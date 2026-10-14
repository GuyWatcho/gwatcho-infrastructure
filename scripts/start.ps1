$ErrorActionPreference = "Stop"

if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host "Created .env from .env.example. Review credentials before continuing."
}

docker compose config
if ($LASTEXITCODE -ne 0) { throw "Docker Compose configuration validation failed." }

docker compose up --build -d
if ($LASTEXITCODE -ne 0) { throw "Docker Compose failed to start the platform." }

docker compose ps
