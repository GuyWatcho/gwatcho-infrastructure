 
$ErrorActionPreference = "Stop"

$Namespace = "gwatcho-local"
$SecretName = "product-db-secret"
$TempPatchFile = Join-Path $env:TEMP "mysql-product-secret-patch.json"
$BSTR = [IntPtr]::Zero

try {
    # Prompt securely for the MySQL root password
    $SecurePassword = Read-Host "Enter the MySQL root password for mysql-product" -AsSecureString
    $BSTR = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
    $RootPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($BSTR)

    if ([string]::IsNullOrWhiteSpace($RootPassword)) {
        throw "Root password cannot be empty."
    }

    # Verify that the Secret exists
    kubectl get secret $SecretName -n $Namespace -o name | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Secret '$SecretName' does not exist in namespace '$Namespace'."
    }

    # Encode the password and create a valid JSON merge patch
    $EncodedPassword = [Convert]::ToBase64String(
        [Text.Encoding]::UTF8.GetBytes($RootPassword)
    )

    $PatchObject = @{
        data = @{
            MYSQL_ROOT_PASSWORD = $EncodedPassword
        }
    }

    $PatchJson = ConvertTo-Json -InputObject $PatchObject -Depth 5
    Set-Content -Path $TempPatchFile -Value $PatchJson -Encoding utf8

    # Apply the patch from the JSON file
    kubectl patch secret $SecretName `
        -n $Namespace `
        --type merge `
        --patch-file $TempPatchFile

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to update Kubernetes Secret."
    }

    Write-Host "MYSQL_ROOT_PASSWORD updated successfully in Secret '$SecretName'."
}
finally {
    if (Test-Path $TempPatchFile) {
        Remove-Item $TempPatchFile -Force
    }

    if ($BSTR -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    }

    $RootPassword = $null
    $EncodedPassword = $null
    $PatchJson = $null
    $PatchObject = $null
    $SecurePassword = $null
}
 