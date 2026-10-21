# GWatcho Shop — Architecture Overview

## System context

GWatcho Shop is a containerized e-commerce demo built from separate application repositories and orchestrated locally with Docker Compose. The infrastructure repository includes the Compose environment, Nginx/API entry configuration, Keycloak realm imports, Kafka, five MySQL databases, seed data, and PowerShell helper scripts.

## Main components

- **Angular frontend** — product browsing, shopping cart, Keycloak sign-in, checkout, order history and order details.
- **API Gateway** — central entry point for backend API routing and Spring Security/JWT integration.
- **Product service** — product catalog and stock/inventory APIs backed by MySQL.
- **User service** — customer profiles and delivery addresses, with Keycloak OAuth2/JWT integration and MySQL persistence.
- **Order service** — order creation, checkout, order history/status and Kafka-based integration with other services; MySQL persistence.
- **Payment service** — payment requests/status and payment outcome events; MySQL persistence.
- **Delivery service** — delivery creation and shipment lifecycle/status events; MySQL persistence.
- **Keycloak** — identity provider and realm/client configuration.
- **Kafka** — asynchronous event transport between backend services.
- **MySQL** — separate database instances for user, product, order, payment and delivery data.
- **Docker Compose / Nginx** — local orchestration and HTTP entry/routing.

## High-level request and event paths

1. A customer uses the Angular application.
2. The frontend authenticates through Keycloak and sends API requests through the API Gateway.
3. The gateway routes requests to the relevant backend service; secured requests use JWT validation.
4. Services persist their own domain data in their corresponding MySQL database.
5. Order, payment and delivery workflows can communicate asynchronously through Kafka events.

Exact route predicates, topic names, event schemas, and transaction boundaries should be verified in the current service configuration/source before being documented as API contracts.

## Local development

From the infrastructure repository, configure `.env`, validate the Compose model, and start the stack:

```powershell
Copy-Item .env.example .env
# Edit .env with local development values
docker compose config
docker compose up --build -d
docker compose ps
```

The documented host endpoints include Angular at `http://localhost/`, Keycloak at `http://localhost:8080`, and the API Gateway at `http://localhost:8085`. Backend containers use Docker-network service names for MySQL and Kafka.

## Data safety and security

`docker compose down` stops containers while retaining named volumes. `docker compose down --volumes` also deletes persistent volume data. The Compose setup is for local development: replace default credentials, do not commit `.env`, and do not treat development-mode Keycloak settings as production-ready.

## CI/CD

Application repositories own their CI workflows. The infrastructure repository documents deployment configuration and is used by the Windows self-hosted deployment workflow. See [CI/CD Angular deployment](../ci-cd-angular-deployment.md) and [versioning](../versioning.md).
