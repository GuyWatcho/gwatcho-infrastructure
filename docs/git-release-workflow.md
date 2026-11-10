# Git release and branch workflow (PowerShell)

This runbook documents the Git operations used for the GWatcho local Kubernetes
release milestone across the six application repositories.

## Scope

Run these scripts from the common parent directory containing:

- `gwatcho-user-service`
- `gwatcho-product-service`
- `gwatcho-order-service`
- `gwatcho-payment-service`
- `gwatcho-delivery-service`
- `gwatcho-api-gateway`

The examples use:

- Release tag: `v1.1.0`
- Release branch: `release/v1.1.0-local.kubernetes`
- Integration branches: `develop` and `main`

> **Safety:** Start with clean working trees and review each repository's changes.
> The scripts stop on Git errors. They do not force-push or discard local changes.
> Run the merge script only after the release changes have been reviewed and
> accepted for `main`. If branch protection requires pull requests, use the
> GitHub PR workflow instead of pushing directly to `main`.

## 1. Merge develop into main

This script updates local refs, checks that each working tree is clean, fast-forwards
local `main` to `origin/main`, merges `origin/develop` using fast-forward only,
and pushes the updated `main`.

Save as `scripts/merge-develop-into-main.ps1` or run from the parent directory:

```powershell
$ErrorActionPreference = "Stop"

$repos = @(
    "gwatcho-user-service",
    "gwatcho-product-service",
    "gwatcho-order-service",
    "gwatcho-payment-service",
    "gwatcho-delivery-service",
    "gwatcho-api-gateway"
)

foreach ($repo in $repos) {
    Write-Host "`n=== $repo ===" -ForegroundColor Cyan
    if (!(Test-Path $repo)) { throw "Repository not found: $repo" }

    Push-Location $repo
    try {
        $status = git status --porcelain
        if ($LASTEXITCODE -ne 0) { throw "Cannot inspect $repo" }
        if ($status) { throw "Working tree is not clean in $repo. Commit or stash changes first." }

        git fetch origin --prune
        if ($LASTEXITCODE -ne 0) { throw "Fetch failed in $repo" }

        git switch main
        if ($LASTEXITCODE -ne 0) { throw "Cannot switch to main in $repo" }

        git pull --ff-only origin main
        if ($LASTEXITCODE -ne 0) { throw "Cannot fast-forward main in $repo" }

        git merge --ff-only origin/develop
        if ($LASTEXITCODE -ne 0) { throw "develop cannot be fast-forwarded into main in $repo. Resolve/review manually." }

        git push origin main
        if ($LASTEXITCODE -ne 0) { throw "Push failed in $repo" }

        Write-Host "$repo: main updated." -ForegroundColor Green
    }
    finally { Pop-Location }
}
```

If `main` is protected, create a pull request from `develop` to `main`,
complete required checks/reviews, and merge it on GitHub. Do not disable branch
protection to run this script.

## 2. Create the release branch and annotated tag

Run after `main` contains the approved release commit. The script checks that
the tag and branch do not already exist remotely, creates the release branch
from `origin/main`, creates an annotated tag at the same commit, and pushes
both refs.

```powershell
$ErrorActionPreference = "Stop"

$repos = @(
    "gwatcho-user-service",
    "gwatcho-product-service",
    "gwatcho-order-service",
    "gwatcho-payment-service",
    "gwatcho-delivery-service",
    "gwatcho-api-gateway"
)

$tag = "v1.1.0"
$releaseBranch = "release/v1.1.0-local.kubernetes"

foreach ($repo in $repos) {
    Write-Host "`n=== $repo ===" -ForegroundColor Cyan
    if (!(Test-Path $repo)) { throw "Repository not found: $repo" }

    Push-Location $repo
    try {
        $status = git status --porcelain
        if ($LASTEXITCODE -ne 0) { throw "Cannot inspect $repo" }
        if ($status) { throw "Working tree is not clean in $repo" }

        git fetch origin --prune --tags
        if ($LASTEXITCODE -ne 0) { throw "Fetch failed in $repo" }

        git switch main
        if ($LASTEXITCODE -ne 0) { throw "Cannot switch to main in $repo" }
        git pull --ff-only origin main
        if ($LASTEXITCODE -ne 0) { throw "Cannot update main in $repo" }

        git ls-remote --exit-code --heads origin $releaseBranch *> $null
        if ($LASTEXITCODE -eq 0) { throw "Remote branch $releaseBranch already exists in $repo" }

        git ls-remote --exit-code --tags origin "refs/tags/$tag" *> $null
        if ($LASTEXITCODE -eq 0) { throw "Remote tag $tag already exists in $repo" }

        git switch -c $releaseBranch origin/main
        if ($LASTEXITCODE -ne 0) { throw "Could not create release branch in $repo" }
        git push -u origin $releaseBranch
        if ($LASTEXITCODE -ne 0) { throw "Could not push release branch in $repo" }

        git tag -a $tag origin/main -m "GWatcho $repo $tag - Local Kubernetes Deployment"
        if ($LASTEXITCODE -ne 0) { throw "Could not create tag in $repo" }
        git push origin $tag
        if ($LASTEXITCODE -ne 0) { throw "Could not push tag in $repo" }

        Write-Host "$repo: release branch and tag pushed." -ForegroundColor Green
    }
    finally { Pop-Location }
}
```

Git tags are repository-local references: using the same tag name in six
repositories creates six separate tags, each pointing to that repository's
release commit. Create/publish the corresponding GitHub Release separately if
release notes are required.

## 3. Synchronize develop with main

After the release merge, update `develop` so it includes the latest `main`.
This script preserves local work by requiring clean working trees, updates
`develop` from its remote, fast-forwards it to `origin/main`, and pushes it.

```powershell
$ErrorActionPreference = "Stop"

$repos = @(
    "gwatcho-user-service",
    "gwatcho-product-service",
    "gwatcho-order-service",
    "gwatcho-payment-service",
    "gwatcho-delivery-service",
    "gwatcho-api-gateway"
)

foreach ($repo in $repos) {
    Write-Host "`n=== $repo ===" -ForegroundColor Cyan
    if (!(Test-Path $repo)) { throw "Repository not found: $repo" }

    Push-Location $repo
    try {
        $status = git status --porcelain
        if ($LASTEXITCODE -ne 0) { throw "Cannot inspect $repo" }
        if ($status) { throw "Working tree is not clean in $repo. Commit or stash changes first." }

        git fetch origin --prune
        if ($LASTEXITCODE -ne 0) { throw "Fetch failed in $repo" }

        git switch develop
        if ($LASTEXITCODE -ne 0) { throw "Cannot switch to develop in $repo" }

        git pull --ff-only origin develop
        if ($LASTEXITCODE -ne 0) { throw "Cannot update develop in $repo" }

        git merge --ff-only origin/main
        if ($LASTEXITCODE -ne 0) { throw "develop cannot be fast-forwarded to main in $repo. Review divergence manually." }

        git push origin develop
        if ($LASTEXITCODE -ne 0) { throw "Push failed in $repo" }

        git status -sb
        Write-Host "$repo: develop synchronized." -ForegroundColor Green
    }
    finally { Pop-Location }
}
```

### Verify branch synchronization

After running the synchronization script:

```powershell
foreach ($repo in $repos) {
    Push-Location $repo
    git fetch origin
    if ($LASTEXITCODE -ne 0) { throw "Fetch failed in $repo" }

    Write-Host "$repo"
    git rev-list --left-right --count origin/main...origin/develop
    if ($LASTEXITCODE -ne 0) { throw "Verification failed in $repo" }
    Pop-Location
}
```

Expected output for each repository is `0 0`: neither branch is ahead of the
other. The release branch remains a separate snapshot and is not modified by
this synchronization.

## Tag naming changes

Git does not rename a tag in place. To change a tag name, create and push a new
tag at the exact same commit, verify it, and only then delete the old local and
remote tags. Before deleting an old tag, check whether a published GitHub
Release or deployment workflow refers to it; GitHub Releases must be updated
separately.

Example for one repository (review the target commit and names before running):

```powershell
$oldTag = "v1.1.0"
$newTag = "v1.1.0-local.kubernetes"

git fetch origin --tags
git rev-parse "$oldTag^{commit}"
git tag $newTag $oldTag
git push origin $newTag

# Only after confirming the new remote tag exists:
git ls-remote --tags origin "refs/tags/$newTag"
git push origin --delete $oldTag
git tag -d $oldTag
```

Do not use this tag-renaming example blindly across repositories: verify that
each repository has the old tag and that the new tag name is not already used.
