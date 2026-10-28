# Keycloak and Kafka Migration to Kubernetes

## Purpose and scope

This document records the local migration of Keycloak and Kafka from the Docker Compose environment into Docker Desktop Kubernetes. The target namespace is `gwatcho-local`.

The migration is for local development. It uses single-replica workloads and the default `hostpath` StorageClass; it is not a highly available production design.

## Current cluster

- Kubernetes context: `docker-desktop`
- Kubernetes version observed during migration: `v1.29.2`
- Namespace: `gwatcho-local`
- Default StorageClass: `hostpath`

Check the active cluster before running commands:

```powershell
kubectl config current-context
kubectl get nodes -o wide
kubectl get deployments,pods,services,pvc -n gwatcho-local
```

## 1. Keycloak migration

### Architecture

Keycloak now runs in Kubernetes as Deployment `keycloak` with ClusterIP Service `keycloak:8080`. Its database is a separate MySQL workload:

| Resource | Configuration |
|---|---|
| Namespace | `gwatcho-local` |
| Keycloak Deployment | `keycloak` |
| Keycloak Service | `keycloak`, port `8080` |
| Database Deployment/Service | `mysql-keycloak`, port `3306` |
| Database PVC | `mysql-keycloak-data`, 5 GiB, `hostpath` |
| Database Secret | `mysql-keycloak-secret` |
| Realm | `gwatcho-shop` |

The repository contains the realm export files at:

```text
docker/keycloak/import/gwatcho-shop-realm.json
docker/keycloak/import/gwatcho-shop-users-0.json
```

Use these as the source of truth for realm configuration and imported users. Confirm the realm and test login in the running Keycloak instance; a healthy pod alone does not prove realm import or OIDC login is correct.

### Verify Keycloak and its database

```powershell
kubectl rollout status deployment/keycloak -n gwatcho-local --timeout=180s
kubectl rollout status deployment/mysql-keycloak -n gwatcho-local --timeout=180s
kubectl get deployment,pod,service,pvc -n gwatcho-local |
  Select-String "keycloak"
kubectl logs deployment/keycloak -n gwatcho-local --tail=100
kubectl logs deployment/mysql-keycloak -n gwatcho-local --tail=100
```

Inspect resource configuration without printing Secret values:

```powershell
kubectl describe deployment keycloak -n gwatcho-local
kubectl describe deployment mysql-keycloak -n gwatcho-local
kubectl get secret mysql-keycloak-secret -n gwatcho-local
```

### Issuer and OIDC URL consistency

The Keycloak issuer in JWTs must exactly match the issuer configured in the API Gateway and backend resource servers. Earlier local configuration used a `localhost` issuer while Keycloak discovery could report a Kubernetes/Docker hostname; that mismatch can cause JWT validation failures.

Inspect the configured issuer and discovery document before changing URLs. Keep these concerns separate:

- The URL used by a browser must be reachable from the browser.
- The issuer configured in each JWT validator must exactly match the token's `iss` claim and Keycloak discovery metadata.
- Kubernetes-only DNS names such as `keycloak.gwatcho-local.svc.cluster.local` are not directly resolvable by a browser outside the cluster.
- Do not change the issuer URL in only one component; align Keycloak hostname/proxy settings, Angular OIDC configuration, and API Gateway/resource-server issuer configuration together.

### Data safety

The former Docker Keycloak volume was named `gwatcho-infrastructure_keycloak-data`, mounted at `/opt/keycloak/data`; the Docker import directory was mounted at `/opt/keycloak/data/import`. Do not delete the old Docker volume until the Kubernetes realm, users, client settings, and login flow have been verified. The Kubernetes MySQL PVC is separate storage and is not automatically populated from the old Docker volume.

## 2. Kafka migration

### Architecture

Kafka has been deployed as a single-node KRaft broker/controller using image `apache/kafka:4.0.0`. ZooKeeper is not required.

| Resource | Configuration |
|---|---|
| Namespace | `gwatcho-local` |
| StatefulSet / Pod | `kafka` / `kafka-0` |
| Client Service | `kafka`, ClusterIP port `9092` |
| Headless Service | `kafka-headless`, controller port `9093` |
| Internal advertised address | `kafka.gwatcho-local.svc.cluster.local:9092` |
| Data PVC | `kafka-data-kafka-0`, 5 GiB, `hostpath` |
| Mode | KRaft, one broker and controller |

In-cluster applications should use the Service address `kafka:9092` (or the full DNS name above). This removes their dependency on `host.docker.internal:19092`. The old Docker broker's external listener remains separate and should not be deleted until dependent applications have been switched and verified.

### Data migration decision

The migration intentionally does **not** copy old Kafka messages. A new cluster ID and fresh persistent volume are used for the Kubernetes broker. The original Docker Kafka container and its named volume `gwatcho-infrastructure_kafka-data` were to be left intact during validation.

Existing application topics identified on the Docker broker:

- `order.created`
- `payment.completed`
- `delivery.completed`
- `product.stock.requested`

The internal topic `__consumer_offsets` is managed by Kafka. Recreate application topics on the Kubernetes broker with the partition and replication settings required by the applications. The initial local configuration uses one partition and replication factor 1; adjust partitions to match the application requirements if necessary.

### Verify Kafka and recreate topics

First verify the broker responds and list topics:

```powershell
kubectl rollout status statefulset/kafka -n gwatcho-local --timeout=180s
kubectl exec -n gwatcho-local kafka-0 -- /opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server kafka:9092
kubectl exec -n gwatcho-local kafka-0 -- /opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:9092 --list
```

If the application topics do not yet exist, create them:

```powershell
$topics = @(
  "order.created",
  "payment.completed",
  "delivery.completed",
  "product.stock.requested"
)

foreach ($topic in $topics) {
  kubectl exec -n gwatcho-local kafka-0 -- `
    /opt/kafka/bin/kafka-topics.sh `
    --bootstrap-server kafka:9092 `
    --create --if-not-exists `
    --topic $topic --partitions 1 --replication-factor 1
}
```

Verify topic details:

```powershell
kubectl exec -n gwatcho-local kafka-0 -- /opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:9092 --describe
```

The pod was observed in `Running` state with zero restarts after deployment. Re-run the commands above to verify current broker metadata and topic state; pod readiness alone is not an end-to-end messaging test.

### Spring Boot configuration

For each service that uses Kafka, configure the application to read the bootstrap server from the environment. For example, if the service's configuration uses `KAFKA_BOOTSTRAP_SERVERS`:

```yaml
spring:
  kafka:
    bootstrap-servers: ${KAFKA_BOOTSTRAP_SERVERS:kafka:9092}
```

Set the Kubernetes Deployment environment variable:

```yaml
env:
  - name: KAFKA_BOOTSTRAP_SERVERS
    value: "kafka:9092"
```

Some existing service configurations may use a differently named property such as `SPRING_KAFKA_BOOTSTRAP_SERVERS`. Check each service's `application.yml` and Deployment manifest, and keep the property name consistent. Do not assume that every service has been switched just because the broker is running.

After updating a service, verify its rollout and logs:

```powershell
kubectl rollout status deployment/<service-name> -n gwatcho-local --timeout=180s
kubectl logs deployment/<service-name> -n gwatcho-local --since=10m |
  Select-String "Kafka|Bootstrap broker|UnknownHostException|Successfully joined group|ERROR|Exception"
```

Also test an actual producer/consumer flow. Successful metadata discovery alone does not prove that events are being processed.

## 3. Migration safety and operational notes

- Do not run `docker compose down --volumes` as part of this migration.
- Do not delete the old Docker Keycloak or Kafka volumes while validating the Kubernetes replacements.
- Do not delete the Kafka PVC to troubleshoot the broker; it contains the new cluster's persisted data.
- The local `hostpath` StorageClass has reclaim policy `Delete`; keep PVC lifecycle changes deliberate.
- Keep passwords and other Secret values out of Git and logs.
- Kafka is a single-replica development deployment. It has no broker-level high availability.
- Keycloak and Kafka migrations do not automatically migrate application configuration. Update and roll out dependent services separately.
- The Kubernetes resource inventory can be checked at any time with `kubectl get deployments,statefulsets,pods,services,pvc -n gwatcho-local`.

## Migration status snapshot

At the time of writing, the cluster inventory showed Keycloak and MySQL Keycloak running in `gwatcho-local`, and Kafka pod `kafka-0` was `1/1 Running`. The four application topic names above were verified on the old Docker broker. Confirm their existence on the Kubernetes broker with the verification commands before declaring the Kafka application cutover complete.
