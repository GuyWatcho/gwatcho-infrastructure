# Service versioning

All seven independently versioned applications start at `1.0.0`.

| Repository | Application version file | Docker image |
|---|---|---|
| `gwatcho-user-service` | `pom.xml` | `ghcr.io/guybami/gwatcho-user-service:1.0.0` |
| `gwatcho-product-service` | `pom.xml` | `ghcr.io/guybami/gwatcho-product-service:1.0.0` |
| `gwatcho-order-service` | `pom.xml` | `ghcr.io/guybami/gwatcho-order-service:1.0.0` |
| `gwatcho-payment-service` | `pom.xml` | `ghcr.io/guybami/gwatcho-payment-service:1.0.0` |
| `gwatcho-delivery-service` | `pom.xml` | `ghcr.io/guybami/gwatcho-delivery-service:1.0.0` |
| `gwatcho-api-gateway` | `pom.xml` | `ghcr.io/guybami/gwatcho-api-gateway:1.0.0` |
| `gwatcho-angular-frontend` | `package.json` and `package-lock.json` | `ghcr.io/guybami/gwatcho-angular-frontend:1.0.0` |

The Compose file uses the matching `GWATCHO_*_VERSION` variable for each image tag. `.env.example` defaults every service to `1.0.0`.

## Apply application versions

From this repository, run the script with the parent folder that contains all seven sibling repositories:

```powershell
.\scriptsersion-services.ps1 -Version 1.0.0 -Workspace "D:\Projects\Java\IntelliJ_WS\MicroServicesApp"
```

The script writes the direct project `<version>` element in each backend/gateway `pom.xml` (adding it when the version was inherited from a parent), validates the POM with Maven, and uses `npm pkg set` plus `npm install --package-lock-only` to update the Angular version and lockfile. It also updates the seven image version variables in this repository's `.env`.

Review all changes before committing. The script does not create commits, Git tags, or push anything.

## Build images

From this repository:

```powershell
docker compose config
docker compose up --build -d
docker compose images
```

The Compose `image:` entries tag locally built images with the version selected in `.env`. These tags do not publish images automatically. To publish later, authenticate to GitHub Container Registry and run `docker compose push`.

## Release convention

Use semantic versioning (`MAJOR.MINOR.PATCH`):

- Patch: backward-compatible fixes, e.g. `1.0.1`
- Minor: backward-compatible features, e.g. `1.1.0`
- Major: incompatible API or behavior changes, e.g. `2.0.0`

Version services independently when they do not share a coordinated release. Update the relevant `GWATCHO_*_VERSION` in `.env` for the infrastructure deployment being tested.
