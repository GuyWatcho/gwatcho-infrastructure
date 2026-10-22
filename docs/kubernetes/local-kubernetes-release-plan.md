# Local Kubernetes and Release/Production Roadmap

## Goals and constraints

- Keep the existing Docker Compose deployment and named volumes operational.
- Do not rewrite application code or modify the existing application CI workflows.
- Introduce Kubernetes as a separate local environment on the Windows development PC.
- Use version tags and a manual approval gate for production releases.
- Promote the same tested container image digest through environments; do not rebuild a different image for production.

## Current baseline

The infrastructure Compose stack runs five MySQL instances, Kafka, Keycloak, five backend services, the API Gateway and Angular frontend. The product service listens on port 8083 with the `/product-service` context path in its default application configuration; Docker deployment configuration may override settings. Confirm each service's effective profile, ports, database URL, Kafka bootstrap address, issuer URL and health endpoint before authoring manifests.

## Architecture decision: isolate first

Initially, Kubernetes runs beside—not instead of—the current Compose stack. Do not run `docker compose down`, do not remove volumes, and do not move the Compose databases during the first Kubernetes milestone.

Important connectivity constraint: containers in a local Kubernetes cluster cannot use Compose-only DNS names such as `mysql-product` or `kafka` by default. Kafka metadata returns the broker address advertised for the listener the client used. The internal Compose listener advertises `kafka:9092`; Kubernetes clients use the dedicated external listener at `host.docker.internal:19092`. Do not assume `localhost` inside a pod refers to Windows or to a Compose container.

## Phases and acceptance criteria

### Phase 0 — Preserve the baseline

1. Record the current working Compose commit and image versions.
2. Run `docker compose config` and `docker compose ps`.
3. Smoke-test login, product browsing, checkout, payment/delivery event handling and persistence.
4. Save a known-good rollback reference. Do not use `docker compose down --volumes`.

**Exit criteria:** current Compose environment still passes its smoke tests.

### Phase 1 — Local cluster foundation

1. Enable Docker Desktop Kubernetes and install `kubectl`.
2. Verify `kubectl config current-context`, `kubectl cluster-info` and `kubectl get nodes`.
3. Create/use the dedicated namespace `gwatcho-local`.
4. Prove host access to the existing Compose dependencies without moving them into Kubernetes.
5. Keep local credentials out of Git.

**Exit criteria:** cluster is healthy, namespace exists, and pod-to-Compose connectivity is tested.

### Phase 2 — First workload: product service

The first Product Service workload is implemented in `kubernetes/base/product-service/` and applied through `kubernetes/overlays/local/`. See the runnable commands and troubleshooting steps in [Kubernetes Product Service deployment guide](../../kubernetes/README.md).

Implemented configuration:

- Deployment `product-service`, one replica, using the local development image `ghcr.io/guywatcho/gwatcho-product-service:develop-latest`.
- ClusterIP Service on port 8080.
- Runtime profile `docker`; MySQL at `host.docker.internal:3308/product_db`.
- MySQL username/password supplied by the cluster Secret `product-db-secret`, not stored in manifests.
- Kafka external listener `host.docker.internal:19092` for Kubernetes clients, while Docker Compose clients keep using `kafka:9092`.
- Startup, liveness and readiness HTTP probes at `/product-service/actuator/health`.

Validation completed for this local milestone:

- Kustomize client dry run and apply succeeded.
- Deployment rollout completed successfully and the Product Service Pod became ready.
- Actuator health returned `UP`; the Products API returned HTTP 200.
- Kafka consumer successfully joined the `product-service` consumer group after configuring the external listener.

**Boundary:** this is a verified local development workload, not a production-ready release. The mutable `develop-latest` image tag is acceptable only for this local exercise; pin a version tag or digest for a release.

### Phase 3 — Expand application workloads

Add one component at a time: user service, order service, payment service, delivery service, API Gateway and Angular frontend. After each addition, test the full integration path and verify that Compose data and containers have not changed. Introduce ingress and local TLS only after service routing is stable.

### Phase 4 — Helm packaging

Package Kubernetes resources into a Helm chart in this infrastructure repository. Keep local values separate from staging/production values. Templates must not contain real passwords, tokens, private keys or production data. Validate with `helm lint` and `helm template` before applying to a cluster.

### Phase 5 — Release pipeline (version tag + approval)

Implement only after local deployment and rollback are demonstrated:

1. Application CI remains responsible for tests and image publication.
2. A release tag (for example `v1.2.0`) identifies the release candidate. Validate tag format and ensure the tag points to the intended commit.
3. Resolve the exact image digest for every service in the release manifest. Do not use mutable branch tags such as `main-latest` for release deployment.
4. Run manifest/chart validation and staging smoke tests.
5. Require a GitHub Actions Environment approval (for example, `production`) before the production deployment job can run. Configure required reviewers in GitHub Environment settings; a YAML environment declaration alone does not create an approval rule.
6. Deploy the same image digests with Helm/kubectl to the target cluster.
7. Wait for rollout completion and run post-deployment smoke tests.
8. If checks fail, stop the pipeline and roll back to the previous known-good chart revision/image digests. Database schema/data rollback must be planned separately.

**Important local runner limitation:** a production job targeting a Kubernetes cluster on this Windows PC requires the machine, Docker engine, local cluster and self-hosted runner to be online. This is acceptable for a learning/demo environment, but it is not a highly available production hosting design.

## GitHub Actions and runner safety

- Keep the existing application CI/CD workflow files unchanged.
- Use a separate release workflow for Kubernetes once its target and permissions are tested.
- Give the deployment identity the minimum required Kubernetes RBAC permissions.
- Protect release tags and the production Environment with repository rules/required reviewers where available.
- Do not print tokens, kubeconfig contents or secret values in logs.
- Use GitHub Environment-scoped secrets/variables for production-specific configuration.
- Pin third-party Actions to reviewed versions or full commit SHAs according to your repository policy.

## Production-readiness boundary

A single Windows PC with a local cluster is a learning/staging target, not resilient production hosting. Before exposing the application publicly, plan a supported hosted Kubernetes service or other reliable host, TLS and DNS, durable database backups and restore drills, secrets management, monitoring/alerts, resource capacity, network policy, image vulnerability scanning, access controls and disaster recovery.

## Rollback

- Keep the existing Compose environment untouched until the Kubernetes environment passes end-to-end tests.
- For Kubernetes application rollback, retain previous chart revisions and image digests and use Helm rollback or a controlled deployment to the previous version.
- Do not roll back database schemas blindly; migrations must be backward-compatible or have a separately reviewed recovery plan.
- Never delete Compose volumes as part of an application rollback.

## Next actions

1. Review and merge the Product Service Kubernetes documentation/manifests change through a pull request.
2. Add resource requests/limits and pin the image by immutable version or digest before using this workload as a release artifact.
3. Test a deliberate pod restart and confirm probes and rollout behavior.
4. Plan the next service integration only after confirming that Compose remains healthy and that the first workload can be rolled back safely.
