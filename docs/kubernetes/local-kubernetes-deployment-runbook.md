# Local Kubernetes Deployment Runbook

This runbook documents the local Docker Desktop Kubernetes workflow for `user-service`, `product-service`, and `order-service`.

## Scope and safety

- Run commands from the `gwatcho-infrastructure` repository in Windows PowerShell.
- Target namespace: `gwatcho-local`.
- Verify the current Kubernetes context before applying changes.
- Keep the existing Docker Compose environment and named volumes intact. Never run `docker compose down --volumes` as part of this workflow.
- Never commit passwords, tokens, decoded Secret values, or kubeconfig contents.

## 1. Verify the cluster

```powershell
kubectl config current-context
kubectl cluster-info
kubectl get nodes
kubectl create namespace gwatcho-local --dry-run=client -o yaml | kubectl apply -f -
```

Proceed only when the selected context is the intended local cluster.

## 2. Verify Vault and image-pull secrets

```powershell
kubectl get vaultstaticsecrets -n gwatcho-local
kubectl get secrets -n gwatcho-local
kubectl get secret ghcr-pull-secret -n gwatcho-local
```

Confirm that the VaultStaticSecret resources are synchronized and healthy and that each destination Secret exists before restarting its Deployment. Do not print Secret values.

## 3. Apply service manifests

Run each Kustomize directory separately:

```powershell
kubectl apply -k .\kubernetes\base\user-service
kubectl apply -k .\kubernetes\base\product-service
kubectl apply -k .\kubernetes\base\order-service
```

Use `kubectl apply -k <directory>` for a directory containing `kustomization.yaml`.

## 4. Wait for rollouts

```powershell
kubectl rollout status deployment/user-service -n gwatcho-local --timeout=180s
kubectl rollout status deployment/product-service -n gwatcho-local --timeout=180s
kubectl rollout status deployment/order-service -n gwatcho-local --timeout=180s
```

## 5. Inspect deployments, pods, services, and events

```powershell
kubectl get deployments,services,pods -n gwatcho-local -o wide
kubectl get events -n gwatcho-local --sort-by=.lastTimestamp
```

Investigate failed probes, missing Secrets, `ImagePullBackOff`, `CrashLoopBackOff`, or repeated restarts before continuing.

## 6. Review logs and health

```powershell
kubectl logs deployment/user-service -n gwatcho-local --tail=100
kubectl logs deployment/product-service -n gwatcho-local --tail=100
kubectl logs deployment/order-service -n gwatcho-local --tail=100
```

The following examples assume these actuator context paths are configured in the corresponding applications:

```powershell
kubectl exec deployment/user-service -n gwatcho-local -- sh -c 'wget -qO- http://localhost:8080/user-service/actuator/health'
kubectl exec deployment/product-service -n gwatcho-local -- sh -c 'wget -qO- http://localhost:8080/product-service/actuator/health'
kubectl exec deployment/order-service -n gwatcho-local -- sh -c 'wget -qO- http://localhost:8080/order-service/actuator/health'
```

Expected result is `"status":"UP"`; inspect database details as well. Actuator health alone does not prove Kafka event processing or end-to-end checkout.

## 7. Test through port forwarding

Run this in a dedicated PowerShell window and leave it open:

```powershell
kubectl port-forward service/order-service 8082:8080 -n gwatcho-local
```

In a second window:

```powershell
Invoke-RestMethod http://localhost:8082/order-service/actuator/health
```

Use the actual Service name and a different local port when testing another service. Stop forwarding with Ctrl+C. Use the actual authenticated API contract and request schema when testing business endpoints.

## 8. Verify Kafka separately

```powershell
kubectl exec deployment/order-service -n gwatcho-local -- printenv SPRING_KAFKA_BOOTSTRAP_SERVERS
kubectl logs deployment/order-service -n gwatcho-local --since=5m |
  Select-String -Pattern 'Successfully joined group|assigned partitions|Bootstrap broker|disconnected|ERROR|Exception'
```

Check that the configured bootstrap address is reachable from Kubernetes and that Kafka advertises a listener the pod can reach. Broker metadata discovery is useful evidence, but confirm group membership and actual event processing.

## 9. Troubleshooting

```powershell
kubectl describe deployment order-service -n gwatcho-local
kubectl describe pods -n gwatcho-local
kubectl get events -n gwatcho-local --sort-by=.lastTimestamp
kubectl logs deployment/order-service -n gwatcho-local --tail=200
```

**Database failures:** verify the database container is running, the JDBC host port/database name are correct, the database exists, and the Vault-synchronized Secret has the expected key names. Do not expose secret values.

**Kafka failures:** check broker status, published host port, `SPRING_KAFKA_BOOTSTRAP_SERVERS`, advertised listeners, and consumer logs.

**Vault failures:** inspect VaultStaticSecret status, VaultAuth, Vault policy, and destination Secret names without printing credentials.

## 10. Roll back a failed Deployment

```powershell
kubectl rollout history deployment/order-service -n gwatcho-local
kubectl rollout undo deployment/order-service -n gwatcho-local
kubectl rollout status deployment/order-service -n gwatcho-local --timeout=180s
```

Roll back only the affected service and confirm the restored revision is known good. A Deployment rollback does not roll back database schema or data. Never delete Compose volumes as part of application rollback.

## Current validation milestone

The local `order-service` Deployment successfully rolled out and its Actuator health response reported `UP`, including MySQL, liveness, and readiness. Kafka logs showed the broker cluster ID and group coordinator discovery. Continue verifying stable consumer group membership, event processing, and end-to-end checkout.
