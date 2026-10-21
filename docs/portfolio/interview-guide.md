# GWatcho Shop — Technical Interview Guide

## 60-second project summary

GWatcho Shop is a containerized e-commerce demo implemented as separate Angular and Spring Boot repositories. Angular provides the customer experience; Keycloak handles identity; a Spring Cloud API Gateway centralizes backend routing; product, user, order, payment and delivery services own distinct responsibilities and persist data in MySQL. Kafka supports asynchronous communication between backend workflows. Docker Compose brings the local environment together, while GitHub Actions builds/tests services, publishes container images to GHCR, and can deploy through a Windows self-hosted runner.

## Architecture topics to explain

### Why split services?
Separate repositories and service boundaries make responsibilities and release pipelines clearer. The trade-off is additional configuration, observability, network failure modes and integration testing.

### Why an API Gateway?
It gives the frontend a central backend entry point and a place to apply routing and security integration. The gateway is not a replacement for authorization checks inside protected services.

### Authentication and authorization
Keycloak acts as the identity provider. The frontend obtains tokens and sends bearer tokens to secured APIs. The gateway/service configuration must agree on the JWT issuer and signing keys. Explain the actual configured issuer, audience/claim rules and route authorization based on the current configuration—do not assume a claim is validated unless the code/config confirms it.

### Why Kafka?
Kafka decouples producers and consumers so services can react asynchronously to business events. Be ready to explain configured topics, keys, consumer groups, retries, duplicate delivery and failure recovery from the actual implementation.

### Data ownership and consistency
Each domain service has its own MySQL database in the Compose environment. Cross-service workflows are distributed; explain which steps are synchronous, which are event-driven, and how the code handles partial failure. Only describe the Transactional Outbox pattern as implemented where it is present in the relevant source.

### CI/CD
Describe the actual workflow stages: tests/build, container image publication to GHCR, and deployment from a self-hosted Windows runner using the infrastructure repository's Compose configuration. Explain branch/tag conventions and required repository secrets without revealing secret values.

## Questions to prepare for

1. How does a frontend request reach a backend service?
2. Where is JWT validation configured, and how do you debug an issuer mismatch?
3. What happens if a payment or delivery consumer is unavailable?
4. How do you prevent duplicate event processing?
5. How do you test services and database integration?
6. How do you deploy one service without rebuilding unrelated containers?
7. How do persistent volumes behave when containers are stopped or removed?
8. What would you improve before production (TLS, secret management, observability, health checks, backup/restore, resilience and security hardening)?

## Evidence to show

- A successful CI run and its test output.
- GHCR image and tag for the commit.
- Compose service status and relevant logs.
- A customer checkout/order flow.
- Kafka event processing using actual topic names from the running configuration.
- Persistence after a container restart without removing volumes.

Keep answers tied to the current code and observed demo results; distinguish implemented behavior from planned improvements.
