# Local Kubernetes: Product Service

This guide documents the first working local Kubernetes workload for GWatcho Shop on Docker Desktop Kubernetes. The manifests live in this repository and are applied with Kustomize.

## Current implementation

- Namespace: `gwatcho-local`
- Workload: one replica of `product-service`
- Image: `ghcr.io/guywatcho/gwatcho-product-service:develop-latest` (local development only; use an immutable version tag or digest for release deployment)
- Kubernetes Service: `ClusterIP`, port `8080`
- Application context path: `/product-service`
- Actuator health endpoint: `/product-service/actuator/health`
- MySQL: existing Compose product database at `host.docker.internal:3308/product_db`
- MySQL credentials: Kubernetes Secret named `product-db-secret`
- Kafka: existing Compose broker using internal listener `kafka:9092` for Compose services and external listener `host.docker.internal:19092` for Kubernetes clients
- Probes: startup, liveness, and readiness HTTP probes

The Kubernetes workload runs beside the existing Docker Compose stack. Do not use `docker compose down --volumes` as part of this workflow; that command deletes named-volume data.

## Files

```text
kubernetes/
  base/
    product-service/
      deployment.yaml
      service.yaml
      kustomization.yaml
  overlays/
    local/
      kustomization.yaml
```

The local overlay sets the namespace and includes the Product Service base resources.

## Prerequisites

- Docker Desktop is running and Kubernetes is enabled.
- `kubectl` is installed and the current context points to Docker Desktop Kubernetes.
- Run commands below from the `gwatcho-infrastructure` repository root in Windows PowerShell.
- The existing Compose MySQL product database and Kafka broker are running.
- The local Kafka Compose service has both listeners configured as described below.

Check the cluster and namespace:

```powershell
kubectl config current-context
kubectl cluster-info
kubectl get nodes
kubectl get namespace gwatcho-local
```

If the namespace does not exist yet:

```powershell
kubectl create namespace gwatcho-local
```

## 1. Configure Kafka for Compose and Kubernetes

Compose containers use the Docker network name `kafka:9092`. Kafka returns the advertised listener address to clients after the initial connection, so changing only the Kubernetes bootstrap address is not enough if the broker advertises `kafka:9092` to the Pod.

In the `kafka` service of `docker-compose.yml`, configure separate internal and external listeners:

```yaml
ports:
  - "9092:9092"
  - "19092:19092"
environment:
  KAFKA_LISTENERS: INTERNAL://:9092,EXTERNAL://:19092,CONTROLLER://:9093
  KAFKA_ADVERTISED_LISTENERS: INTERNAL://kafka:9092,EXTERNAL://host.docker.internal:19092
  KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: INTERNAL:PLAINTEXT,EXTERNAL:PLAINTEXT,CONTROLLER:PLAINTEXT
  KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
  KAFKA_INTER_BROKER_LISTENER_NAME: INTERNAL
```

Keep the existing controller quorum, node ID, process roles, replication settings, and other Kafka environment variables unchanged. Merge the port mappings with the existing `ports` section rather than adding a duplicate.

Validate the Compose configuration and recreate only Kafka:

```powershell
docker compose config --quiet
docker compose up -d --no-deps --force-recreate kafka
docker ps --filter "name=gwatcho-kafka"
docker logs --tail=80 gwatcho-kafka
```

This recreates the Kafka container only; it does not intentionally recreate other services or remove volumes. Do not remove the named volume `gwatcho-infrastructure_kafka-data`.

Verify that the broker responds through both listeners:

```powershell
docker exec gwatcho-kafka /opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092
docker exec gwatcho-kafka /opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server localhost:19092
```

The internal listener should advertise `kafka:9092`; the external listener should advertise `host.docker.internal:19092`.

## 2. Create the MySQL Secret

Do not put the database password in a manifest, commit it to Git, or print it in terminal logs. Create the Secret directly in the cluster using a secure PowerShell prompt. Enter the password currently configured for the Compose `product_db` database when prompted:

```powershell
$securePassword = Read-Host "Enter the product MySQL password" -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
try {
    $mysqlPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    kubectl create secret generic product-db-secret `
      --namespace gwatcho-local `
      --from-literal=SPRING_DATASOURCE_USERNAME=product_user `
      --from-literal=SPRING_DATASOURCE_PASSWORD="$mysqlPassword" `
      --dry-run=client -o yaml |
      kubectl apply -f -
}
finally {
    if ($bstr -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
    $mysqlPassword = $null
    $securePassword.Dispose()
}
```

If the Secret already exists and you need to rotate its values, rerun the command; the generated resource is applied to the existing Secret.

Kubernetes Secrets are not automatically encrypted at rest simply because they are Secret objects. This local setup is for development. Production should use appropriate encryption at rest, least-privilege RBAC, and a managed/external secrets solution.

## 3. Validate and apply the manifests

Review the rendered resources first:

```powershell
kubectl kustomize .\kubernetes\overlays\local
kubectl apply --dry-run=client -k .\kubernetes\overlays\local
```

Apply them and wait for rollout:

```powershell
kubectl apply -k .\kubernetes\overlays\local
kubectl rollout status deployment/product-service -n gwatcho-local --timeout=180s
kubectl get deployment,pods,svc -n gwatcho-local
```

The Deployment uses these settings:

- `SPRING_PROFILES_ACTIVE=docker`
- MySQL URL: `jdbc:mysql://host.docker.internal:3308/product_db?serverTimezone=Europe/Berlin`
- Username and password from `product-db-secret`
- Kafka bootstrap address: `host.docker.internal:19092`
- Probe path: `/product-service/actuator/health`

## 4. Verify health, logs, and the Products API

Inspect the latest application logs:

```powershell
kubectl logs deployment/product-service -n gwatcho-local --tail=100
```

Check that the environment references the Secret and the intended Kafka listener without displaying the password:

```powershell
kubectl get deployment product-service -n gwatcho-local -o yaml |
  Select-String -Pattern "product-db-secret|secretKeyRef|SPRING_KAFKA_BOOTSTRAP_SERVERS|host.docker.internal:19092" -Context 1,2
kubectl exec deployment/product-service -n gwatcho-local -- printenv SPRING_KAFKA_BOOTSTRAP_SERVERS
```

Start a port-forward in a separate PowerShell window and leave it running:

```powershell
kubectl port-forward -n gwatcho-local svc/product-service 18083:8080
```

In another PowerShell window, test health and product retrieval:

```powershell
Invoke-RestMethod "http://localhost:18083/product-service/actuator/health"
Invoke-RestMethod "http://localhost:18083/product-service/api/products"
```

Expected results: the health response reports `status = UP`; the Products API returns product data. The dedicated health endpoint exposes the `liveness` and `readiness` groups. Review the response and logs if a check fails.

Check Kafka connectivity from the Product Service logs:

```powershell
kubectl logs deployment/product-service -n gwatcho-local --since=5m |
  Select-String -Pattern "UnknownHostException|Error connecting to node|Successfully joined group"
```

A successful consumer group join is a positive signal. If `UnknownHostException: kafka` appears, verify that the external Kafka listener is configured and that the Kubernetes Deployment uses `host.docker.internal:19092`.

## 5. Troubleshooting and safe operations

```powershell
kubectl describe deployment product-service -n gwatcho-local
kubectl describe pods -n gwatcho-local
kubectl get events -n gwatcho-local --sort-by=.lastTimestamp
kubectl logs deployment/product-service -n gwatcho-local --tail=200
kubectl rollout status deployment/product-service -n gwatcho-local --timeout=180s
```

- **Pod is not ready:** inspect startup/readiness probe events and application logs.
- **MySQL authentication fails:** verify that `product-db-secret` contains the correct username/password for the existing product database; do not print Secret values to the console.
- **Kafka reports `UnknownHostException: kafka`:** verify the broker advertises the external listener correctly and the Deployment uses `host.docker.internal:19092`.
- **Health is UP but Kafka warns:** Actuator health may not prove Kafka consumer connectivity; inspect the Kafka consumer logs separately.
- **Do not delete Compose volumes or run `docker compose down --volumes`** to troubleshoot this local Kubernetes deployment.

## Validation status

The first Product Service workload was applied successfully in namespace `gwatcho-local`. The Deployment rollout completed, the health endpoint returned `UP`, the Products API returned HTTP 200, and the Kafka consumer successfully joined the `product-service` consumer group after configuring the external listener.

This milestone proves the first local workload only. It does not mean that all microservices or a production deployment are ready. Continue with one service at a time and run end-to-end smoke tests before expanding the deployment.
