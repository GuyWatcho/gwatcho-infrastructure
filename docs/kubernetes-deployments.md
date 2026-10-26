# Kubernetes Deployment Documentation

This document describes the five Spring Boot microservices deployed to the local Kubernetes namespace `gwatcho-local` in Docker Desktop Kubernetes.

> **Environment scope:** These manifests use `host.docker.internal` for host-based MySQL and Kafka endpoints. This is the current local development setup; review networking, credentials, image tags, replicas, and secret management before using a production Kubernetes cluster.

## 1. Deployment overview

| Service | Kubernetes Deployment / Service | GHCR image | Container / Service port | MySQL endpoint | Database | Health endpoint |
|---|---|---|---:|---|---|---|
| User | `user-service` | `ghcr.io/guywatcho/gwatcho-user-service:develop-latest` | 8080 | `host.docker.internal:3307` | `user_db` | `/user-service/actuator/health` |
| Product | `product-service` | `ghcr.io/guywatcho/gwatcho-product-service:develop-latest` | 8080 | `host.docker.internal:3308` | `product_db` | `/product-service/actuator/health` |
| Order | `order-service` | `ghcr.io/guywatcho/gwatcho-order-service:develop-latest` | 8080 | `host.docker.internal:3309` | `order_db` | `/order-service/actuator/health` |
| Payment | `payment-service` | `ghcr.io/guywatcho/gwatcho-payment-service:develop-latest` | 8080 | `host.docker.internal:3310` | `payment_db` | `/payment-service/actuator/health` |
| Delivery | `delivery-service` | `ghcr.io/guywatcho/gwatcho-delivery-service:develop-latest` | 8080 | `host.docker.internal:3311` | `delivery_db` | `/delivery-service/actuator/health` |

All five Kubernetes Services are intended to be internal `ClusterIP` services on port 8080. The current manifests configure Kafka at `host.docker.internal:19092`.

## 2. Common deployment configuration

- Namespace: `gwatcho-local`
- Replicas: `1` per service
- Spring profile: `docker`
- Server port: `8080`
- Container registry: GitHub Container Registry (GHCR)
- Image pull secret: `ghcr-pull-secret` (must exist in `gwatcho-local` and have package read access)
- Image pull policy: check each service's `deployment.yaml`; the current manifests use `Always` for the services.
- Probes: startup, liveness, and readiness HTTP probes against each service's actuator health path, on the named `http` port.
- Database credentials: injected through Kubernetes Secret references; passwords must not be committed to Git.

## 3. Service-by-service configuration

### User Service

- Manifest directory: `kubernetes/base/user-service/`
- Deployment and Service: `user-service`
- Image: `ghcr.io/guywatcho/gwatcho-user-service:develop-latest`
- Database: `user_db`, reached through `host.docker.internal:3307`
- Kubernetes Secret: `user-db-secret`
- Required Secret keys: `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD`
- Kafka bootstrap server: `host.docker.internal:19092`
- Health endpoint: `/user-service/actuator/health`
- OAuth2 resource-server configuration is set through JWT issuer and JWK-set environment variables in the Deployment.
- Vault integration: Vault role `gwatcho-user-service-role`, policy `gwatcho-user-service-policy`, ServiceAccount `vso-user-service`, KV v2 path `secret/user-service`, destination Secret `user-db-secret`.

### Product Service

- Manifest directory: `kubernetes/base/product-service/`
- Deployment and Service: `product-service`
- Image: `ghcr.io/guywatcho/gwatcho-product-service:develop-latest`
- Database: `product_db`, reached through `host.docker.internal:3308`
- Kubernetes Secret: `product-db-secret`
- Required Secret keys: `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD`
- Kafka bootstrap server: `host.docker.internal:19092`
- Health endpoint: `/product-service/actuator/health`
- Vault integration: Vault role `gwatcho-product-service-role`, policy `gwatcho-product-service-policy`, ServiceAccount `vso-product-service`, KV v2 path `secret/product-service`, destination Secret `product-db-secret`.

### Order Service

- Manifest directory: `kubernetes/base/order-service/`
- Deployment and Service: `order-service`
- Image: `ghcr.io/guywatcho/gwatcho-order-service:develop-latest`
- Database: `order_db`, reached through `host.docker.internal:3309`
- Kubernetes Secret: `order-db-secret`
- Required Secret keys: `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD`
- Kafka bootstrap server: `host.docker.internal:19092`
- Health endpoint: `/order-service/actuator/health`
- OAuth2 resource-server JWT issuer and JWK-set URI are configured through environment variables in the Deployment.
- Vault integration: Vault role `gwatcho-order-service-role`, policy `gwatcho-order-service-policy`, ServiceAccount `vso-order-service`, KV v2 path `secret/order-service`, destination Secret `order-db-secret`.

### Payment Service

- Manifest directory: `kubernetes/base/payment-service/`
- Deployment and Service: `payment-service`
- Image: `ghcr.io/guywatcho/gwatcho-payment-service:develop-latest`
- Database: `payment_db`, reached through `host.docker.internal:3310`
- Kubernetes Secret: `payment-db-secret`
- Required Secret keys: `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD`
- Kafka bootstrap server: `host.docker.internal:19092`
- Health endpoint: `/payment-service/actuator/health`
- Vault integration: Vault role `gwatcho-payment-service-role`, policy `gwatcho-payment-service-policy`, ServiceAccount `vso-payment-service`, KV v2 path `secret/payment-service`, destination Secret `payment-db-secret`.
- The Deployment must reference `imagePullSecrets: [{ name: ghcr-pull-secret }]` so Kubernetes can pull the private GHCR package.

### Delivery Service

- Manifest directory: `kubernetes/base/delivery-service/`
- Deployment and Service: `delivery-service`
- Image: `ghcr.io/guywatcho/gwatcho-delivery-service:develop-latest`
- Database: `delivery_db`, reached through `host.docker.internal:3311`
- Kubernetes Secret: `delivery-db-secret`
- Required Secret keys: `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD`
- Kafka bootstrap server: `host.docker.internal:19092`
- Health endpoint: `/delivery-service/actuator/health`
- Vault integration: Vault role `gwatcho-delivery-service-role`, policy `gwatcho-delivery-service-policy`, ServiceAccount `vso-delivery-service`, KV v2 path `secret/delivery-service`, destination Secret `delivery-db-secret`.
- The Deployment must reference `imagePullSecrets: [{ name: ghcr-pull-secret }]` so Kubernetes can pull the private GHCR package.

## 4. Vault Secrets Operator pattern

Each service uses its own Vault Kubernetes-auth role and narrowly scoped policy to read only its own KV v2 secret path:

| Service | VaultAuth resource | VaultStaticSecret resource | KV v2 path | Destination Kubernetes Secret |
|---|---|---|---|---|
| User | `user-service-vault-auth` | `user-service-db-secret` | `secret/user-service` | `user-db-secret` |
| Product | `product-service-vault-auth` | `product-service-db-secret` | `secret/product-service` | `product-db-secret` |
| Order | `order-service-vault-auth` | `order-db-secret` | `secret/order-service` | `order-db-secret` |
| Payment | `payment-service-vault-auth` | `payment-service-db-secret` | `secret/payment-service` | `payment-db-secret` |
| Delivery | `delivery-service-vault-auth` | `delivery-service-db-secret` | `secret/delivery-service` | `delivery-db-secret` |

Vault KV v2 policy paths use the API path `secret/data/<service>`; the logical secret paths shown in the table omit the `data/` segment. Each VaultStaticSecret is configured to refresh periodically. Do not store actual credentials in manifests or this document.

## 5. Apply and verify deployments

Run commands from the infrastructure repository root.

Apply one service:

```powershell
kubectl apply -k .\kubernetes\base\user-service
kubectl apply -k .\kubernetes\base\product-service
kubectl apply -k .\kubernetes\base\order-service
kubectl apply -k .\kubernetes\base\payment-service
kubectl apply -k .\kubernetes\base\delivery-service
```

Check workloads and Services:

```powershell
kubectl get deployments,pods,svc -n gwatcho-local
```

Check Vault synchronization:

```powershell
kubectl get vaultauth,vaultstaticsecret -n gwatcho-local
```

Inspect one service's logs:

```powershell
kubectl logs deployment/delivery-service -n gwatcho-local --tail=100
```

If a pod cannot pull an image, inspect its events with `kubectl describe pod <pod-name> -n gwatcho-local`. For GHCR authorization failures, verify that `ghcr-pull-secret` exists in the same namespace and has a valid token with `read:packages` access.

## 6. Current verification snapshot

On 2026-10-26, the cluster output shared for namespace `gwatcho-local` showed all five Deployments available at `1/1`, and the five service pods in `Running` state with zero restarts at the time of that check. This is a historical snapshot, not a live health guarantee.
