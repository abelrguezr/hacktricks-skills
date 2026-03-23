#!/usr/bin/env pwsh
# Setup Writable System Path for DLL Hijacking
# Usage: .\setup-hijacking-path.ps1 [-Path <custom-path>]

param(
    [string]$Path = "C:\privesc_hijacking"
)

Write-Host "[*] Setting up writable System Path for DLL hijacking..." -ForegroundColor Cyan
Write-Host "[*] Target path: $Path" -ForegroundColor Cyan

# Create the folder if it does not exist
if (!(Test-Path $Path -PathType Container)) {
    Write-Host "[*] Creating folder: $Path" -ForegroundColor Yellow
    try {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Write-Host "[+] Folder created successfully" -ForegroundColor Green
    } catch {
        Write-Host "[-] Failed to create folder: $_" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "[+] Folder already exists: $Path" -ForegroundColor Green
}

# Check if we have write permissions
try {
    $testFile = Join-Path $Path "test_write.tmp"
    New-Item -ItemType File -Path $testFile -Force | Out-Null
    Remove-Item -Path $testFile -Force
    Write-Host "[+] Write permissions confirmed" -ForegroundColor Green
} catch {
    Write-Host "[-] No write permissions to: $Path" -ForegroundColor Red
    exit 1
}

# Set the folder path in the System environment variable PATH
$envPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
if ($envPath -notlike "*$Path*") {
    Write-Host "[*] Adding $Path to System PATH" -ForegroundColor Yellow
    try {
        $newPath = "$envPath;$Path"
        [Environment]::SetEnvironmentVariable("PATH", $newPath, "Machine")
        Write-Host "[+] System PATH updated successfully" -ForegroundColor Green
        Write-Host "[*] New PATH: $newPath" -ForegroundColor Gray
    } catch {
        Write-Host "[-] Failed to update System PATH: $_" -ForegroundColor Red
        Write-Host "[*] Try running as Administrator" -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "[+] Path already in System PATH" -ForegroundColor Green
}

Write-Host "" -ForegroundColor White
Write-Host "[*] Setup complete!" -ForegroundColor Cyan
Write-Host "[*] Next steps:" -ForegroundColor Cyan
Write-Host "    1. Download Procmon from Sysinternals" -ForegroundColor White
Write-Host "    2. Enable boot logging in Procmon" -ForegroundColor White
Write-Host "    3. Reboot the system" -ForegroundColor White
Write-Host "    4. Open Procmon and save boot events" -ForegroundColor White
Write-Host "    5. Filter for missing DLLs in $Path" -ForegroundColor White
Write-Host "" -ForegroundColor White
