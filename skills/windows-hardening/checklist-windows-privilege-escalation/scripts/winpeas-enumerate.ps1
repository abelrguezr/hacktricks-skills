#!/usr/bin/env pwsh
# Windows Privilege Escalation Enumeration Script
# Quick enumeration of common PE vectors

Write-Host "[*] Windows Privilege Escalation Enumeration" -ForegroundColor Cyan
Write-Host "[*] Starting enumeration at $(Get-Date)" -ForegroundColor Cyan
Write-Host ""

# System Information
Write-Host "[+] System Information" -ForegroundColor Yellow
systeminfo | Select-String "OS Name|OS Version|System Type|Build|Hotfix"
ver
whoami /all | Select-String "Privilege"
Write-Host ""

# User and Group Info
Write-Host "[+] User and Group Information" -ForegroundColor Yellow
whoami
net user
net localgroup administrators
Write-Host ""

# Check for Dangerous Privileges
Write-Host "[+] Dangerous Privileges Check" -ForegroundColor Yellow
$dangerous_privs = @(
    "SeImpersonatePrivilege",
    "SeAssignPrimaryPrivilege",
    "SeTcbPrivilege",
    "SeBackupPrivilege",
    "SeRestorePrivilege",
    "SeCreateTokenPrivilege",
    "SeLoadDriverPrivilege",
    "SeTakeOwnershipPrivilege",
    "SeDebugPrivilege"
)

$privs = whoami /priv | Select-String "Privilege"
foreach ($priv in $dangerous_privs) {
    if ($privs -match $priv) {
        Write-Host "[!] FOUND: $priv" -ForegroundColor Red
    }
}
Write-Host ""

# Security Features
Write-Host "[+] Security Features" -ForegroundColor Yellow

# UAC
$uac = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -ErrorAction SilentlyContinue
if ($uac) {
    Write-Host "UAC Enabled: $($uac.EnableLUA)"
}

# Credential Guard
$credguard = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "CredentialGuard" -ErrorAction SilentlyContinue
if ($credguard) {
    Write-Host "Credential Guard: $credguard.CredentialGuard"
}

# WDigest
$wdigest = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "UseLogonCredential" -ErrorAction SilentlyContinue
if ($wdigest) {
    Write-Host "WDigest Enabled: $wdigest.UseLogonCredential"
}

# LSA Protection
$lsaprotect = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPL" -ErrorAction SilentlyContinue
if ($lsaprotect) {
    Write-Host "LSA Protection: $lsaprotect.RunAsPPL"
}
Write-Host ""

# AlwaysInstallElevated
Write-Host "[+] AlwaysInstallElevated Check" -ForegroundColor Yellow
$alwaysinstall = @(
    Get-ItemProperty "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Installer" -Name "AlwaysInstallElevated" -ErrorAction SilentlyContinue,
    Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer" -Name "AlwaysInstallElevated" -ErrorAction SilentlyContinue
)
foreach ($ai in $alwaysinstall) {
    if ($ai.AlwaysInstallElevated -eq 1) {
        Write-Host "[!] AlwaysInstallElevated is ENABLED!" -ForegroundColor Red
    }
}
Write-Host ""

# Service Enumeration
Write-Host "[+] Service Enumeration" -ForegroundColor Yellow
Write-Host "Checking for unquoted service paths..."
$services = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\*" -Name "ImagePath" -ErrorAction SilentlyContinue
foreach ($svc in $services) {
    if ($svc.ImagePath -notlike '"*"' -and $svc.ImagePath -notlike "*") {
        Write-Host "[!] Unquoted path: $($svc.PSChildName) - $($svc.ImagePath)" -ForegroundColor Red
    }
}
Write-Host ""

# Writable PATH directories
Write-Host "[+] Writable PATH Directories" -ForegroundColor Yellow
$env:PATH -split ';' | ForEach-Object {
    if (Test-Path $_) {
        $acl = Get-Acl $_ -ErrorAction SilentlyContinue
        if ($acl) {
            $writable = $acl.Access | Where-Object { $_.FileSystemRights -match 'Write' -and $_.IdentityReference -notlike "NT AUTHORITY\SYSTEM" }
            if ($writable) {
                Write-Host "[!] Writable PATH: $_" -ForegroundColor Red
            }
        }
    }
}
Write-Host ""

# Credential Locations
Write-Host "[+] Credential Locations" -ForegroundColor Yellow

# PowerShell history
$ps_history = "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
if (Test-Path $ps_history) {
    Write-Host "[+] PowerShell history found: $ps_history"
    Write-Host "Last 10 entries:"
    Get-Content $ps_history -Tail 10
}

# cmdkey
Write-Host "[+] Saved credentials (cmdkey):"
cmdkey /list 2>$null

# Unattended files
$unattended_files = @(
    "C:\Windows\System32\Sysprep\unattend.xml",
    "C:\Windows\Panther\unattend.xml",
    "C:\Windows\Panther\unattend\unattend.xml"
)
foreach ($file in $unattended_files) {
    if (Test-Path $file) {
        Write-Host "[!] Unattended file found: $file" -ForegroundColor Red
    }
}

# McAfee SiteList
$mcafee = "C:\ProgramData\McAfee\SiteList.xml"
if (Test-Path $mcafee) {
    Write-Host "[!] McAfee SiteList.xml found: $mcafee" -ForegroundColor Red
}
Write-Host ""

# Network Information
Write-Host "[+] Network Information" -ForegroundColor Yellow
ipconfig | Select-String "IPv4|Subnet|Default"
Write-Host ""
Write-Host "Local services:"
netstat -ano | Select-String "127.0.0.1|localhost"
Write-Host ""

# AV/EDR Detection
Write-Host "[+] AV/EDR Detection" -ForegroundColor Yellow
$av_patterns = @("av", "antivirus", "defender", "mcafee", "symantec", "kaspersky", "bitdefender", "eset", "trend", "sophos", "crowdstrike", "carbonblack", "sentinelone", "cylance")
$av_processes = Get-Process | Where-Object { 
    $av_patterns | ForEach-Object { $_.ProcessName -match $_ -ci } 
}
if ($av_processes) {
    Write-Host "[!] Potential AV/EDR processes detected:" -ForegroundColor Red
    $av_processes | Select-Object ProcessName, Id
} else {
    Write-Host "No obvious AV/EDR processes detected"
}
Write-Host ""

Write-Host "[*] Enumeration complete at $(Get-Date)" -ForegroundColor Cyan
Write-Host "[*] For comprehensive enumeration, run WinPEAS: https://github.com/carlospolop/privilege-escalation-awesome-scripts-suite/tree/master/winPEAS" -ForegroundColor Cyan
