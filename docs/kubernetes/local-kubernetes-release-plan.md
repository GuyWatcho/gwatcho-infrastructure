# Local Kubernetes and Release/Production Roadmap

## Goals and constraints

- Keep the existing Docker Compose deployment and named volumes operational.
- Do not rewrite application code or modify the existing application CI workflows.
- Introduce Kubernetes as a separate local environment on the Windows development PC.
- Use version tags and a manual approval gate for production releases.
- Promote the same tested container image digest through environments; do not rebuild a different image for production.

## Current baseline

The infrastructure Compose stack currently runs five MySQL instances, Kafka, Keycloak, five backend services, the API Gateway and Angular frontend. The product service listens on port 8083 with the `/product-service` context path in its default application configuration; Docker deployment configuration may override settings. Confirm each service's effective profile, ports, database URL, Kafka bootstrap address, issuer URL and health endpoint before authoring manifests.

## Architecture decision: isolate first

Initially, Kubernetes will run beside—not instead of—the current Compose stack. Do not run `docker compose down`, do not remove volumes, and do not move the Compose databases during the first Kubernetes milestone.

Important connectivity constraint: containers in a local Kubernetes cluster cannot use Compose-only DNS names such as `mysql-product` or `kafka` by default. The existing Kafka Compose configuration advertises `kafka:9092`; that advertised address is not resolvable from Kubernetes pods unless networking is explicitly designed for it. Before deploying an application service, define and test a host-reachable endpoint strategy for MySQL, Kafka and Keycloak. Do not assume `localhost` inside a pod refers to Windows or to a Compose container.

## Phases and acceptance criteria

### Phase 0 — Preserve the baseline

1. Record the current working Compose commit and image versions.
2. Run `docker compose config` and `docker compose ps`.
3. Smoke-test login, product browsing, checkout, payment/delivery event handling and persistence.
4. Save a known-good rollback reference. Do not use `docker compose down --volumes`.

**Exit criteria:** current Compose environment still passes its smoke tests.

### Phase 1 — Local cluster foundation

1. Install a supported local Kubernetes option (recommended first: kind, with Docker Desktop already running) and `kubectl`.
2. Create a cluster named `gwatcho-local`.
3. Verify `kubectl cluster-info` and `kubectl get nodes`.
4. Create a dedicated namespace such as `gwatcho-local`.
5. Add resource labels, image pull credentials for private GHCR packages where required, and a written connectivity test plan.
6. Do not deploy databases, Kafka or Keycloak into Kubernetes in this phase.

**Exit criteria:** cluster is healthy, namespace exists, and the pod-to-Compose networking plan is proven with a disposable connectivity test.

### Phase 2 — First workload: product service

1. Use the already published GHCR image, pinned to a commit SHA or version tag (never `latest` for a release).
2. Create a Deployment and ClusterIP Service.
3. Set required runtime configuration explicitly; keep credentials out of manifests and Git.
4. Configure startup/readiness/liveness probes only after verifying the actual actuator path and security behavior.
5. Add CPU/memory requests and limits after measuring a reasonable local baseline.
6. Verify pod logs, readiness, service discovery, database access, Kafka access, JWT issuer reachability and product API behavior.

**Exit criteria:** product API works through port-forward or the local ingress path and its required Compose dependencies remain healthy.

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

## Immediate next action

Complete Phase 0, then build and verify the local cluster foundation. Before creating a working product-service Deployment, prove how Kubernetes pods will reach the Compose MySQL/Kafka/Keycloak endpoints. This is the main technical dependency to resolve before writing runnable application manifests.
