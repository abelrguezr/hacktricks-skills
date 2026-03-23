# Print Spooler Vulnerability Assessment Script
# Checks current spooler configuration and identifies potential vulnerabilities

Write-Host "=== Print Spooler Security Assessment ===" -ForegroundColor Cyan
Write-Host ""

# Check service status
Write-Host "[1] Service Status:" -ForegroundColor Yellow
$spooler = Get-Service -Name Spooler -ErrorAction SilentlyContinue
if ($spooler) {
    Write-Host "  Status: $($spooler.Status)" -ForegroundColor $(if($spooler.Status -eq 'Running'){'Red'}else{'Green'})
    Write-Host "  Startup Type: $($spooler.StartType)" -ForegroundColor $(if($spooler.StartType -eq 'Automatic'){'Yellow'}else{'Green'})
} else {
    Write-Host "  Service not found" -ForegroundColor Red
}
Write-Host ""

# Check Point & Print restrictions
Write-Host "[2] Point & Print Restrictions:" -ForegroundColor Yellow
$pointAndPrintPath = 'HKLM:\Software\Policies\Microsoft\Windows NT\Printers\PointAndPrint'
if (Test-Path $pointAndPrintPath) {
    $restrictValue = Get-ItemProperty -Path $pointAndPrintPath -Name 'RestrictDriverInstallationToAdministrators' -ErrorAction SilentlyContinue
    if ($restrictValue) {
        Write-Host "  RestrictDriverInstallationToAdministrators: $($restrictValue.RestrictDriverInstallationToAdministrators)" -ForegroundColor $(if($restrictValue.RestrictDriverInstallationToAdministrators -eq 1){'Green'}else{'Yellow'})
    } else {
        Write-Host "  RestrictDriverInstallationToAdministrators: NOT SET (Vulnerable)" -ForegroundColor Red
    }
} else {
    Write-Host "  Point & Print policy not configured (Vulnerable)" -ForegroundColor Red
}
Write-Host ""

# Check for suspicious files in spool directory
Write-Host "[3] Spool Directory Scan:" -ForegroundColor Yellow
$spoolDir = "C:\Windows\System32\spool\drivers"
if (Test-Path $spoolDir) {
    $suspiciousFiles = Get-ChildItem -Path $spoolDir -Recurse -File -ErrorAction SilentlyContinue | 
        Where-Object { $_.Extension -eq '.dll' -or $_.Extension -eq '.exe' } | 
        Select-Object FullName, LastWriteTime, Length
    if ($suspiciousFiles) {
        Write-Host "  Found $($suspiciousFiles.Count) executable files in spool directory:" -ForegroundColor Yellow
        $suspiciousFiles | Format-Table -AutoSize
    } else {
        Write-Host "  No suspicious files found" -ForegroundColor Green
    }
} else {
    Write-Host "  Spool directory not found" -ForegroundColor Yellow
}
Write-Host ""

# Check event log availability
Write-Host "[4] Event Log Configuration:" -ForegroundColor Yellow
$printServiceLog = Get-EventLog -LogName 'Microsoft-Windows-PrintService/Operational' -ErrorAction SilentlyContinue
if ($printServiceLog) {
    Write-Host "  PrintService/Operational log: Available" -ForegroundColor Green
} else {
    Write-Host "  PrintService/Operational log: Not available or not enabled" -ForegroundColor Yellow
}
Write-Host ""

# Check if this is a Domain Controller
Write-Host "[5] System Type:" -ForegroundColor Yellow
$adModule = Get-Module -ListAvailable -Name ActiveDirectory -ErrorAction SilentlyContinue
if ($adModule) {
    try {
        $dc = Get-ADDomainController -Discover -ErrorAction Stop
        Write-Host "  This is a Domain Controller: $($dc.HostName)" -ForegroundColor Red
        Write-Host "  RECOMMENDATION: Disable Print Spooler immediately on Domain Controllers" -ForegroundColor Red
    } catch {
        Write-Host "  AD module available but DC discovery failed" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ActiveDirectory module not available (likely not a DC)" -ForegroundColor Green
}
Write-Host ""

Write-Host "=== Assessment Complete ===" -ForegroundColor Cyan
