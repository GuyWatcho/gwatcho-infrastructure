
$ErrorActionPreference = "Stop"
$Namespace = "gwatcho-local"

$Secrets = @(
    "product-db-secret" 
   # "user-db-secret",
   # "order-db-secret",
   # "payment-db-secret",
   # "delivery-db-secret"
)

foreach ($Secret in $Secrets) {
    Write-Host "`n=== Updating $Secret ===" -ForegroundColor Cyan

    # Verify that the Secret exists
    kubectl get secret $Secret "-n=$Namespace" -o name | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Secret not found; skipping $Secret"
        continue
    }

    $SecurePassword = Read-Host `
        "Enter the actual MySQL root password for $Secret" -AsSecureString

    $BSTR = [IntPtr]::Zero
    $TempFile = Join-Path $env:TEMP "$Secret-patch.json"

    try {
        $BSTR = [Runtime.InteropServices.Marshal]::SecureStringToBSTR(
            $SecurePassword
        )
        $Password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($BSTR)

        if ([string]::IsNullOrWhiteSpace($Password)) {
            throw "Password cannot be empty."
        }

        $EncodedPassword = [Convert]::ToBase64String(
            [Text.Encoding]::UTF8.GetBytes($Password)
        )

        $PatchJson = @{
            data = @{
                MYSQL_ROOT_PASSWORD = $EncodedPassword
            }
        } | ConvertTo-Json -Depth 5

        # Write UTF-8 without a BOM for reliable JSON parsing
        $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($TempFile, $PatchJson, $Utf8NoBom)

        kubectl patch secret $Secret `
            "-n=$Namespace" `
            --type=merge `
            "--patch-file=$TempFile"

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to update $Secret."
        }

        Write-Host "Updated $Secret successfully." -ForegroundColor Green
    }
    catch {
        Write-Warning "$Secret : $($_.Exception.Message)"
    }
    finally {
        if (Test-Path $TempFile) {
            Remove-Item $TempFile -Force
        }

        if ($BSTR -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
        }

        $Password = $null
        $EncodedPassword = $null
        $PatchJson = $null
        $SecurePassword = $null
    }
}

Write-Host "`nFinished processing Secrets."


# Check 

$Secrets | ForEach-Object {
    Write-Host "`n$_"
    kubectl get secret $_ -n $Namespace -o json |
        ConvertFrom-Json |
        ForEach-Object { $_.data.PSObject.Properties.Name }
}

Write-Host "`nFinished."