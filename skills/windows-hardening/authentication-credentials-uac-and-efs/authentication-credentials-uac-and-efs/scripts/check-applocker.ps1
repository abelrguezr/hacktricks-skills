# Check AppLocker Policy Configuration
# Run this script to enumerate AppLocker rules on a Windows system

Write-Host "=== AppLocker Policy Check ===" -ForegroundColor Cyan

try {
    # Get effective policy
    $policy = Get-AppLockerPolicy -Effective -ErrorAction Stop
    
    Write-Host "`nRule Collections:" -ForegroundColor Yellow
    $policy.RuleCollections | ForEach-Object {
        Write-Host "  - $($_.FileTypes)" -ForegroundColor White
    }
    
    # Check registry location
    $regPath = "HKLM:\Software\Policies\Microsoft\Windows\SrpV2"
    if (Test-Path $regPath) {
        Write-Host "`nRegistry path exists: $regPath" -ForegroundColor Green
    } else {
        Write-Host "`nRegistry path not found: $regPath" -ForegroundColor Red
    }
    
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
