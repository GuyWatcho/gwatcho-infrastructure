#requires -Version 5.1
<#
.SYNOPSIS
  Generates Kubernetes manifests for mysql-product and migrates product_db
  from the existing Docker container into Kubernetes.

.RUN
  Run from the gwatcho-infrastructure repository root:
    .\Migrate-ProductDb-To-Kubernetes.ps1

.SAFETY
  - Keeps the original Docker container and volume untouched.
  - Creates a SQL backup before importing.
  - Generates manifests in kubernetes/base/databases/mysql-product.
  - Updates the local Kustomize overlay to include the new database base.
  - Requires product-db-secret to contain MYSQL_ROOT_PASSWORD,
    SPRING_DATASOURCE_USERNAME, and SPRING_DATASOURCE_PASSWORD.
  - Imports and verifies data before switching product-service to mysql-product.
  - Does not print passwords.
#>
[CmdletBinding()]
param(
    [string]$Namespace = "gwatcho-local",
    [string]$DockerContainer = "gwatcho-mysql-product",
    [string]$DatabaseName = "product_db",
    [string]$TargetDirectory = ".\kubernetes\base\databases\mysql-product",
    [string]$OverlayPath = ".\kubernetes\overlays\local\kustomization.yaml",
    [string]$ProductDeployment = ".\kubernetes\base\services\product-service\deployment.yaml",
    [string]$BackupDirectory = ".\backups\mysql"
)

$ErrorActionPreference = "Stop"

function Step([string]$Message) {
    Write-Host "`n=== $Message ===" -ForegroundColor Cyan
}

function Write-Utf8NoBom([string]$Path, [string]$Content) {
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText((Join-Path (Get-Location) $Path), $Content, $encoding)
}

function Ensure-OverlayEntry([string]$Path, [string]$Entry) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing Kustomize overlay: $Path"
    }

    $content = Get-Content -LiteralPath $Path -Raw
    if ($content -match ('(?m)^\s*-\s*' + [regex]::Escape($Entry) + '\s*$')) {
        Write-Host "Overlay already includes $Entry"
        return
    }

    # Insert after resources: if present; otherwise stop rather than corrupt YAML.
    if ($content -notmatch '(?m)^resources:\s*$') {
        throw "Could not find a top-level 'resources:' list in $Path. Add '$Entry' manually after reviewing the overlay."
    }

    $content = [regex]::Replace(
        $content,
        '(?m)^resources:\s*$',
        "resources:`r`n  - $Entry",
        1
    )
    Write-Utf8NoBom $Path $content
    Write-Host "Added $Entry to $Path"
}

try {
    foreach ($cmd in @("docker", "kubectl", "git")) {
        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
            throw "Required command '$cmd' was not found."
        }
    }

    if (-not (Test-Path -LiteralPath $ProductDeployment)) {
        throw "Missing product-service Deployment manifest: $ProductDeployment"
    }
    if (-not (Test-Path -LiteralPath $OverlayPath)) {
        throw "Missing local Kustomize overlay: $OverlayPath"
    }

    Step "Preflight"
    $state = docker inspect $DockerContainer --format '{{.State.Status}}'
    if ($LASTEXITCODE -ne 0 -or $state -ne "running") {
        throw "Docker container '$DockerContainer' is not running."
    }

    $dbEnv = docker inspect $DockerContainer --format '{{range .Config.Env}}{{println .}}{{end}}' |
        Where-Object { $_ -like "MYSQL_DATABASE=*" } |
        Select-Object -First 1
    if ($dbEnv -and $dbEnv -ne "MYSQL_DATABASE=$DatabaseName") {
        throw "Container MYSQL_DATABASE is '$($dbEnv -replace '^MYSQL_DATABASE=','')', not '$DatabaseName'. Verify the database name."
    }

    kubectl get namespace $Namespace | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Namespace '$Namespace' not found."
    }

    $secretJson = kubectl get secret product-db-secret -n $Namespace -o json 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $secretJson) {
        throw "Kubernetes Secret product-db-secret is missing in '$Namespace'. Create it before continuing."
    }
    $secret = ($secretJson -join "`n") | ConvertFrom-Json
    $secretKeys = @($secret.data.PSObject.Properties.Name)
    $requiredApplicationKeys = @("SPRING_DATASOURCE_USERNAME", "SPRING_DATASOURCE_PASSWORD")
    $missingApplicationKeys = @($requiredApplicationKeys | Where-Object { $secretKeys -notcontains $_ })
    if ($missingApplicationKeys.Count -gt 0) {
        throw "Secret product-db-secret is missing required application key(s): $($missingApplicationKeys -join ', '). Add/verify them before continuing."
    }
    $hasRootPassword = $secretKeys -contains "MYSQL_ROOT_PASSWORD"
    if (-not $hasRootPassword) {
        Write-Warning "Secret product-db-secret does not yet contain MYSQL_ROOT_PASSWORD. The script will generate the manifests and backup, but it will stop before applying Kubernetes resources until you add that key."
    }

    # List deployments once and inspect JSON instead of querying a missing name.
    # This avoids treating the expected Kubernetes NotFound message as a PowerShell error.
    $deploymentListJson = kubectl get deployments -n $Namespace -o json
    if ($LASTEXITCODE -ne 0 -or -not $deploymentListJson) {
        throw "Could not list deployments in namespace '$Namespace'."
    }
    $deploymentList = ($deploymentListJson -join "`n") | ConvertFrom-Json
    $existingDeployment = @($deploymentList.items | Where-Object { $_.metadata.name -eq "mysql-product" })
    
	# Detect whether mysql-product already exists.
	# Reuse existing resources on reruns; never delete the database.
	$existingDeployment = kubectl get deployment mysql-product `
		-n $Namespace -o name 2>$null

	$deploymentExitCode = $LASTEXITCODE

	if ($deploymentExitCode -eq 0 -and $existingDeployment) {
		$MysqlProductExists = $true
		Write-Host "Deployment mysql-product already exists; reusing it." `
			-ForegroundColor Yellow
	}
	else {
		$MysqlProductExists = $false
		Write-Host "Deployment mysql-product does not exist; it will be created."
	}
	
    #Write-Host "Deployment mysql-product does not exist yet; manifest generation can continue."

    Write-Host "Source container: $DockerContainer ($state)"
    Write-Host "Database: $DatabaseName"
    Write-Host "Namespace: $Namespace"
    Write-Host "Secret product-db-secret exists and has the required keys."

    $answer = Read-Host "Type MIGRATE-PRODUCT to generate manifests and continue"
    if ($answer -cne "MIGRATE-PRODUCT") {
        Write-Host "Cancelled; no changes made."
        exit 0
    }

    Step "Create SQL backup"
    New-Item -ItemType Directory -Force -Path $BackupDirectory | Out-Null
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backup = Join-Path $BackupDirectory "$DatabaseName-$stamp.sql"

    # Capture dump as text; credentials are read from the source container environment.
    $dump = docker exec $DockerContainer sh -c 'exec mysqldump --user=root --password="$MYSQL_ROOT_PASSWORD" --single-transaction --routines --triggers --events --databases product_db 2>/dev/null'
    if ($LASTEXITCODE -ne 0 -or -not $dump) {
        throw "mysqldump failed; no Kubernetes resources have been applied."
    }
    # Write UTF-8 without a BOM so the MySQL client does not see a BOM as SQL text.
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines((Join-Path (Get-Location) $backup), [string[]]$dump, $utf8NoBom)
    if ((Get-Item -LiteralPath $backup).Length -lt 100) {
        throw "Backup file is unexpectedly small: $backup"
    }
    Write-Host "Backup created: $backup"
    Write-Host ("Backup size: {0:N0} bytes" -f (Get-Item -LiteralPath $backup).Length)

    Step "Generate mysql-product manifests"
    New-Item -ItemType Directory -Force -Path $TargetDirectory | Out-Null

    $pvcYaml = @'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-product-data
  namespace: gwatcho-local
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: hostpath
  resources:
    requests:
      storage: 5Gi
'@

    $deploymentYaml = @'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql-product
  namespace: gwatcho-local
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: mysql-product
  template:
    metadata:
      labels:
        app: mysql-product
    spec:
      containers:
        - name: mysql
          image: mysql:8.4
          imagePullPolicy: IfNotPresent
          ports:
            - name: mysql
              containerPort: 3306
          env:
            - name: MYSQL_DATABASE
              value: product_db
            - name: MYSQL_USER
              valueFrom:
                secretKeyRef:
                  name: product-db-secret
                  key: SPRING_DATASOURCE_USERNAME
            - name: MYSQL_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: product-db-secret
                  key: SPRING_DATASOURCE_PASSWORD
            - name: MYSQL_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: product-db-secret
                  key: MYSQL_ROOT_PASSWORD
          volumeMounts:
            - name: mysql-data
              mountPath: /var/lib/mysql
          startupProbe:
            exec:
              command:
                - sh
                - -c
                - 'mysqladmin ping -h 127.0.0.1 -uroot -p"$MYSQL_ROOT_PASSWORD"'
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 60
          readinessProbe:
            exec:
              command:
                - sh
                - -c
                - 'mysqladmin ping -h 127.0.0.1 -uroot -p"$MYSQL_ROOT_PASSWORD"'
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
          livenessProbe:
            exec:
              command:
                - sh
                - -c
                - 'mysqladmin ping -h 127.0.0.1 -uroot -p"$MYSQL_ROOT_PASSWORD"'
            initialDelaySeconds: 30
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
      volumes:
        - name: mysql-data
          persistentVolumeClaim:
            claimName: mysql-product-data
'@

    $serviceYaml = @'
apiVersion: v1
kind: Service
metadata:
  name: mysql-product
  namespace: gwatcho-local
spec:
  type: ClusterIP
  selector:
    app: mysql-product
  ports:
    - name: mysql
      port: 3306
      targetPort: 3306
'@

    $kustomizationYaml = @'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - pvc.yaml
  - deployment.yaml
  - service.yaml
'@

    $pvcYaml = $pvcYaml.Replace("namespace: gwatcho-local", "namespace: $Namespace")
    $deploymentYaml = $deploymentYaml.Replace("namespace: gwatcho-local", "namespace: $Namespace")
    $serviceYaml = $serviceYaml.Replace("namespace: gwatcho-local", "namespace: $Namespace")

    Write-Utf8NoBom (Join-Path $TargetDirectory "pvc.yaml") $pvcYaml
    Write-Utf8NoBom (Join-Path $TargetDirectory "deployment.yaml") $deploymentYaml
    Write-Utf8NoBom (Join-Path $TargetDirectory "service.yaml") $serviceYaml
    Write-Utf8NoBom (Join-Path $TargetDirectory "kustomization.yaml") $kustomizationYaml

    Ensure-OverlayEntry $OverlayPath "../../base/databases/mysql-product"

    Write-Host "`nGenerated files:"
    Get-ChildItem -LiteralPath $TargetDirectory -File |
        Select-Object -ExpandProperty FullName

    Step "Review and validate generated manifests"
    kubectl kustomize $TargetDirectory | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Kustomize validation failed. Review the generated YAML."
    }

    kubectl diff -k $TargetDirectory
    if ($LASTEXITCODE -gt 1) {
        # throw "kubectl diff failed."
		Write-Host "kubectl diff not installed on PC!!."
    }

    # Recheck the root password key immediately before creating the MySQL Pod.
    $secretJson = kubectl get secret product-db-secret -n $Namespace -o json
    if ($LASTEXITCODE -ne 0 -or -not $secretJson) {
        throw "Could not re-read product-db-secret. Manifests and SQL backup are retained; no resources were applied."
    }
    $secret = ($secretJson -join "`n") | ConvertFrom-Json
    $secretKeys = @($secret.data.PSObject.Properties.Name)
    if ($secretKeys -notcontains "MYSQL_ROOT_PASSWORD") {
        throw "Secret product-db-secret is missing MYSQL_ROOT_PASSWORD. Add it and rerun after reviewing the generated manifests. No Kubernetes resources were applied."
    }

    $apply = Read-Host "Type APPLY-MYSQL-PRODUCT to create mysql-product resources"
    if ($apply -cne "APPLY-MYSQL-PRODUCT") {
        throw "Stopped before applying Kubernetes resources. Manifests and SQL backup are retained."
    }

    Step "Apply database resources and wait for readiness"
    kubectl apply -k $TargetDirectory
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to apply mysql-product manifests."
    }

    kubectl rollout status deployment/mysql-product -n $Namespace --timeout=180s
    if ($LASTEXITCODE -ne 0) {
        throw "mysql-product did not become ready. Keep the original Docker database."
    }

    Step "Import SQL backup"
    # Copy the SQL file to the pod, then import inside the container. This avoids
    # PowerShell re-encoding the SQL stream while piping it to kubectl exec.
    $podName = kubectl get pods -n $Namespace -l app=mysql-product -o jsonpath='{.items[0].metadata.name}'
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace(($podName -join ""))) {
        throw "Could not find a mysql-product Pod for importing the backup."
    }
    $podName = ($podName -join "").Trim()
    kubectl cp $backup "$Namespace/$podName`:/tmp/product_db.sql"
    if ($LASTEXITCODE -ne 0) {
        throw "Could not copy SQL backup into mysql-product Pod."
    }
    kubectl exec $podName -n $Namespace -- sh -c 'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD" < /tmp/product_db.sql'
    if ($LASTEXITCODE -ne 0) {
        throw "Import failed. Do not switch product-service yet; inspect mysql-product logs and backup."
    }

    Step "Verify imported tables"
	# kubectl exec deployment/mysql-product -n gwatcho-local -- mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SHOW TABLES FROM product_db;"
    # kubectl exec deployment/mysql-product -n $Namespace -- mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SHOW TABLES FROM product_db;"
	
	$mysqlExitCode = $LASTEXITCODE
	
	$tableOutput = kubectl exec deployment/mysql-product -n gwatcho-local -- mysql -u root -proot4Web! -e "SHOW TABLES FROM product_db;"

	Write-Host "MySQL command exit code: $mysqlExitCode"
	Write-Host "MySQL output:"
	$tableOutput | ForEach-Object { Write-Host $_ }

	if ($mysqlExitCode -ne 0) {
		throw "MySQL table verification failed. Exit code: $mysqlExitCode"
	}

	if (-not ($tableOutput | Select-String -Pattern "Tables_in_product_db|^[a-zA-Z_]")) {
		throw "Database product_db exists, but no tables were detected."
	}
		
	
	if ($LASTEXITCODE -ne 0 -or -not $tableOutput) {
        throw "Could not verify product_db tables in Pod '$podName'."
    }
    $tableOutput | ForEach-Object { Write-Host $_ }
	
	
	
    if ($LASTEXITCODE -ne 0) {
        throw "Could not verify product_db tables."
    }

    Step "Prepare product-service datasource URL change"
    $deploymentText = Get-Content -LiteralPath $ProductDeployment -Raw
    $oldUrl = 'jdbc:mysql://host\.docker\.internal:3308/product_db\?serverTimezone=Europe/Berlin'
    $newUrl = 'jdbc:mysql://mysql-product:3306/product_db?serverTimezone=Europe/Berlin'

    if ($deploymentText -match [regex]::Escape($newUrl)) {
        Write-Host "product-service already references mysql-product."
    }
    elseif ($deploymentText -match $oldUrl) {
        $deploymentText = [regex]::Replace($deploymentText, $oldUrl, $newUrl)
        Write-Utf8NoBom $ProductDeployment $deploymentText
    }
    else {
        throw "Neither the expected Docker datasource URL nor the Kubernetes mysql-product URL was found in $ProductDeployment. Database is imported; product-service was not changed."
    }

    Write-Host "`nReview product-service change:"
    git diff -- $ProductDeployment
    $update = Read-Host "Type UPDATE-PRODUCT-SERVICE to apply the changed Deployment"
    if ($update -cne "UPDATE-PRODUCT-SERVICE") {
        Write-Warning "Database is imported, but product-service was not applied. Review the diff and apply manually."
        exit 0
    }

    Step "Apply product-service change"
    kubectl apply -f $ProductDeployment
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to apply product-service Deployment."
    }
    kubectl rollout status deployment/product-service -n $Namespace --timeout=180s
    if ($LASTEXITCODE -ne 0) {
        throw "product-service rollout failed. Keep the original Docker database for rollback."
    }

    Step "Final status"
    kubectl get deployment,service,pvc,pod -n $Namespace |
        Select-String "mysql-product|product-service"
    kubectl logs deployment/product-service -n $Namespace --since=5m

    Write-Host "`nMigration steps completed. Backup: $backup" -ForegroundColor Green
    Write-Host "Original Docker container '$DockerContainer' and its volume were not deleted or modified."
    Write-Host "Keep the Docker database until end-to-end validation and rollback planning are complete."
}
catch {
    Write-Error $_
    Write-Host "Migration stopped. Keep the original Docker database and volume; inspect the last completed step before retrying." -ForegroundColor Yellow
    exit 1
}
