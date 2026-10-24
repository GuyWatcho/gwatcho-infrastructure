# Local Kubernetes Deployment Runbook

This runbook documents the current local Kubernetes workflow for the `user-service`, `product-service`, and `order-service` on Docker Desktop Kubernetes.

## Scope and safety

- Run commands from the `gwatcho-infrastructure` repository in Windows PowerShell.
- The target namespace is `gwatcho-local`.
- The local Kubernetes context is expected to be `docker-desktop`; verify it before applying changes.
- The application images are published in GHCR. Confirm the image tag and private-registry pull secret before deployment.
- Keep the existing Docker Compose environment and its named volumes intact. Do not run `docker compose down --volumes` as part of Kubernetes deployment or rollback.
- Do not commit credentials, Secret values, tokens, or kubeconfig data.

## 1. Select and verify the cluster

```powershell
kubectl config current-context
kubectl cluster-info
kubectl get nodes
```

Confirm that the selected context is the intended local cluster before proceeding. If the context is not `docker-desktop`, switch only if that is the cluster you intend to administer:

```powershell
kubectl config use-context docker-desktop
```

Create the namespace if it does not already exist:

```powershell
kubectl create namespace gwatcho-local --dry-run=client -o yaml | kubectl apply -f -
```

## 2. Check prerequisites and secrets

Confirm the namespace and Vault-synchronized database Secrets are present:

```powershell
kubectl get namespace gwatcho-local
kubectl get secrets -n gwatcho-local
kubectl get vaultstaticsecrets -n gwatcho-local
```

For services using Vault Secrets, check sync and health without printing secret values:

```powershell
kubectl get vaultstaticsecret -n gwatcho-local
kubectl describe vaultstaticsecret user-db-secret -n gwatcho-local
kubectl describe vaultstaticsecret order-db-secret -n gwatcho-local
```

Use the actual resource names in your manifests if they differ. A database Secret should be synchronized and contain the expected keys before restarting its Deployment. For private GHCR images, verify the configured image pull Secret exists:

```powershell
kubectl get secret ghcr-pull-secret -n gwatcho-local
```

Do not display or paste decoded Secret values into logs, tickets, or GitHub.

## 3. Apply each service's Kubernetes manifests

Apply each Kustomize directory separately. This keeps changes scoped and makes troubleshooting easier:

```powershell
kubectl apply -k .\kubernetes\base\user-service
kubectl apply -k .\kubernetes\base\product-service
kubectl apply -k .\kubernetes\base\order-service
```

If the repository uses different directory names, use the paths that actually contain each service's `kustomization.yaml`. Use `kubectl apply -k <directory>`, not `kubectl apply -f kustomization.yaml`.

## 4. Wait for the rollouts

```powershell
kubectl rollout status deployment/user-service -n gwatcho-local --timeout=180s
kubectl rollout status deployment/product-service -n gwatcho-local --timeout=180s
kubectl rollout status deployment/order-service -n gwatcho-local --timeout=180s
```

A successful rollout confirms the Deployment has met its rollout conditions; still check pod readiness, logs, and application health.

## 5. Verify workloads and Services

```powershell
kubectl get deployments,services,pods -n gwatcho-local -o wide
kubectl get events -n gwatcho-local --sort-by=.lastTimestamp
```

Each intended Deployment should have the expected number of ready replicas. Investigate `ImagePullBackOff`, `CrashLoopBackOff`, failed probes, missing Secrets, or repeated restarts before continuing.

## 6. Verify application logs and health

Review recent logs for each service:

```powershell
kubectl logs deployment/user-service -n gwatcho-local --tail=100
kubectl logs deployment/product-service -n gwatcho-local --tail=100
kubectl logs deployment/order-service -n gwatcho-local --tail=100
```

Check the Actuator health endpoint from inside each pod. The paths below assume the services use the corresponding context paths; adjust them if the application configuration differs:

```powershell
kubectl exec deployment/user-service -n gwatcho-local -- sh -c 'wget -qO- http://localhost:8080/user-service/actuator/health'
kubectl exec deployment/product-service -n gwatcho-local -- sh -c 'wget -qO- http://localhost:8080/product-service/actuator/health'
kubectl exec deployment/order-service -n gwatcho-local -- sh -c 'wget -qO- http://localhost:8080/order-service/actuator/health'
```

Expected result: `"status":"UP"`. Check component details too, especially the database. A health endpoint that reports `UP` does not by itself prove Kafka event processing or end-to-end checkout works.

## 7. Test a service from Windows using port forwarding

Port-forwarding is useful for local smoke tests without changing the Service type or exposing the service permanently. Run one command in a dedicated PowerShell window and leave it open:

```powershell
kubectl port-forward service/order-service 8082:8080 -n gwatcho-local
```

In a second PowerShell window:

```powershell
Invoke-RestMethod http://localhost:8082/order-service/actuator/health
```

For other services, use a different local port and the actual Service name. Stop port forwarding with Ctrl+C when finished. Use authenticated API requests and the real request schema when testing protected business endpoints; do not guess payloads.

## 8. Check Kafka connectivity separately

The Actuator response may not include a Kafka health component. Inspect the configured bootstrap server and recent Kafka logs:

```powershell
kubectl exec deployment/order-service -n gwatcho-local -- printenv SPRING_KAFKA_BOOTSTRAP_SERVERS
kubectl logs deployment/order-service -n gwatcho-local --since=5m |
    Select-String -Pattern 'Successfully joined group|assigned partitions|Bootstrap broker|disconnected|ERROR|Exception'
```

A successful broker metadata response and group coordinator discovery are encouraging, but confirm the consumer joins its group and that the application can process the expected events. Make sure the Kafka advertised listener is reachable from Kubernetes pods; an address that works from a Compose container may not work from a Kubernetes pod.

## 9. Troubleshooting quick reference

### Rollout is stuck or a pod is not ready

```powershell
kubectl describe deployment order-service -n gwatcho-local
kubectl describe pod -n gwatcho-local <pod-name>
kubectl get events -n gwatcho-local --sort-by=.lastTimestamp
kubectl logs deployment/order-service -n gwatcho-local --tail=200
```

### Database connection failure

- Verify the database container is running and healthy.
- Confirm the configured host port, database name, and JDBC URL match the intended database container.
- Confirm the database exists and credentials are synchronized from Vault into the Kubernetes Secret.
- From a pod, do not use `localhost` to mean the Windows host or another container.
- Avoid changing database passwords, grants, or volumes until the specific failure is identified.

### Kafka connection failure

- Verify the broker is running and the host listener is published.
- Test the relevant host port from Windows with `Test-NetConnection localhost -Port <port>`.
- Check `SPRING_KAFKA_BOOTSTRAP_SERVERS` and Kafka's advertised listener configuration.
- Review logs for repeated disconnects, group-join failures, and missing partition assignments.

### Secret is missing or Vault sync is unhealthy

```powershell
kubectl get vaultstaticsecret -n gwatcho-local
kubectl describe vaultstaticsecret <vault-static-secret-name> -n gwatcho-local
kubectl get secret <destination-secret-name> -n gwatcho-local
```

Check Vault policy, VaultAuth, Kubernetes auth role, destination Secret name, and expected key names without printing secret values.

## 10. Roll back an application Deployment

If a new Deployment revision fails and the previous revision is known to be good:

```powershell
kubectl rollout history deployment/order-service -n gwatcho-local
kubectl rollout undo deployment/order-service -n gwatcho-local
kubectl rollout status deployment/order-service -n gwatcho-local --timeout=180s
```

Repeat for the affected service only. Confirm the image and configuration restored are the intended known-good revision. Deployment rollback does not roll back database schema or data. Never delete the Docker Compose database volumes as part of application rollback.

## 11. Current verified milestone

The local `order-service` Deployment has successfully rolled out. Its Actuator health endpoint reported `UP`, including the MySQL component, liveness, and readiness. Kafka logs showed the broker cluster ID and group coordinator discovery; verify stable group membership and actual event processing during end-to-end tests.

Record future verification results here as the remaining services and checkout flow are tested.