
$repositories = @(
    "GuyWatcho/gwatcho-payment-service",
    "GuyWatcho/gwatcho-delivery-service",
    "GuyWatcho/gwatcho-angular-frontend",
    "GuyWatcho/gwatcho-api-gateway"
)

$variables = @{
    "KUBECONFIG"     = "C:\ProgramData\GitHubActionsRunner\kube\config"
    "KUBE_CONTEXT"   = "docker-desktop"
    "KUBE_NAMESPACE" = "gwatcho-local"
}

# Check GitHub CLI authentication
gh auth status
if ($LASTEXITCODE -ne 0) {
    throw "GitHub CLI is not authenticated. Run: gh auth login"
}

foreach ($repo in $repositories) {
    Write-Host "`nConfiguring $repo..." -ForegroundColor Cyan

    foreach ($variable in $variables.Keys) {
        gh variable set $variable `
            --body $variables[$variable] `
            --repo $repo

        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to configure $variable in $repo"
        }
        else {
            Write-Host "  Configured: $variable" -ForegroundColor Green
        }
    }
}

Write-Host "`nConfiguration completed." -ForegroundColor Green
