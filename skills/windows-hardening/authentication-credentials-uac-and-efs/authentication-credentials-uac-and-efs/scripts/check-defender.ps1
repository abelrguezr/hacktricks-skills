# Check Microsoft Defender Status
# Run this script to check Defender configuration

Write-Host "=== Microsoft Defender Status Check ===" -ForegroundColor Cyan

try {
    $status = Get-MpComputerStatus -ErrorAction Stop
    
    Write-Host "`nKey Status:" -ForegroundColor Yellow
    Write-Host "  AntivirusEnabled: $($status.AntivirusEnabled)" -ForegroundColor White
    Write-Host "  AntispywareEnabled: $($status.AntispywareEnabled)" -ForegroundColor White
    Write-Host "  RealTimeProtectionEnabled: $($status.RealTimeProtectionEnabled)" -ForegroundColor White
    Write-Host "  AntispywareSignatureVersion: $($status.AntispywareSignatureVersion)" -ForegroundColor White
    Write-Host "  AntispywareSignatureLastUpdated: $($status.AntispywareSignatureLastUpdated)" -ForegroundColor White
    
    # Check service status
    Write-Host "`nService Status:" -ForegroundColor Yellow
    $service = Get-Service -Name windefend -ErrorAction SilentlyContinue
    if ($service) {
        Write-Host "  WinDefend Service: $($service.Status)" -ForegroundColor White
    }
    
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
