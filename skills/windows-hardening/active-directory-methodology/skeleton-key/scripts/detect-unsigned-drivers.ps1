# Detect unsigned kernel driver installations
# Skeleton Key Attack Detection
# Event ID 7045 - Service/Driver Installation

Write-Host "[*] Checking for unsigned kernel driver installations..." -ForegroundColor Cyan

$events = Get-WinEvent -FilterHashtable @{Logname='System';ID=7045} -ErrorAction SilentlyContinue

if ($events) {
    $unsignedDrivers = $events | Where-Object {
        $_.message -like "*Kernel Mode Driver*"
    }
    
    if ($unsignedDrivers) {
        Write-Host "[!] Found $($unsignedDrivers.Count) kernel driver installation events:" -ForegroundColor Yellow
        Write-Host ""
        
        foreach ($event in $unsignedDrivers | Select-Object -First 20) {
            Write-Host "Time: $($event.TimeCreated)" -ForegroundColor Gray
            Write-Host "Message: $($event.message)" -ForegroundColor White
            Write-Host "---"
        }
        
        if ($unsignedDrivers.Count -gt 20) {
            Write-Host "... and $($unsignedDrivers.Count - 20) more events" -ForegroundColor Gray
        }
    } else {
        Write-Host "[+] No kernel driver installation events found" -ForegroundColor Green
    }
} else {
    Write-Host "[+] No Event ID 7045 events found" -ForegroundColor Green
}
