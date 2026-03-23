# Hunt for Mimikatz driver (mimidrv.sys)
# Skeleton Key Attack Detection
# Event ID 7045 - Service/Driver Installation

Write-Host "[*] Hunting for Mimikatz driver (mimidrv.sys)..." -ForegroundColor Cyan

$events = Get-WinEvent -FilterHashtable @{Logname='System';ID=7045} -ErrorAction SilentlyContinue

if ($events) {
    $mimidrvEvents = $events | Where-Object {
        $_.message -like "*Kernel Mode Driver*" -and 
        $_.message -like "*mimidrv*"
    }
    
    if ($mimidrvEvents) {
        Write-Host "[!] CRITICAL: Found $($mimidrvEvents.Count) mimidrv.sys installation events!" -ForegroundColor Red
        Write-Host ""
        Write-Host "This indicates a potential Skeleton Key attack!" -ForegroundColor Red
        Write-Host ""
        
        foreach ($event in $mimidrvEvents) {
            Write-Host "Time: $($event.TimeCreated)" -ForegroundColor Gray
            Write-Host "Message: $($event.message)" -ForegroundColor White
            Write-Host "---"
        }
        
        Write-Host ""
        Write-Host "[!] RECOMMENDED ACTIONS:" -ForegroundColor Yellow
        Write-Host "1. Reboot all domain controllers immediately" -ForegroundColor Yellow
        Write-Host "2. Investigate the source of driver installation" -ForegroundColor Yellow
        Write-Host "3. Check for lateral movement from the initial compromise" -ForegroundColor Yellow
    } else {
        Write-Host "[+] No mimidrv.sys events found" -ForegroundColor Green
    }
} else {
    Write-Host "[+] No Event ID 7045 events found" -ForegroundColor Green
}
