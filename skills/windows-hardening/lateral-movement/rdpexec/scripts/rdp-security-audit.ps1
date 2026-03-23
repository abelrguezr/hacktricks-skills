# RDP Security Audit - PowerShell Script for RDP Security Assessment
# Usage: .\rdp-security-audit.ps1 [-Target <IP>] [-OutputFile <path>]
# Note: Run locally to audit current machine, or via RDP session on target

param(
    [Parameter(Mandatory=$false)]
    [string]$Target,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputFile
)

# Security Warning
Write-Warning "WARNING: Only run this audit on systems you own or have explicit authorization to assess."

$auditResults = @()
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Write-Host "RDP Security Audit - Started at $timestamp" -ForegroundColor Cyan
Write-Host "=" * 60

# Check 1: Is RDP enabled?
Write-Host "[1/8] Checking if RDP is enabled..." -ForegroundColor Yellow
try {
    $rdpEnabled = Get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections' -ErrorAction Stop
    $isRdpEnabled = ($rdpEnabled.fDenyTSConnections -eq 0)
    $auditResults += @{
        Check = "RDP Enabled"
        Status = if ($isRdpEnabled) { "ENABLED" } else { "DISABLED" }
        Risk = if ($isRdpEnabled) { "MEDIUM" } else { "LOW" }
        Details = "fDenyTSConnections = $($rdpEnabled.fDenyTSConnections)"
    }
    Write-Host "  RDP is $((if ($isRdpEnabled) { 'ENABLED' } else { 'DISABLED' }))" -ForegroundColor $(if ($isRdpEnabled) { 'Yellow' } else { 'Green' })
} catch {
    Write-Host "  Error checking RDP status: $_" -ForegroundColor Red
}

# Check 2: Network Level Authentication (NLA)
Write-Host "[2/8] Checking Network Level Authentication..." -ForegroundColor Yellow
try {
    $nlaSetting = Get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name 'UserAuthentication' -ErrorAction Stop
    $nlaEnabled = ($nlaSetting.UserAuthentication -eq 1)
    $auditResults += @{
        Check = "Network Level Authentication"
        Status = if ($nlaEnabled) { "ENABLED" } else { "DISABLED" }
        Risk = if ($nlaEnabled) { "LOW" } else { "HIGH" }
        Details = "UserAuthentication = $($nlaSetting.UserAuthentication)"
    }
    Write-Host "  NLA is $((if ($nlaEnabled) { 'ENABLED' } else { 'DISABLED' }))" -ForegroundColor $(if ($nlaEnabled) { 'Green' } else { 'Red' })
} catch {
    Write-Host "  Error checking NLA: $_" -ForegroundColor Red
}

# Check 3: RDP Port
Write-Host "[3/8] Checking RDP port configuration..." -ForegroundColor Yellow
try {
    $rdpPort = Get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name 'PortNumber' -ErrorAction Stop
    $auditResults += @{
        Check = "RDP Port"
        Status = "Port $($rdpPort.PortNumber)"
        Risk = if ($rdpPort.PortNumber -eq 3389) { "MEDIUM" } else { "LOW" }
        Details = "Default port (3389) is more likely to be scanned"
    }
    Write-Host "  RDP Port: $($rdpPort.PortNumber)" -ForegroundColor $(if ($rdpPort.PortNumber -eq 3389) { 'Yellow' } else { 'Green' })
} catch {
    Write-Host "  Error checking RDP port: $_" -ForegroundColor Red
}

# Check 4: Encryption Level
Write-Host "[4/8] Checking encryption level..." -ForegroundColor Yellow
try {
    $encryption = Get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name 'MinEncryptionLevel' -ErrorAction Stop
    $auditResults += @{
        Check = "Encryption Level"
        Status = "Level $($encryption.MinEncryptionLevel)"
        Risk = if ($encryption.MinEncryptionLevel -ge 3) { "LOW" } else { "HIGH" }
        Details = "Higher values = stronger encryption (3 = FIPS compliant)"
    }
    Write-Host "  Encryption Level: $($encryption.MinEncryptionLevel)" -ForegroundColor $(if ($encryption.MinEncryptionLevel -ge 3) { 'Green' } else { 'Yellow' })
} catch {
    Write-Host "  Error checking encryption: $_" -ForegroundColor Red
}

# Check 5: RDP Services
Write-Host "[5/8] Checking RDP-related services..." -ForegroundColor Yellow
$rdpServices = @('TermService', 'UmRdpService', 'SessionEnv')
foreach ($service in $rdpServices) {
    try {
        $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
        if ($svc) {
            $auditResults += @{
                Check = "Service: $service"
                Status = $svc.Status
                Risk = "INFO"
                Details = "StartupType: $($svc.StartType)"
            }
            Write-Host "  $service: $($svc.Status)" -ForegroundColor Gray
        }
    } catch {}
}

# Check 6: Firewall Rules
Write-Host "[6/8] Checking firewall rules for RDP..." -ForegroundColor Yellow
try {
    $firewallRules = Get-NetFirewallRule -DisplayName "*RemoteDesktop*" -ErrorAction SilentlyContinue
    if ($firewallRules) {
        $enabledRules = $firewallRules | Where-Object {$_.Enabled -eq 'True'}
        $auditResults += @{
            Check = "RDP Firewall Rules"
            Status = "$($enabledRules.Count) enabled"
            Risk = "INFO"
            Details = "$(($enabledRules | Select-Object -ExpandProperty DisplayName) -join ', ')"
        }
        Write-Host "  Found $($enabledRules.Count) enabled RDP firewall rules" -ForegroundColor Gray
    }
} catch {
    Write-Host "  Error checking firewall: $_" -ForegroundColor Red
}

# Check 7: Active RDP Sessions
Write-Host "[7/8] Checking active RDP sessions..." -ForegroundColor Yellow
try {
    $sessions = qwinsta 2>$null
    if ($sessions) {
        $activeSessions = ($sessions | Select-String "Active" | Measure-Object).Count
        $auditResults += @{
            Check = "Active RDP Sessions"
            Status = "$activeSessions active"
            Risk = if ($activeSessions -gt 5) { "MEDIUM" } else { "LOW" }
            Details = "Multiple active sessions may indicate shared access"
        }
        Write-Host "  Active sessions: $activeSessions" -ForegroundColor Gray
    }
} catch {
    Write-Host "  Error checking sessions: $_" -ForegroundColor Red
}

# Check 8: Account Lockout Policy
Write-Host "[8/8] Checking account lockout policy..." -ForegroundColor Yellow
try {
    $lockoutPolicy = Get-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name 'AutoLockLogonTimeout' -ErrorAction SilentlyContinue
    $auditResults += @{
        Check = "Auto-Lock Policy"
        Status = "Configured"
        Risk = "INFO"
        Details = "AutoLockLogonTimeout = $($lockoutPolicy.AutoLockLogonTimeout)"
    }
    Write-Host "  Auto-lock timeout configured" -ForegroundColor Gray
} catch {
    Write-Host "  No auto-lock policy found" -ForegroundColor Yellow
}

# Summary
Write-Host ""
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "Audit Summary" -ForegroundColor Cyan
Write-Host "=" * 60

$highRisk = ($auditResults | Where-Object {$_.Risk -eq "HIGH"}).Count
$mediumRisk = ($auditResults | Where-Object {$_.Risk -eq "MEDIUM"}).Count

Write-Host "High Risk Findings: $highRisk" -ForegroundColor $(if ($highRisk -gt 0) { 'Red' } else { 'Green' })
Write-Host "Medium Risk Findings: $mediumRisk" -ForegroundColor $(if ($mediumRisk -gt 0) { 'Yellow' } else { 'Green' })

# Export results
if ($OutputFile) {
    $auditResults | ConvertTo-Json -Depth 5 | Out-File $OutputFile
    Write-Host ""
    Write-Host "Results exported to: $OutputFile" -ForegroundColor Green
}

Write-Host ""
Write-Host "Audit completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
