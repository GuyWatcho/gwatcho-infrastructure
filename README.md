# GWatcho e-Commerce Infrastructure

Local Docker Compose environment and Kubernetes manifests for the GWatcho e-commerce microservices platform.

## Project documentation

- [Architecture overview](docs/portfolio/architecture.md)
- [Final application architecture — Docker Desktop Kubernetes](docs/portfolio/final-architecture.md)
- [End-to-end demo checklist](docs/portfolio/demo-checklist.md)
- [Local Kubernetes deployment — v1.1.0](docs/kubernetes/local-kubernetes-deployment.md)
- [Local Kubernetes deployment runbook](docs/kubernetes/local-kubernetes-deployment-runbook.md)
- [Kubernetes release roadmap](docs/kubernetes/local-kubernetes-release-plan.md)
- [Kubernetes manifests and Product Service guide](kubernetes/README.md)
- [CI/CD Angular deployment](docs/ci-cd-angular-deployment.md)

## What this repository contains

- Docker Compose configuration for five MySQL databases, Kafka, Keycloak, five backend services, the API Gateway, and Angular frontend.
- Kubernetes manifests and local deployment documentation.
- Keycloak realm and user import files.
- Product seed SQL containing 300 sample products.
- Example environment variables and PowerShell helper scripts.

## Repository layout

This repository expects the application repositories to be checked out as sibling folders under the same parent directory:

```text
MicroServicesApp/
├── gwatcho-infrastructure/
├── gwatcho-user-service/
├── gwatcho-product-service/
├── gwatcho-order-service/
├── gwatcho-payment-service/
├── gwatcho-delivery-service/
├── gwatcho-api-gateway/
└── gwatcho-angular-frontend/
```

The Compose file builds each application from its sibling repository and expects a `Dockerfile` at that repository's root. If your local folder names or Dockerfile locations differ, update the corresponding `build.context` or `build.dockerfile` entries in `docker-compose.yml`.

See [docs/versioning.md](docs/versioning.md) for application versions and Docker image tags. Run `scripts/version-services.ps1` to apply the versions.

## CI/CD deployment

Application repositories own their build and test workflows. The Angular frontend is built, tested, published to GitHub Container Registry (GHCR), and deployed to local Kubernetes by the configured Windows self-hosted GitHub Actions runner.

See [docs/ci-cd-angular-deployment.md](docs/ci-cd-angular-deployment.md) for the pipeline stages, runner setup, image tags, deployment commands, verification steps, and troubleshooting.

## Prerequisites

- Docker Desktop with Docker Compose v2 and Kubernetes enabled for the local Kubernetes environment.
- `kubectl` configured for the intended cluster context.
- All seven application repositories checked out in the sibling layout above when using the Compose build workflow.
- Ports required by the selected local environment available.

## Start the Docker Compose platform (Windows PowerShell)

From this directory:

```powershell
Copy-Item .env.example .env
# Edit .env with local development values, then:
docker compose config
docker compose up --build -d
docker compose ps
```

Or run:

```powershell
.\scripts\start.ps1
```

The first build can take several minutes. Check logs if a service does not become healthy:

```powershell
docker compose logs -f
docker compose logs -f user-service
docker compose logs -f api-gateway
```

## Docker Compose local endpoints

| Component | URL / port |
|---|---|
| Angular frontend | http://localhost/ |
| API Gateway | http://localhost:8085 |
| Keycloak | http://localhost:8080 |
| Kafka host listener | localhost:9092 |
| User MySQL | localhost:3307 |
| Product MySQL | localhost:3308 |
| Order MySQL | localhost:3309 |
| Payment MySQL | localhost:3310 |
| Delivery MySQL | localhost:3311 |

Within the Docker network, backend services connect to MySQL using service DNS names (for example, `mysql-user:3306`) and Kafka using `kafka:9092`. Backend containers listen on port `8080`; the API Gateway is exposed on host port `8085`.

## Keycloak

The Compose service starts Keycloak in development mode and imports the realm files from `docker/keycloak/import`. Development-mode credentials default to `admin` / `admin` unless overridden in `.env`. Do not use these defaults in a shared or production environment.

The realm import file may contain realm/client configuration and development test identities. Review it before using this setup with real users or credentials.

## Product seed data

`docker/mysql/product/products.sql` contains 300 product inserts for `product_db`. It is kept as an explicit seed script rather than automatically mounted into MySQL's initialization directory: the `products` table must exist before the inserts run.

Avoid re-running the script against a database that already contains the same SKUs; the inserts may fail on unique constraints.

## Stop the Docker Compose platform

```powershell
docker compose down
```

This keeps named volumes and their database contents. To remove the local databases, Kafka data, and Keycloak data as well:

```powershell
docker compose down --volumes
```

**Warning:** `down --volumes` permanently deletes the data stored in these Compose volumes.

Or run `.\scripts\stop.ps1` to stop containers without deleting volumes.

## Security notes

- This repository is for local development and demo deployment, not production deployment.
- Change all default passwords in `.env`; never commit `.env`.
- Use a proper secret store and TLS for production.
- Keycloak uses `start-dev`; configure production mode, hostname, HTTPS, and a persistent production database before deployment.
- Confirm that the realm's issuer URLs and frontend redirect URLs match your environment.
- Exposed MySQL and Kafka ports are for local developer access; restrict or remove them for shared deployments.
- Never commit kubeconfig files, tokens, decoded Kubernetes Secret values, passwords, or private keys.

## Kubernetes and release roadmap

The local Docker Desktop Kubernetes deployment baseline is documented in [docs/kubernetes/local-kubernetes-deployment.md](docs/kubernetes/local-kubernetes-deployment.md). The component and network topology is documented in [docs/portfolio/final-architecture.md](docs/portfolio/final-architecture.md). The staged release roadmap is in [docs/kubernetes/local-kubernetes-release-plan.md](docs/kubernetes/local-kubernetes-release-plan.md).

The local Kubernetes deployment is the v1.1.0 milestone. The next planned infrastructure milestone is migration to Azure Kubernetes Service (AKS). The existing Docker Compose environment remains documented and available as a separate local workflow.
