
# =====================================================
# Gwatcho Microservices - Apply Configuration & Restart
# =====================================================

$Namespace = "gwatcho-local"
$ConfigPath = ".\kubernetes\base"

$Deployments = @(
    "user-service",
    "product-service",
    "order-service",
    "payment-service",
    "delivery-service",
    "api-gateway",
    "angular-frontend"
)
 

# -----------------------------------------------------
# 1. Validate Kubernetes connection
# -----------------------------------------------------

Write-Host "`n[1/5] Checking Kubernetes connection..." -ForegroundColor Cyan

kubectl cluster-info

if ($LASTEXITCODE -ne 0) {
    throw "Cannot connect to Kubernetes cluster."
}

# -----------------------------------------------------
# 2. Apply Kubernetes configuration changes
# -----------------------------------------------------

Write-Host "`n[2/5] Applying Kubernetes configuration..." -ForegroundColor Cyan

if (-not (Test-Path $ConfigPath)) {
    throw "Configuration directory not found: $ConfigPath"
}


foreach ($Deployment in $Deployments) {

    Write-Host "`nApplying config for $Deployment ..." -ForegroundColor Yellow

    if ($Deployment -like '*service*') {
        # For all microservices
        $appConfigPath = Join-Path $ConfigPath "services\$Deployment"
    }
    else {
        # For api-gateway and angular-frontend
        $appConfigPath = Join-Path $ConfigPath $Deployment
    }

    # Check configuration directory
    if (-not (Test-Path $appConfigPath)) {
        throw "Configuration directory not found: $appConfigPath"
    }

    Write-Host "Applying: $appConfigPath" -ForegroundColor Gray

    # Apply Kubernetes configuration
    kubectl apply -k $appConfigPath -n $Namespace

    if ($LASTEXITCODE -ne 0) {
        throw "Kubernetes configuration apply failed. Restart cancelled: $Deployment"
    }
}





# -----------------------------------------------------
# 3. Restart microservices
# -----------------------------------------------------

Write-Host "`n[3/5] Restarting microservices..." -ForegroundColor Cyan

foreach ($Deployment in $Deployments) {

    Write-Host "`nRestarting $Deployment ..." -ForegroundColor Yellow

    kubectl rollout restart deployment/$Deployment -n $Namespace

    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Could not restart $Deployment"
    }
}

# -----------------------------------------------------
# 4. Wait for rollout completion
# -----------------------------------------------------

Write-Host "`n[4/5] Waiting for deployments..." -ForegroundColor Cyan

foreach ($Deployment in $Deployments) {

    Write-Host "`nChecking $Deployment ..." -ForegroundColor Yellow

    kubectl rollout status deployment/$Deployment `
        -n $Namespace `
        --timeout=180s

    if ($LASTEXITCODE -ne 0) {
        Write-Warning "$Deployment did not become ready within 180 seconds."
    }
}

# -----------------------------------------------------
# 5. Display final status
# -----------------------------------------------------

Write-Host "`n[5/5] Final deployment status..." -ForegroundColor Green

kubectl get deployments -n $Namespace
kubectl get pods -n $Namespace -o wide

Write-Host "`nKubernetes update and restart process completed." -ForegroundColor Green
