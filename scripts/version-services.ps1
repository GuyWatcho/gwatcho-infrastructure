param(
    [string]$Version = "1.0.0",
    [string]$Workspace = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
)

$ErrorActionPreference = "Stop"

$services = @(
    @{ Name = "user-service"; Path = "gwatcho-user-service"; Type = "maven" },
    @{ Name = "product-service"; Path = "gwatcho-product-service"; Type = "maven" },
    @{ Name = "order-service"; Path = "gwatcho-order-service"; Type = "maven" },
    @{ Name = "payment-service"; Path = "gwatcho-payment-service"; Type = "maven" },
    @{ Name = "delivery-service"; Path = "gwatcho-delivery-service"; Type = "maven" },
    @{ Name = "api-gateway"; Path = "gwatcho-api-gateway"; Type = "maven" },
    @{ Name = "angular-frontend"; Path = "gwatcho-angular-frontend"; Type = "npm" }
)

Write-Host "Setting GWatcho application versions to $Version" -ForegroundColor Cyan

foreach ($service in $services) {
    $repoPath = Join-Path $Workspace $service.Path
    if (-not (Test-Path $repoPath)) {
        throw "Repository folder not found: $repoPath"
    }

    Push-Location $repoPath
    try {
        if ($service.Type -eq "maven") {
            if (-not (Test-Path "pom.xml")) {
                throw "pom.xml not found in $repoPath"
            }

            # Update only the project's direct <version> element. A child POM
            # may inherit its version from <parent>; versions:set fails in that case.
            $pomPath = (Resolve-Path "pom.xml").Path
            [xml]$pomXml = Get-Content -Raw -Path $pomPath
            $project = $pomXml.DocumentElement
            $namespaceUri = $project.NamespaceURI

            $projectVersion = $project.SelectSingleNode("./*[local-name()='version']")
            if ($null -eq $projectVersion) {
                $projectVersion = $pomXml.CreateElement("version", $namespaceUri)
                $projectArtifactId = $project.SelectSingleNode("./*[local-name()='artifactId']")
                if ($null -eq $projectArtifactId) {
                    throw "Could not find the project's direct artifactId in $pomPath"
                }
                [void]$project.InsertAfter($projectVersion, $projectArtifactId)
            }
            $projectVersion.InnerText = $Version

            $settings = New-Object System.Xml.XmlWriterSettings
            $settings.Indent = $true
            $settings.Encoding = New-Object System.Text.UTF8Encoding($false)
            $writer = [System.Xml.XmlWriter]::Create($pomPath, $settings)
            try {
                $pomXml.Save($writer)
            } finally {
                $writer.Dispose()
            }

            & mvn -q -N validate
            if ($LASTEXITCODE -ne 0) {
                throw "Maven POM validation failed after version update for $($service.Name)"
            }
        } else {
            if (-not (Test-Path "package.json")) {
                throw "package.json not found in $repoPath"
            }
            & npm pkg set "version=$Version"
            if ($LASTEXITCODE -ne 0) {
                throw "package.json version update failed for $($service.Name)"
            }
            if (Test-Path "package-lock.json") {
                & npm install --package-lock-only --ignore-scripts
                if ($LASTEXITCODE -ne 0) {
                    throw "package-lock.json version sync failed for $($service.Name)"
                }
            }
        }
        Write-Host "Updated $($service.Name) to $Version" -ForegroundColor Green
    } finally {
        Pop-Location
    }
}

# Keep local infrastructure image tags aligned with the application release.
$envPath = Join-Path $PSScriptRoot "..\.env"
$envExamplePath = Join-Path $PSScriptRoot "..\.env.example"
if (-not (Test-Path $envPath)) {
    Copy-Item $envExamplePath $envPath
    Write-Host "Created .env from .env.example"
}
$versionKeys = @(
    "GWATCHO_USER_SERVICE_VERSION",
    "GWATCHO_PRODUCT_SERVICE_VERSION",
    "GWATCHO_ORDER_SERVICE_VERSION",
    "GWATCHO_PAYMENT_SERVICE_VERSION",
    "GWATCHO_DELIVERY_SERVICE_VERSION",
    "GWATCHO_API_GATEWAY_VERSION",
    "GWATCHO_ANGULAR_FRONTEND_VERSION"
)
$lines = Get-Content $envPath
foreach ($key in $versionKeys) {
    $pattern = "^\s*$([regex]::Escape($key))="
    $replacement = "$key=$Version"
    $found = $false
    $lines = @($lines | ForEach-Object {
        if ($_ -match $pattern) {
            $found = $true
            $replacement
        } else {
            $_
        }
    })
    if (-not $found) {
        $lines += $replacement
    }
}
Set-Content -Path $envPath -Value $lines -Encoding utf8

Write-Host ""
Write-Host "Version update complete. Review changes in all seven repositories and in gwatcho-infrastructure." -ForegroundColor Cyan
Write-Host "This script does not create Git commits or tags."
