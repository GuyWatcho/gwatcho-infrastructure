# Kubernetes deployment area

This directory contains the staged Kubernetes implementation of GWatcho Shop. The local Docker Compose environment remains the baseline and must be kept intact while Kubernetes workloads are validated.

## Local deployment runbook

Follow the [Local Kubernetes Deployment Runbook](../docs/kubernetes/local-kubernetes-deployment-runbook.md) for Windows PowerShell instructions to:

- Verify the local cluster and `gwatcho-local` namespace.
- Check Vault-synchronized database Secrets and GHCR image-pull credentials.
- Apply the Kustomize manifests for `user-service`, `product-service`, and `order-service`.
- Wait for rollouts and inspect Deployments, Services, pods, events, and logs.
- Verify Actuator health, test using port-forwarding, and diagnose MySQL/Kafka connectivity.
- Roll back a failed Deployment without deleting database volumes.

The runbook reflects the current local development workflow. Confirm resource names, image tags, context paths, and runtime configuration against the manifests before applying changes.

## Intended structure

```text
kubernetes/
  README.md
  base/            # service manifests organized by workload
  charts/          # Helm chart, when introduced
  values/          # environment-specific values; never store real secrets
```

Read [Local Kubernetes and Release/Production Roadmap](../docs/kubernetes/local-kubernetes-release-plan.md) for the phases, acceptance criteria, release approval, and rollback strategy.

## Safety constraints

- Do not run `docker compose down --volumes` during Kubernetes deployment or rollback.
- Do not commit real passwords, tokens, private keys, decoded Secret values, or kubeconfig contents.
- Do not assume Compose-only DNS names such as `mysql-product` or `kafka` resolve from Kubernetes pods.
- Verify Kafka advertised listeners and database connectivity from the Kubernetes workload itself.
