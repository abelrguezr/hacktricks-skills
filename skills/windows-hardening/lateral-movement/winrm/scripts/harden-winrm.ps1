# WinRM Hardening Script
# Usage: .\harden-winrm.ps1 [-CertificateThumbprint <thumbprint>]
# WARNING: Backup your configuration before running!
# Purpose: Apply security hardening to WinRM configuration

param(
    [string]$CertificateThumbprint,
    [switch]$DryRun,
    [string]$Hostname = (hostname)
)

Write-Host "=== WinRM Hardening Script ===" -ForegroundColor Cyan
Write-Host "Target: $Hostname"
Write-Host "Mode: $((if($DryRun){'DRY RUN'}else{'LIVE'}))" -ForegroundColor $(if($DryRun){'Yellow'}else{'Green'})
Write-Host ""

# Function to execute commands
function Execute-Command {
    param($Command, $Description)
    Write-Host "[ACTION] $Description" -ForegroundColor Yellow
    if ($DryRun) {
        Write-Host "  Would execute: $Command" -ForegroundColor Gray
    } else {
        try {
            Invoke-Expression $Command
            Write-Host "  SUCCESS" -ForegroundColor Green
        } catch {
            Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# 1. Disable Basic Authentication
Write-Host "[1] Disabling Basic Authentication" -ForegroundColor Yellow
Execute-Command -Command "winrm set winrm/config/service/Auth @{Basic='false'}" -Description "Disable Basic authentication"

# 2. Enable Kerberos and NTLM
Write-Host "[2] Configuring Authentication Methods" -ForegroundColor Yellow
Execute-Command -Command "winrm set winrm/config/service/Auth @{Kerberos='true';Negotiate='true';NTLM='true'}" -Description "Enable Kerberos and NTLM authentication"

# 3. Disable Unencrypted Messages
Write-Host "[3] Disabling Unencrypted Messages" -ForegroundColor Yellow
Execute-Command -Command "winrm set winrm/config/service @{AllowUnencrypted='false'}" -Description "Disable unencrypted messages"

# 4. Set reasonable timeout
Write-Host "[4] Configuring Timeout" -ForegroundColor Yellow
Execute-Command -Command "winrm set winrm/config/service @{MaxTimeoutms='1800000'}" -Description "Set timeout to 30 minutes"

# 5. Enable logging
Write-Host "[5] Enabling WinRM Logging" -ForegroundColor Yellow
Execute-Command -Command "winrm set winrm/config/service @{EnableWinRMLogging='true'}" -Description "Enable WinRM logging"

# 6. Remove HTTP listener (if HTTPS certificate provided)
if ($CertificateThumbprint) {
    Write-Host "[6] Removing HTTP Listener" -ForegroundColor Yellow
    Execute-Command -Command "winrm delete winrm/config/listener?Address=*+Transport=HTTP" -Description "Remove HTTP listener"
    
    Write-Host "[7] Creating HTTPS Listener" -ForegroundColor Yellow
    Execute-Command -Command "winrm create winrm/config/listener?Address=*+Transport=HTTPS @{Hostname='$Hostname';CertificateThumbprint='$CertificateThumbprint'}" -Description "Create HTTPS listener"
} else {
    Write-Host "[6] Skipping HTTPS configuration (no certificate thumbprint provided)" -ForegroundColor Yellow
}

# 7. Configure client settings
Write-Host "[8] Configuring Client Settings" -ForegroundColor Yellow
Execute-Command -Command "winrm set winrm/config/client @{AllowUnencrypted='false'}" -Description "Disable unencrypted client messages"

Write-Host ""
Write-Host "=== Hardening Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "RECOMMENDED NEXT STEPS:" -ForegroundColor Yellow
Write-Host "1. Verify WinRM is still functional: Test-WSMan" -ForegroundColor White
Write-Host "2. Configure firewall rules to restrict access" -ForegroundColor White
Write-Host "3. Enable audit logging for WinRM events" -ForegroundColor White
Write-Host "4. Test remote connections from authorized systems" -ForegroundColor White
