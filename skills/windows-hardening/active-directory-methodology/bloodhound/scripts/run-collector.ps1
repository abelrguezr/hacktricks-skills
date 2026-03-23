# BloodHound Collector Runner
# PowerShell script to run SharpHound or RustHound collectors

param(
    [Parameter(Mandatory=$true)]
    [string]$Domain,
    
    [Parameter(Mandatory=$false)]
    [string]$Username,
    
    [Parameter(Mandatory=$false)]
    [string]$Password,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("All", "Stealth", "Targeted", "LDAP")]
    [string]$CollectionMode = "Targeted",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputDir = ".\bloodhound-data",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("SharpHound", "RustHound")]
    [string]$Collector = "SharpHound"
)

# Create output directory
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

Write-Host "[+] Starting BloodHound collection..." -ForegroundColor Green
Write-Host "    Domain: $Domain" -ForegroundColor Cyan
Write-Host "    Mode: $CollectionMode" -ForegroundColor Cyan
Write-Host "    Collector: $Collector" -ForegroundColor Cyan
Write-Host "    Output: $OutputDir" -ForegroundColor Cyan

# Check if running elevated
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "[!] WARNING: Not running elevated. Privilege edges may be incomplete." -ForegroundColor Yellow
    Write-Host "[+] Right-click PowerShell and select 'Run as Administrator' for full data." -ForegroundColor Yellow
}

switch ($Collector) {
    "SharpHound" {
        # Check if SharpHound exists
        if (-not (Test-Path ".\SharpHound.exe")) {
            Write-Host "[!] SharpHound.exe not found. Download from: https://github.com/BloodHoundAD/BloodHound/releases" -ForegroundColor Red
            exit 1
        }
        
        switch ($CollectionMode) {
            "All" {
                Write-Host "[+] Running full collection (noisy)..." -ForegroundColor Cyan
                .\SharpHound.exe --CollectionMethods All --ZipFilename "bloodhound-full.zip" --ZipPath $OutputDir
            }
            "Stealth" {
                Write-Host "[+] Running stealth collection (LDAP only)..." -ForegroundColor Cyan
                .\SharpHound.exe --Stealth --LDAP --ZipFilename "bloodhound-stealth.zip" --ZipPath $OutputDir
            }
            "Targeted" {
                Write-Host "[+] Running targeted collection..." -ForegroundColor Cyan
                .\SharpHound.exe --CollectionMethods Group,LocalAdmin,Session,Trusts,ACL --ZipFilename "bloodhound-targeted.zip" --ZipPath $OutputDir
            }
            "LDAP" {
                Write-Host "[+] Running LDAP-only collection..." -ForegroundColor Cyan
                .\SharpHound.exe --CollectionMethods LDAP --ZipFilename "bloodhound-ldap.zip" --ZipPath $OutputDir
            }
        }
    }
    
    "RustHound" {
        # Check if RustHound exists
        if (-not (Test-Path ".\rusthound-ce.exe")) {
            Write-Host "[!] RustHound-CE not found. Download from: https://github.com/g0h4n/RustHound-CE" -ForegroundColor Red
            exit 1
        }
        
        Write-Host "[+] Running RustHound-CE (ADWS stealthy collection)..." -ForegroundColor Cyan
        
        $args = @("-d", $Domain, "-c", "All", "-z", "-o", $OutputDir)
        
        if ($Username -and $Password) {
            $args += @("-u", $Username, "-p", $Password)
        }
        
        & .\rusthound-ce.exe $args
    }
}

Write-Host ""
Write-Host "[+] Collection complete!" -ForegroundColor Green
Write-Host "[+] Output saved to: $OutputDir" -ForegroundColor Green
Write-Host "[+] Import the .zip file into BloodHound web UI at http://localhost:8080" -ForegroundColor Green
