# Angular Frontend on Kubernetes

## Overview

The Angular frontend is deployed in the local Kubernetes cluster in namespace `gwatcho-local`. Its Deployment and Service are managed by Kustomize in:

```text
kubernetes/base/angular-frontend/
├── deployment.yaml
├── kustomization.yaml
└── service.yaml
```

The frontend uses the GHCR image `ghcr.io/guybami/gwatcho-angular-frontend:develop-latest`, the existing `ghcr-pull-secret`, one replica, and an internal ClusterIP Service on port 80.

This step does not change Nginx, Keycloak, backend services, or database volumes.

## Apply the manifests

Run from the local `gwatcho-infrastructure` repository in PowerShell:

```powershell
kubectl kustomize .\kubernetes\base\angular-frontend
kubectl apply -k .\kubernetes\base\angular-frontend
kubectl rollout status deployment/angular-frontend -n gwatcho-local --timeout=180s
```

## Verify the deployment

```powershell
kubectl get deployments,pods,services -n gwatcho-local |
  Select-String "angular-frontend"
```

Expected healthy state:

- Deployment: `1/1` available
- Pod: `1/1 Running`
- Service: `ClusterIP`, port `80/TCP`

## Test the frontend locally

Start port forwarding in one PowerShell terminal and leave it running:

```powershell
kubectl port-forward -n gwatcho-local svc/angular-frontend 4201:80
```

In a second terminal, request the frontend:

```powershell
Invoke-WebRequest -Uri "http://localhost:4201/" -UseBasicParsing |
  Select-Object StatusCode, StatusDescription
```

Or open `http://localhost:4201/` in a browser. A successful HTTP response confirms that the frontend is serving its page; also check the browser UI and developer console for application or API errors.

## Inspect the deployed image

```powershell
kubectl get deployment angular-frontend -n gwatcho-local -o jsonpath='{.spec.template.spec.containers[0].image}'
```

## Notes

- The manifest assumes the frontend container serves HTTP on port 80. If the image uses another port, update the Deployment and Service consistently.
- A healthy Pod does not by itself prove that API requests or Keycloak login work.
- Browser code cannot normally resolve Kubernetes-only service names such as `api-gateway`. Configure the frontend to use browser-reachable URLs exposed by the existing proxy and identity-provider setup.
- Keep changes scoped to the Angular frontend. Do not remove or recreate Nginx, Keycloak, backend services, or database volumes as part of this deployment.
