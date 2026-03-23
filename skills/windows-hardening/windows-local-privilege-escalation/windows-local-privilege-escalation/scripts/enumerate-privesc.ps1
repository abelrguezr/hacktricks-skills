# Windows Privilege Escalation Enumeration Script
# Quick enumeration of common privesc vectors

Write-Host "[*] Windows Privilege Escalation Enumeration" -ForegroundColor Cyan
Write-Host "[*] ===========================================" -ForegroundColor Cyan

# System Information
Write-Host "`n[+] System Information" -ForegroundColor Yellow
systeminfo | Select-String "OS Name|OS Version|Build Number"

# Current User and Groups
Write-Host "`n[+] Current User and Groups" -ForegroundColor Yellow
whoami /all | Select-String "Group Name"

# AlwaysInstallElevated
Write-Host "`n[+] AlwaysInstallElevated Check" -ForegroundColor Yellow
$HKCU_AIE = Get-ItemProperty "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Installer" -ErrorAction SilentlyContinue
$HKLM_AIE = Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer" -ErrorAction SilentlyContinue
if ($HKCU_AIE.AlwaysInstallElevated -eq 1 -and $HKLM_AIE.AlwaysInstallElevated -eq 1) {
    Write-Host "[!] AlwaysInstallElevated is ENABLED - VULNERABLE" -ForegroundColor Red
} else {
    Write-Host "[+] AlwaysInstallElevated is disabled" -ForegroundColor Green
}

# Service Permissions
Write-Host "`n[+] Service Enumeration" -ForegroundColor Yellow
$services = Get-WmiObject Win32_Service | Where-Object {$_.StartMode -eq "Auto" -and $_.PathName -notlike "C:\Windows\*"}
foreach ($service in $services) {
    Write-Host "Service: $($service.Name) - Path: $($service.PathName)"
}

# Unquoted Service Paths
Write-Host "`n[+] Unquoted Service Paths" -ForegroundColor Yellow
$unquoted = Get-WmiObject Win32_Service | Where-Object {$_.StartMode -eq "Auto" -and $_.PathName -notlike "C:\Windows*" -and $_.PathName -notlike '"*'}
foreach ($u in $unquoted) {
    Write-Host "[!] $($u.Name): $($u.PathName)" -ForegroundColor Red
}

# Environment Variables
Write-Host "`n[+] Environment Variables" -ForegroundColor Yellow
Get-ChildItem Env: | Where-Object {$_.Value -match "password|pass|cred|token|key" -ci} | Format-Table Key, Value

# PowerShell History
Write-Host "`n[+] PowerShell History" -ForegroundColor Yellow
$historyPath = (Get-PSReadlineOption).HistorySavePath
if (Test-Path $historyPath) {
    Write-Host "History file: $historyPath"
    Select-String -Path $historyPath -Pattern "password|pass|cred" -Context 0,2 | Select-Object -First 10
}

# Credential Manager
Write-Host "`n[+] Credential Manager" -ForegroundColor Yellow
cmdkey /list

# WiFi Passwords
Write-Host "`n[+] WiFi Profiles" -ForegroundColor Yellow
netsh wlan show profiles | Select-String "All User Profile" | ForEach-Object {
    $profile = ($_ -split ":")[1].Trim()
    Write-Host "Profile: $profile"
}

# Scheduled Tasks
Write-Host "`n[+] Scheduled Tasks" -ForegroundColor Yellow
Get-ScheduledTask | Where-Object {$_.TaskPath -ne "\"} | Format-Table TaskName, TaskPath, State

# Running Processes
Write-Host "`n[+] Running Processes" -ForegroundColor Yellow
Get-Process | Where-Object {$_.ProcessName -notlike "svchost*"} | Select-Object ProcessName, Id, @{Name="Owner";Expression={$_.GetOwner().UserName}} | Format-Table

Write-Host "`n[*] Enumeration Complete" -ForegroundColor Cyan
