# Check EFS Configuration
# Run this script to check EFS usage on a Windows system

Write-Host "=== EFS Configuration Check ===" -ForegroundColor Cyan

# Check if current user has used EFS
$efsPath = "$env:USERPROFILE\AppData\Roaming\Microsoft\Protect"

if (Test-Path $efsPath) {
    Write-Host "`nEFS path exists: $efsPath" -ForegroundColor Green
    Write-Host "Contents:" -ForegroundColor Yellow
    Get-ChildItem $efsPath -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Host "  - $($_.Name)" -ForegroundColor White
    }
} else {
    Write-Host "`nEFS path not found: $efsPath" -ForegroundColor Red
    Write-Host "User may not have used EFS encryption" -ForegroundColor Yellow
}

# Check for encrypted files in current directory
Write-Host "`nChecking for encrypted files in current directory..." -ForegroundColor Yellow
try {
    $files = Get-ChildItem -File -ErrorAction SilentlyContinue
    foreach ($file in $files) {
        $attrs = (Get-Item $file.FullName).Attributes
        if ($attrs -match "Encrypted") {
            Write-Host "  Encrypted: $($file.Name)" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "Error checking files: $_" -ForegroundColor Red
}
