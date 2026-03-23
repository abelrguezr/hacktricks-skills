# Validate PPL (Protected Process Light) enforcement on LSASS
# Skeleton Key Attack Detection
# Event ID 12 - Protected Process

Write-Host "[*] Validating PPL enforcement on LSASS..." -ForegroundColor Cyan

$events = Get-WinEvent -FilterHashtable @{Logname='System';ID=12} -ErrorAction SilentlyContinue

if ($events) {
    $pplEvents = $events | Where-Object {
        $_.message -like "*protected process*"
    }
    
    if ($pplEvents) {
        Write-Host "[+] Found $($pplEvents.Count) protected process events:" -ForegroundColor Green
        Write-Host ""
        
        $lsassPpl = $pplEvents | Where-Object {
            $_.message -like "*lsass*"
        }
        
        if ($lsassPpl) {
            Write-Host "[+] LSASS is running as a protected process (PPL enabled)" -ForegroundColor Green
            Write-Host ""
            Write-Host "Recent PPL events:" -ForegroundColor Gray
            foreach ($event in $lsassPpl | Select-Object -First 5) {
                Write-Host "Time: $($event.TimeCreated)" -ForegroundColor Gray
                Write-Host "Message: $($event.message)" -ForegroundColor White
            }
        } else {
            Write-Host "[!] WARNING: No LSASS protected process events found" -ForegroundColor Yellow
            Write-Host "PPL may not be enabled for LSASS" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[!] WARNING: No protected process events found" -ForegroundColor Yellow
        Write-Host "PPL may not be enabled" -ForegroundColor Yellow
    }
} else {
    Write-Host "[!] WARNING: No Event ID 12 events found" -ForegroundColor Yellow
    Write-Host "PPL may not be enabled or logging may be disabled" -ForegroundColor Yellow
}
