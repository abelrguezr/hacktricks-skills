# Print Spooler Disable Script
# Safely disables the Print Spooler service
# WARNING: This will break all printing functionality

param(
    [switch]$Force,
    [switch]$WhatIf
)

Write-Host "=== Print Spooler Disable Script ===" -ForegroundColor Cyan
Write-Host ""

# Check if running as administrator
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: This script must be run as Administrator" -ForegroundColor Red
    exit 1
}

# Check current status
Write-Host "[1] Current Status:" -ForegroundColor Yellow
$spooler = Get-Service -Name Spooler -ErrorAction SilentlyContinue
if ($spooler) {
    Write-Host "  Current Status: $($spooler.Status)" -ForegroundColor Yellow
    Write-Host "  Current Startup Type: $($spooler.StartType)" -ForegroundColor Yellow
} else {
    Write-Host "  Service not found" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Check for dependent services
Write-Host "[2] Dependent Services:" -ForegroundColor Yellow
$dependents = Get-Service -Name Spooler -ErrorAction SilentlyContinue | Select-Object -ExpandProperty DependOnService
if ($dependents) {
    Write-Host "  Services that depend on Spooler:" -ForegroundColor Yellow
    foreach ($dep in $dependents) {
        $depService = Get-Service -Name $dep -ErrorAction SilentlyContinue
        if ($depService) {
            Write-Host "    - $($dep) (Status: $($depService.Status))" -ForegroundColor $(if($depService.Status -eq 'Running'){'Red'}else{'Yellow'})
        }
    }
} else {
    Write-Host "  No dependent services found" -ForegroundColor Green
}
Write-Host ""

# Check if this is a Domain Controller
Write-Host "[3] System Type Check:" -ForegroundColor Yellow
$adModule = Get-Module -ListAvailable -Name ActiveDirectory -ErrorAction SilentlyContinue
$isDC = $false
if ($adModule) {
    try {
        $dc = Get-ADDomainController -Discover -ErrorAction Stop
        $isDC = $true
        Write-Host "  This is a Domain Controller: $($dc.HostName)" -ForegroundColor Red
        Write-Host "  Disabling Spooler is RECOMMENDED on Domain Controllers" -ForegroundColor Green
    } catch {
        Write-Host "  Could not determine if this is a Domain Controller" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ActiveDirectory module not available" -ForegroundColor Yellow
}
Write-Host ""

# Confirmation
if (!$Force) {
    Write-Host "WARNING: Disabling the Print Spooler will break all printing functionality." -ForegroundColor Red
    Write-Host "This action is recommended for Domain Controllers but will affect workstations." -ForegroundColor Yellow
    Write-Host ""
    $confirm = Read-Host "Are you sure you want to continue? (yes/no)"
    if ($confirm -ne 'yes') {
        Write-Host "Operation cancelled by user" -ForegroundColor Yellow
        exit 0
    }
}

if ($WhatIf) {
    Write-Host "[WhatIf] Would stop and disable Print Spooler service" -ForegroundColor Cyan
    exit 0
}

# Disable the service
Write-Host "[4] Disabling Print Spooler..." -ForegroundColor Yellow
try {
    # Stop the service
    Stop-Service -Name Spooler -Force -ErrorAction Stop
    Write-Host "  Service stopped successfully" -ForegroundColor Green
    
    # Disable startup
    Set-Service -Name Spooler -StartupType Disabled -ErrorAction Stop
    Write-Host "  Service startup type set to Disabled" -ForegroundColor Green
    
    # Verify
    $spooler = Get-Service -Name Spooler
    Write-Host ""
    Write-Host "[5] Verification:" -ForegroundColor Yellow
    Write-Host "  Status: $($spooler.Status)" -ForegroundColor Green
    Write-Host "  Startup Type: $($spooler.StartType)" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "=== Print Spooler Disabled Successfully ===" -ForegroundColor Green
    
} catch {
    Write-Host "ERROR: Failed to disable Print Spooler: $_" -ForegroundColor Red
    exit 1
}
