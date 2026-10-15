# GWatcho Infrastructure

Local Docker Compose environment for the GWatcho e-commerce microservices platform.

## What this repository contains

- Docker Compose configuration for five MySQL databases, Kafka, Keycloak, five backend services, the API Gateway, and Angular frontend.
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

See [docs/versioning.md](docs/versioning.md) for application versions and Docker image tags. Run `scripts/version-services.ps1` to apply the versions.\n\n## CI/CD deployment

The Angular frontend is built, tested, published to GitHub Container Registry (GHCR), and deployed automatically by the GitHub Actions workflow in `gwatcho-angular-frontend` after a successful push to `develop`.

See [docs/ci-cd-angular-deployment.md](docs/ci-cd-angular-deployment.md) for the pipeline stages, Windows self-hosted runner setup, image tags, deployment commands, verification steps, and troubleshooting.

## Prerequisites

- Docker Desktop with Docker Compose v2
- All seven application repositories checked out in the sibling layout above
- Ports 80, 8080, 8085, 9092, and 3307–3311 available

## Start the platform (Windows PowerShell)

From this directory:

```powershell
Copy-Item .env.example .env
# Edit .env if needed, then:
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

## Local endpoints

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

To import it after the product service has created the table, use a MySQL client against `localhost:3308`, selecting database `product_db`. Example:

```powershell
Get-Content .\docker\mysql\product\products.sql | docker exec -i gwatcho-mysql-product mysql -u product_user -pproduct_password product_db
```

If you changed the password in `.env`, replace `product_password` in the command accordingly. Avoid re-running the script against a database that already contains the same SKUs; the inserts may fail on unique constraints.

## Stop the platform

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

- This repository is for local development, not production deployment.
- Change all default passwords in `.env`; never commit `.env`.
- Use a proper secret store and TLS for production.
- Keycloak uses `start-dev`; configure production mode, hostname, HTTPS, and a persistent production database before deployment.
- Confirm that the realm's issuer URLs and frontend redirect URLs match your environment.
- Exposed MySQL and Kafka ports are for local developer access; restrict or remove them for shared deployments.

## Troubleshooting

```powershell
docker compose config
docker compose ps
docker compose logs --tail=200
```

If a container cannot connect to a database or Kafka, verify that it uses the Compose service hostname rather than `localhost`. Inside a container, `localhost` refers to that same container.
