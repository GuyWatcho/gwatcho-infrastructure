# Kubernetes Deployment Documentation

This document describes the five Spring Boot microservices and their supporting infrastructure deployed to the local Kubernetes cluster in namespace `gwatcho-local`.

> **Environment scope:** This is a Kubernetes deployment guide. Application Pods connect to Kubernetes ClusterIP Services using Kubernetes DNS names and Service ports. Do not use Docker Compose host ports such as `host.docker.internal:3307-3311` from these Pods. Docker Desktop is the local Kubernetes platform, but the workloads and dependencies documented here run as Kubernetes resources.

## 1. Deployment overview

Each microservice owns a dedicated MySQL database deployment, Service, and persistent volume claim. Each microservice connects only to its own database.

| Microservice | Kubernetes Deployment / Service | GHCR image | HTTP port | MySQL Service endpoint | Database | Health endpoint |
|---|---|---|---:|---|---|---|
| User | `user-service` | `ghcr.io/guywatcho/gwatcho-user-service:develop-latest` | 8080 | `mysql-user:3306` | `user_db` | `/user-service/actuator/health` |
| Product | `product-service` | `ghcr.io/guywatcho/gwatcho-product-service:develop-latest` | 8080 | `mysql-product:3306` | `product_db` | `/product-service/actuator/health` |
| Order | `order-service` | `ghcr.io/guywatcho/gwatcho-order-service:develop-latest` | 8080 | `mysql-order:3306` | `order_db` | `/order-service/actuator/health` |
| Payment | `payment-service` | `ghcr.io/guywatcho/gwatcho-payment-service:develop-latest` | 8080 | `mysql-payment:3306` | `payment_db` | `/payment-service/actuator/health` |
| Delivery | `delivery-service` | `ghcr.io/guywatcho/gwatcho-delivery-service:develop-latest` | 8080 | `mysql-delivery:3306` | `delivery_db` | `/delivery-service/actuator/health` |

The full in-cluster Service DNS names are:

- `mysql-user.gwatcho-local.svc.cluster.local:3306`
- `mysql-product.gwatcho-local.svc.cluster.local:3306`
- `mysql-order.gwatcho-local.svc.cluster.local:3306`
- `mysql-payment.gwatcho-local.svc.cluster.local:3306`
- `mysql-delivery.gwatcho-local.svc.cluster.local:3306`

Short Service names (for example, `mysql-product`) resolve within the same namespace, `gwatcho-local`.

| Supporting component | Kubernetes resource / Service | In-cluster endpoint |
|---|---|---|
| Kafka | StatefulSet `kafka`, Service `kafka` | `kafka:9092` |
| Keycloak | Deployment and Service `keycloak` | `http://keycloak:8080` |
| MySQL for Keycloak | Kubernetes MySQL resource | `mysql-keycloak:3306` |

All five backend Services are internal `ClusterIP` Services on port 8080. The five MySQL Services are internal `ClusterIP` Services on port 3306. Kafka exposes an internal ClusterIP Service on port 9092. Keycloak exposes an internal ClusterIP Service on port 8080.

## 2. Common deployment configuration

- Namespace: `gwatcho-local`
- Microservice replicas: one per Deployment in the current local manifests
- Spring server port: `8080`
- Spring profile: the Kubernetes manifests are the source of truth; some service manifests currently still set `SPRING_PROFILES_ACTIVE=docker` and must be aligned to `kubernetes` before relying on profile-specific Kubernetes configuration.
- Container registry: GitHub Container Registry (GHCR)
- Image pull secret: `ghcr-pull-secret` (must exist in `gwatcho-local` and have package read access)
- Image pull policy: `Always` in the five service Deployments
- Probes: startup, liveness, and readiness HTTP probes against each service's actuator health path, on the named `http` port
- Database credentials: supplied through Kubernetes Secret references; never commit real credentials to Git
- Database networking: Kubernetes Service DNS name and port 3306, never host-published Docker ports
- MySQL persistence: each MySQL Deployment mounts its own PersistentVolumeClaim

**Important configuration follow-up:** The current repository manifests do not yet agree on all runtime settings. User and Order currently set the `kubernetes` profile; Product, Payment, and Delivery still set `docker`. Kafka is set to `kafka:9092` for User but `kafka:19092` for Product, Order, Payment, and Delivery even though the Kubernetes Kafka Service exposes port 9092 only. Correct these Deployment environment values and the related Spring profile configuration before considering all services consistently configured for Kubernetes. This guide records that mismatch explicitly; it does not pretend the live manifests have already been fixed.

## 3. Service-by-service configuration

The JDBC URLs below match the Kubernetes database Service names and database names. They are the required in-cluster endpoints for this architecture.

### User Service

- Manifest directory: `kubernetes/base/services/user-service/`
- Deployment and Service: `user-service`
- Image: `ghcr.io/guywatcho/gwatcho-user-service:develop-latest`
- Spring profile in current manifest: `kubernetes`
- JDBC URL: `jdbc:mysql://mysql-user:3306/user_db?serverTimezone=Europe/Berlin`
- Database Service: `mysql-user:3306`
- Kubernetes Secret: `user-db-secret`
- Required Secret keys: `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD`
- Kafka bootstrap server in current manifest: `kafka:9092`
- Health endpoint: `/user-service/actuator/health`
- JWT issuer currently configured as `http://localhost:8080/realms/gwatcho-shop`; JWK Set URI: `http://keycloak:8080/realms/gwatcho-shop/protocol/openid-connect/certs`. The issuer must match the `iss` claim in the access token. Verify that the browser-facing Keycloak URL and issuer configuration are consistent.
- Vault integration documented in repository: role `gwatcho-user-service-role`, policy `gwatcho-user-service-policy`, ServiceAccount `vso-user-service`, KV v2 path `secret/user-service`, destination Secret `user-db-secret`.

### Product Service

- Manifest directory: `kubernetes/base/services/product-service/`
- Deployment and Service: `product-service`
- Image: `ghcr.io/guywatcho/gwatcho-product-service:develop-latest`
- Spring profile in current manifest: `docker` (change to `kubernetes` for consistent Kubernetes configuration)
- JDBC URL: `jdbc:mysql://mysql-product:3306/product_db?serverTimezone=Europe/Berlin`
- Database Service: `mysql-product:3306`
- Kubernetes Secret: `product-db-secret`
- Required Secret keys: `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD`
- Kafka bootstrap server in current manifest: `kafka:19092` (incorrect for the Kubernetes Service; change to `kafka:9092`)
- Health endpoint: `/product-service/actuator/health`
- JWK Set URI: `http://keycloak:8080/realms/gwatcho-shop/protocol/openid-connect/certs`; validate the configured JWT issuer against the token `iss` claim.
- Vault integration documented in repository: role `gwatcho-product-service-role`, policy `gwatcho-product-service-policy`, ServiceAccount `vso-product-service`, KV v2 path `secret/product-service`, destination Secret `product-db-secret`.

### Order Service

- Manifest directory: `kubernetes/base/services/order-service/`
- Deployment and Service: `order-service`
- Image: `ghcr.io/guywatcho/gwatcho-order-service:develop-latest`
- Spring profile in current manifest: `kubernetes`
- JDBC URL: `jdbc:mysql://mysql-order:3306/order_db?serverTimezone=Europe/Berlin`
- Database Service: `mysql-order:3306`
- Kubernetes Secret: `order-db-secret`
- Required Secret keys: `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD`
- Kafka bootstrap server in current manifest: `kafka:19092` (incorrect for the Kubernetes Service; change to `kafka:9092`)
- Health endpoint: `/order-service/actuator/health`
- JWT issuer and JWK Set URI are configured through environment variables. Validate issuer consistency with the token `iss` claim.
- Vault integration documented in repository: role `gwatcho-order-service-role`, policy `gwatcho-order-service-policy`, ServiceAccount `vso-order-service`, KV v2 path `secret/order-service`, destination Secret `order-db-secret`.

### Payment Service

- Manifest directory: `kubernetes/base/services/payment-service/`
- Deployment and Service: `payment-service`
- Image: `ghcr.io/guywatcho/gwatcho-payment-service:develop-latest`
- Spring profile in current manifest: `docker` (change to `kubernetes` for consistent Kubernetes configuration)
- JDBC URL: `jdbc:mysql://mysql-payment:3306/payment_db?serverTimezone=Europe/Berlin`
- Database Service: `mysql-payment:3306`
- Kubernetes Secret: `payment-db-secret`
- Required Secret keys: `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD`
- Kafka bootstrap server in current manifest: `kafka:19092` (incorrect for the Kubernetes Service; change to `kafka:9092`)
- Health endpoint: `/payment-service/actuator/health`
- JWK Set URI: `http://keycloak:8080/realms/gwatcho-shop/protocol/openid-connect/certs`; validate the configured JWT issuer against the token `iss` claim.
- Vault integration documented in repository: role `gwatcho-payment-service-role`, policy `gwatcho-payment-service-policy`, ServiceAccount `vso-payment-service`, KV v2 path `secret/payment-service`, destination Secret `payment-db-secret`.

### Delivery Service

- Manifest directory: `kubernetes/base/services/delivery-service/`
- Deployment and Service: `delivery-service`
- Image: `ghcr.io/guywatcho/gwatcho-delivery-service:develop-latest`
- Spring profile in current manifest: `docker` (change to `kubernetes` for consistent Kubernetes configuration)
- JDBC URL: `jdbc:mysql://mysql-delivery:3306/delivery_db?serverTimezone=Europe/Berlin`
- Database Service: `mysql-delivery:3306`
- Kubernetes Secret: `delivery-db-secret`
- Required Secret keys: `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD`
- Kafka bootstrap server in current manifest: `kafka:19092` (incorrect for the Kubernetes Service; change to `kafka:9092`)
- Health endpoint: `/delivery-service/actuator/health`
- JWK Set URI: `http://keycloak:8080/realms/gwatcho-shop/protocol/openid-connect/certs`; validate the configured JWT issuer against the token `iss` claim.
- Vault integration documented in repository: role `gwatcho-delivery-service-role`, policy `gwatcho-delivery-service-policy`, ServiceAccount `vso-delivery-service`, KV v2 path `secret/delivery-service`, destination Secret `delivery-db-secret`.

## 4. Dedicated MySQL databases and persistence

The Kubernetes base tree defines five independent MySQL workloads:

| Microservice | MySQL Deployment | MySQL Service | Database | PVC |
|---|---|---|---|---|
| User | `mysql-user` | `mysql-user` | `user_db` | `mysql-user-data` |
| Product | `mysql-product` | `mysql-product` | `product_db` | `mysql-product-data` |
| Order | `mysql-order` | `mysql-order` | `order_db` | `mysql-order-data` |
| Payment | `mysql-payment` | `mysql-payment` | `payment_db` | `mysql-payment-data` |
| Delivery | `mysql-delivery` | `mysql-delivery` | `delivery_db` | `mysql-delivery-data` |

Each database Deployment uses MySQL 8.4, listens on container port 3306, loads database credentials from its service-specific Kubernetes Secret, and mounts its own PVC at `/var/lib/mysql`. Its Service is ClusterIP on port 3306. This provides both logical database ownership and separate persisted data volumes.

The MySQL Services are in the same namespace as the microservices, so short DNS names such as `mysql-order` are valid. Fully qualified DNS names can be used where desired.

## 5. Vault Secrets Operator pattern

Each service uses its own Vault Kubernetes-auth role and narrowly scoped policy to read only its own KV v2 secret path:

| Service | VaultAuth resource | VaultStaticSecret resource | KV v2 path | Destination Kubernetes Secret |
|---|---|---|---|---|
| User | `user-service-vault-auth` | `user-service-db-secret` | `secret/user-service` | `user-db-secret` |
| Product | `product-service-vault-auth` | `product-service-db-secret` | `secret/product-service` | `product-db-secret` |
| Order | `order-service-vault-auth` | `order-db-secret` | `secret/order-service` | `order-db-secret` |
| Payment | `payment-service-vault-auth` | `payment-service-db-secret` | `secret/payment-service` | `payment-db-secret` |
| Delivery | `delivery-service-vault-auth` | `delivery-service-db-secret` | `secret/delivery-service` | `delivery-db-secret` |

Vault KV v2 policy paths use the API path `secret/data/<service>`; the logical secret paths shown in the table omit the `data/` segment. Each VaultStaticSecret is configured to refresh periodically. Do not store actual credentials in manifests or this document.

The five MySQL Deployments also require the key `MYSQL_ROOT_PASSWORD` in their corresponding database Secret. Verify that each Secret contains this key in addition to the Spring datasource username/password keys. Do not print Secret contents in logs or diagnostic output.

## 6. Apply and verify Kubernetes deployments

Run commands from the infrastructure repository root in PowerShell. The base directories are organized by component; apply each desired resource set explicitly.

Apply microservices:

```powershell
kubectl apply -k .\kubernetes\base\services\user-service
kubectl apply -k .\kubernetes\base\services\product-service
kubectl apply -k .\kubernetes\base\services\order-service
kubectl apply -k .\kubernetes\base\services\payment-service
kubectl apply -k .\kubernetes\base\services\delivery-service
```

Apply MySQL workloads:

```powershell
kubectl apply -k .\kubernetes\base\databases\mysql-user
kubectl apply -k .\kubernetes\base\databases\mysql-product
kubectl apply -k .\kubernetes\base\databases\mysql-order
kubectl apply -k .\kubernetes\base\databases\mysql-payment
kubectl apply -k .\kubernetes\base\databases\mysql-delivery
```

The component Kustomizations must be applied only after their required Secrets exist (and, where enabled, have been synchronized by Vault Secrets Operator). Inspect the rendered manifests first with `kubectl kustomize <directory>`.

Check workloads and Services:

```powershell
kubectl get deployments,statefulsets,pods,services,pvc -n gwatcho-local
```

Check database Service endpoints:

```powershell
kubectl get svc mysql-user mysql-product mysql-order mysql-payment mysql-delivery -n gwatcho-local
kubectl get endpoints mysql-user mysql-product mysql-order mysql-payment mysql-delivery -n gwatcho-local
```

Check Vault synchronization:

```powershell
kubectl get vaultauth,vaultstaticsecret -n gwatcho-local
```

Inspect service logs:

```powershell
kubectl logs deployment/user-service -n gwatcho-local --tail=100
kubectl logs deployment/product-service -n gwatcho-local --tail=100
kubectl logs deployment/order-service -n gwatcho-local --tail=100
kubectl logs deployment/payment-service -n gwatcho-local --tail=100
kubectl logs deployment/delivery-service -n gwatcho-local --tail=100
```

For image pull problems, inspect Pod events with `kubectl describe pod <pod-name> -n gwatcho-local`. Verify that `ghcr-pull-secret` exists in the same namespace and has a valid token with `read:packages` access.

## 7. Network and application configuration checks

### MySQL

From every microservice Pod, the JDBC hostname must be its dedicated MySQL Service name and the port must be 3306. Examples:

```text
jdbc:mysql://mysql-user:3306/user_db
jdbc:mysql://mysql-product:3306/product_db
jdbc:mysql://mysql-order:3306/order_db
jdbc:mysql://mysql-payment:3306/payment_db
jdbc:mysql://mysql-delivery:3306/delivery_db
```

Never configure a Kubernetes Pod to connect to these in-cluster MySQL workloads through `host.docker.internal` or the old Compose host ports `3307`- `3311`.

### Kafka

The Kubernetes Kafka manifest defines a ClusterIP Service named `kafka` on port 9092 and advertises `kafka.gwatcho-local.svc.cluster.local:9092`. Therefore all microservice Deployments must use:

```text
SPRING_KAFKA_BOOTSTRAP_SERVERS=kafka:9092
```

The current Product, Order, Payment, and Delivery Deployment manifests still show `kafka:19092`, which does not match the Kubernetes Service. Update those values to `kafka:9092`. Do not copy the old Docker external-listener port into Kubernetes workloads.

### Keycloak and JWT issuer

The JWK Set URI used by Pods should address the Kubernetes Service, for example:

```text
http://keycloak:8080/realms/gwatcho-shop/protocol/openid-connect/certs
```

The JWT issuer (`iss`) must exactly match the issuer claim in the tokens issued to the browser. Do not assume that the Pod-internal JWK URL is also the browser-facing issuer URL. Configure Keycloak hostname/issuer and the Spring resource-server issuer setting consistently; the current manifests use `http://localhost:8080/realms/gwatcho-shop` as issuer, so verify that this is still what the realm advertises.

### Spring profile

The five Deployment manifests should consistently select the Kubernetes Spring profile if the application has Kubernetes-specific configuration. Currently Product, Payment, and Delivery use `SPRING_PROFILES_ACTIVE=docker`, while User and Order use `kubernetes`. Align the three inconsistent manifests and verify that each service contains the intended `application-kubernetes.yml` settings. Database and Kafka environment variables should be explicit and should not rely on a Docker profile's defaults.

## 8. Current verification snapshot

On 2026-10-26, the cluster output shared for namespace `gwatcho-local` showed all five microservice Deployments available at `1/1`, and the five service Pods in `Running` state with zero restarts at the time of that check. This is a historical snapshot, not a live health guarantee. The repository manifests also define five separate MySQL Deployments, Services, and PVCs; verify their current status with the commands above.

---
**Kubernetes configuration rule:** Kubernetes workloads communicate through Kubernetes Services and in-cluster DNS. Docker Compose host ports and host-specific endpoints belong only in Docker Compose documentation, not in these Kubernetes Deployment instructions.
