# Angular Frontend CI/CD Deployment

## 1. Overview

This document describes the Continuous Integration and Continuous Deployment (CI/CD) pipeline for the Angular frontend of the Gwatcho Microservices Demo Application.

The pipeline automatically builds, tests, publishes, and deploys the Angular frontend after a successful push to the `develop` branch.

### Technology stack

- GitHub Actions
- Angular and Node.js 24
- Docker and Docker Compose
- GitHub Container Registry (GHCR)
- Windows 11
- Docker Desktop with WSL2
- Self-hosted GitHub Actions runner

### Repositories

| Repository | Responsibility |
|---|---|
| `gwatcho-angular-frontend` | Angular source code, CI workflow, Docker image publishing and deployment workflow |
| `gwatcho-infrastructure` | Docker Compose configuration, environment variables and running infrastructure |

## 2. CI/CD Architecture

The deployment pipeline consists of four stages:

1. **Build Angular** — installs npm dependencies and builds the Angular application.
2. **Run Angular Tests** — executes the unit tests using Chrome Headless.
3. **Publish Docker Image to GHCR** — builds and publishes the frontend container image.
4. **Deploy Angular Frontend** — pulls the published image and updates the frontend container on the Windows deployment machine.

The first two jobs run on GitHub-hosted Ubuntu runners. Image publishing also runs on Ubuntu. Deployment runs on the self-hosted Windows runner.

### Pipeline flow

```text
Developer pushes to develop
            |
            v
     Build Angular
            |
            v
    Run Angular Tests
            |
            v
  Publish Docker Image
            |
            v
   GitHub Container Registry
            |
            v
  Windows Self-hosted Runner
            |
            v
      Docker Desktop
            |
            v
     angular-frontend
```

The deployment job depends on successful image publishing.

## 3. Docker Image

The frontend image is published to:

```text
ghcr.io/guybami/gwatcho-angular-frontend
```

The workflow uses branch-specific tags:

| Branch | Image tag |
|---|---|
| `develop` | `develop-latest` |
| `main` | `main-latest` |

For deployments to the local development environment, the image is:

```text
ghcr.io/guybami/gwatcho-angular-frontend:develop-latest
```

The image is built and published by GitHub Actions. It is not rebuilt locally during deployment.

## 4. Windows Self-hosted Runner

### Installation directory

```text
D:\actions-runner
```

### Runner configuration

| Setting | Value |
|---|---|
| Operating system | Windows x64 |
| Runner name | `windows-docker-runner` |
| Custom label | `docker-deploy` |
| Docker context | `desktop-linux` |
| Container engine | Docker Desktop |
| Container platform | Linux/amd64 |

The runner is registered to the repository:

`guybami/gwatcho-angular-frontend`

### Verify Docker access

Run these commands in the Windows environment used by the runner:

```powershell
docker context show
docker version
docker compose version
docker ps
```

The Docker client and server must both be accessible.

**Important:** Docker Desktop runs in a Windows user session. A runner service running as Local System may not be able to access the Docker Desktop engine. The working configuration must ensure that the runner and Docker Desktop can communicate. An interactively started runner requires its PowerShell window to remain open.

## 5. Infrastructure Configuration

The Docker Compose configuration is maintained in `gwatcho-infrastructure`.

The frontend service uses the following image setting:

```yaml
angular-frontend:
  image: ghcr.io/guybami/gwatcho-angular-frontend:${GWATCHO_ANGULAR_FRONTEND_VERSION:-1.0.0}
```

For automatic deployment from `develop`, configure the deployment machine's local `.env` file:

```dotenv
GWATCHO_ANGULAR_FRONTEND_VERSION=develop-latest
```

The Compose default remains `1.0.0` when the variable is not set.

The GitHub repository variable `INFRA_DIR` points to the local infrastructure repository directory on the deployment machine.

Example:

```text
D:\Projects\Java\IntelliJ_WS\MicroServicesApp\gwatcho-infrastructure
```

Do not commit secrets or private access tokens to `.env` or the repository.

## 6. GitHub Actions Workflow

Workflow file:

```text
gwatcho-angular-frontend/.github/workflows/ci.yml
```

The workflow runs CI on pushes and pull requests targeting `develop` or `main`.

Image publishing is restricted to pushes to these branches. The deployment job is restricted to pushes to `develop`.

The deployment job uses the following runner labels:

```yaml
runs-on: [self-hosted, Windows, X64, docker-deploy]
```

It depends on successful publishing:

```yaml
needs: publish-docker
```

The deployment job verifies Docker access, changes to the infrastructure directory, pulls the frontend image, and updates the frontend container.

## 7. Deployment Commands

The deployment workflow executes the equivalent of these commands:

```powershell
docker compose pull angular-frontend

docker compose up -d --no-build --no-deps angular-frontend

docker compose ps angular-frontend
```

The commands are executed from the infrastructure directory.

### Deployment safety

- Only `angular-frontend` is explicitly targeted.
- `--no-deps` prevents Compose from starting or recreating dependencies as part of this command.
- `--no-build` prevents a local frontend image build.
- The complete Compose stack is not taken down.
- Database volumes are not deleted.
- Keycloak, the backend services, and the existing Nginx API proxy configuration are preserved.

## 8. Verification

### Verify the published image

```powershell
docker manifest inspect ghcr.io/guybami/gwatcho-angular-frontend:develop-latest
```

A successful response contains the image manifest.

### Verify the resolved Compose image

```powershell
docker compose config --images
```

Confirm that the frontend resolves to:

```text
ghcr.io/guybami/gwatcho-angular-frontend:develop-latest
```

### Verify the running container

```powershell
docker compose ps angular-frontend
docker logs --tail 50 gwatcho-angular
```

Open the frontend in a browser:

```text
http://localhost/
```

Confirm that the application loads and that API requests through the existing Nginx proxy continue to work.

### Verify GitHub Actions

Open the Actions tab of `gwatcho-angular-frontend`.

A successful workflow run should show:

- Build Angular — Success
- Run Angular Tests — Success
- Publish Docker Image to GHCR — Success
- Deploy Angular Frontend — Success

## 9. Troubleshooting

### Manifest unknown

**Cause:** The image tag in Docker Compose does not match the published tag.

**Resolution:** Set `GWATCHO_ANGULAR_FRONTEND_VERSION=develop-latest` in the deployment machine's `.env` file and verify the resolved image.

### Docker daemon connection failure

**Cause:** The runner cannot access the Docker Desktop engine.

**Resolution:** Confirm Docker Desktop is running, check the Docker context, and verify that the runner's execution account can access the engine.

### PowerShell script-signing error

**Cause:** Windows PowerShell execution policy prevents execution of an unsigned temporary workflow script.

**Resolution:** Use the `cmd` shell for deployment steps where appropriate, rather than weakening the machine-wide execution policy.

### Runner offline

**Cause:** The runner is stopped, disconnected, or its interactive process has exited.

**Resolution:** Check the runner status under GitHub repository Settings → Actions → Runners and ensure Docker Desktop is available.

## 10. Operational Considerations

- Deployments are triggered automatically by pushes to `develop` after successful image publishing.
- The local development deployment is not automatically triggered by pushes to `main`.
- Docker Desktop and the self-hosted runner must be available for deployment to execute.
- A runner started interactively must remain running in its PowerShell window.
- Private GHCR packages require appropriate registry authentication.
- The deployment runner must be restricted to trusted workflows and contributors.

## 11. Current Status

The initial automated deployment has completed successfully.

Verified results:

- Angular build and unit tests passed.
- The frontend image was published to GHCR.
- The Windows self-hosted runner completed the deployment job.
- The Angular frontend is accessible at `http://localhost/`.

The deployment updates the frontend independently of the rest of the microservices infrastructure.
