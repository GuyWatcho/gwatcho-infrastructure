
$ErrorActionPreference = "Stop"

# Resolve repository root (parent of custom-scripts)
$RepoRoot = Split-Path -Parent $PSScriptRoot

# Keycloak manifest directory
$KeycloakDir = Join-Path $RepoRoot "kubernetes\base\keycloak"

New-Item -ItemType Directory -Path $KeycloakDir -Force | Out-Null

Write-Host "Repository root: $RepoRoot"
Write-Host "Keycloak directory: $KeycloakDir"

# 1. namespace.yaml
@'
apiVersion: v1
kind: Namespace
metadata:
  name: gwatcho-local
'@ | Set-Content "$KeycloakDir\namespace.yaml" -Encoding utf8

# 2. deployment.yaml
@'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: keycloak
  namespace: gwatcho-local
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: keycloak
  template:
    metadata:
      labels:
        app: keycloak
    spec:
      containers:
        - name: keycloak
          image: quay.io/keycloak/keycloak:26.4
          args:
            - start-dev
            - --import-realm
          ports:
            - name: http
              containerPort: 8080
          env:
            - name: KC_BOOTSTRAP_ADMIN_USERNAME
              valueFrom:
                secretKeyRef:
                  name: keycloak-admin-secret
                  key: KC_BOOTSTRAP_ADMIN_USERNAME
            - name: KC_BOOTSTRAP_ADMIN_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: keycloak-admin-secret
                  key: KC_BOOTSTRAP_ADMIN_PASSWORD
            - name: KC_DB
              value: mysql
            - name: KC_DB_URL
              value: jdbc:mysql://mysql-keycloak:3306/keycloak_db
            - name: KC_DB_USERNAME
              valueFrom:
                secretKeyRef:
                  name: mysql-keycloak-secret
                  key: MYSQL_USER
            - name: KC_DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mysql-keycloak-secret
                  key: MYSQL_PASSWORD
            - name: KC_HTTP_ENABLED
              value: "true"
            - name: KC_HOSTNAME
              value: http://localhost:8080
          volumeMounts:
            - name: realm-import
              mountPath: /opt/keycloak/data/import/gwatcho-shop-realm.json
              subPath: gwatcho-shop-realm.json
              readOnly: true
            - name: realm-import
              mountPath: /opt/keycloak/data/import/gwatcho-shop-users-0.json
              subPath: gwatcho-shop-users-0.json
              readOnly: true
          resources:
            requests:
              cpu: 250m
              memory: 512Mi
            limits:
              memory: 1Gi
      volumes:
        - name: realm-import
          secret:
            secretName: keycloak-realm-import
'@ | Set-Content "$KeycloakDir\deployment.yaml" -Encoding utf8

# 3. service.yaml
@'
apiVersion: v1
kind: Service
metadata:
  name: keycloak
  namespace: gwatcho-local
spec:
  type: ClusterIP
  selector:
    app: keycloak
  ports:
    - name: http
      port: 8080
      targetPort: 8080
'@ | Set-Content "$KeycloakDir\service.yaml" -Encoding utf8

# 4. kustomization.yaml
@'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: gwatcho-local
resources:
  - namespace.yaml
  - deployment.yaml
  - service.yaml
'@ | Set-Content "$KeycloakDir\kustomization.yaml" -Encoding utf8

Write-Host "`nKeycloak Kubernetes manifests created successfully!" -ForegroundColor Green
Get-ChildItem $KeycloakDir
