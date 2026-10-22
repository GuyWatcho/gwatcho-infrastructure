# Kubernetes deployment area

This directory is reserved for the staged Kubernetes implementation of GWatcho Shop.

The first iteration deliberately starts with a plan rather than runnable application manifests. The current Compose services use internal DNS names and Kafka advertises `kafka:9092`; Kubernetes pods will not automatically resolve those Compose names. A working connectivity strategy must be tested before application Deployments are added.

Read [Local Kubernetes and Release/Production Roadmap](../docs/kubernetes/local-kubernetes-release-plan.md) for phases, acceptance criteria, release approval and rollback strategy.

## Intended structure

```text
kubernetes/
  README.md
  charts/          # Helm chart added after first workload is proven
  values/          # local/staging/production values; never store real secrets
```

The current Docker Compose environment remains the working baseline and must not be stopped or have its volumes removed during initial Kubernetes work.
