# NTLM Configuration Checker
# Run as Administrator to check current NTLM security settings

Write-Host "=== NTLM Security Configuration Check ===" -ForegroundColor Cyan
Write-Host ""

# Check LMCompatibilityLevel
Write-Host "[1] LMCompatibilityLevel:" -ForegroundColor Yellow
$lmLevel = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "LMCompatibilityLevel" -ErrorAction SilentlyContinue
if ($lmLevel) {
    $value = $lmLevel.LMCompatibilityLevel
    Write-Host "    Current Value: $value" -ForegroundColor $(if ($value -ge 5) { "Green" } else { "Red" })
    
    $levels = @(
        "0 - Send LM & NTLM responses",
        "1 - Send LM & NTLM responses, use NTLMv2 session security if negotiated",
        "2 - Send NTLM response only",
        "3 - Send NTLMv2 response only",
        "4 - Send NTLMv2 response only, refuse LM",
        "5 - Send NTLMv2 response only, refuse LM & NTLM (RECOMMENDED)"
    )
    if ($value -ge 0 -and $value -le 5) {
        Write-Host "    Setting: $($levels[$value])" -ForegroundColor White
    }
    
    if ($value -lt 5) {
        Write-Host "    WARNING: Consider setting to 5 for maximum security" -ForegroundColor Red
    }
} else {
    Write-Host "    Not configured (default)" -ForegroundColor Yellow
}

Write-Host ""

# Check NTLMMinClientSec
Write-Host "[2] NTLMMinClientSec:" -ForegroundColor Yellow
$ntlmMin = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0" -Name "NTLMMinClientSec" -ErrorAction SilentlyContinue
if ($ntlmMin) {
    $value = $ntlmMin.NTLMMinClientSec
    Write-Host "    Current Value: 0x$value" -ForegroundColor White
    Write-Host "    (0x08000000 = Require NTLMv2 session security)" -ForegroundColor Gray
} else {
    Write-Host "    Not configured" -ForegroundColor Yellow
}

Write-Host ""

# Check RestrictSendingNTLMTraffic
Write-Host "[3] RestrictSendingNTLMTraffic:" -ForegroundColor Yellow
$restrict = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RestrictSendingNTLMTraffic" -ErrorAction SilentlyContinue
if ($restrict) {
    $value = $restrict.RestrictSendingNTLMTraffic
    Write-Host "    Current Value: $value" -ForegroundColor $(if ($value -eq 2) { "Green" } else { "Yellow" })
    
    $restrictValues = @(
        "0 - No restriction",
        "1 - Restrict to trusted subnets only",
        "2 - Restrict to all (RECOMMENDED)"
    )
    if ($value -ge 0 -and $value -le 2) {
        Write-Host "    Setting: $($restrictValues[$value])" -ForegroundColor White
    }
} else {
    Write-Host "    Not configured (default: 0)" -ForegroundColor Yellow
}

Write-Host ""

# Check SMB Signing
Write-Host "[4] SMB Signing:" -ForegroundColor Yellow
$smbSign = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "RequireSecuritySignature" -ErrorAction SilentlyContinue
if ($smbSign) {
    $value = $smbSign.RequireSecuritySignature
    Write-Host "    RequireSecuritySignature: $value" -ForegroundColor $(if ($value -eq 1) { "Green" } else { "Yellow" })
    Write-Host "    (1 = Required, 0 = Optional)" -ForegroundColor Gray
} else {
    Write-Host "    Not configured" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Recommendations ===" -ForegroundColor Cyan
Write-Host "1. Set LMCompatibilityLevel to 5" -ForegroundColor White
Write-Host "2. Set NTLMMinClientSec to 0x08000000" -ForegroundColor White
Write-Host "3. Set RestrictSendingNTLMTraffic to 2" -ForegroundColor White
Write-Host "4. Enable SMB signing (RequireSecuritySignature = 1)" -ForegroundColor White
Write-Host "5. Apply CVE-2025-33073 patch" -ForegroundColor White
Write-Host ""
