# WinRM Connectivity Test Script
# Usage: .\test-winrm-connectivity.ps1 [-ComputerName <target>] [-Credential <cred>]
# Purpose: Test WinRM connectivity to target systems

param(
    [string]$ComputerName,
    [PSCredential]$Credential,
    [switch]$UseSSL,
    [int]$Port = if($UseSSL){5986}else{5985}
)

Write-Host "=== WinRM Connectivity Test ===" -ForegroundColor Cyan

if (-not $ComputerName) {
    Write-Host "ERROR: ComputerName is required" -ForegroundColor Red
    Write-Host "Usage: .\test-winrm-connectivity.ps1 -ComputerName <target>" -ForegroundColor Yellow
    exit 1
}

Write-Host "Target: $ComputerName" -ForegroundColor Green
Write-Host "Port: $Port" -ForegroundColor Green
Write-Host "Protocol: $((if($UseSSL){'HTTPS'}else{'HTTP'}))" -ForegroundColor Green
Write-Host ""

# Test 1: Basic connectivity
Write-Host "[1] Testing Basic Connectivity" -ForegroundColor Yellow
try {
    $testParams = @{
        ComputerName = $ComputerName
    }
    if ($Credential) {
        $testParams.Credential = $Credential
    }
    
    $result = Test-WSMan @testParams -ErrorAction Stop
    Write-Host "  Status: SUCCESS" -ForegroundColor Green
    Write-Host "  Protocol: $($result.Protocol)" -ForegroundColor Green
    Write-Host "  Product: $($result.Product)" -ForegroundColor Green
    Write-Host "  Version: $($result.Version)" -ForegroundColor Green
} catch {
    Write-Host "  Status: FAILED" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Test 2: Enumerate configuration
Write-Host "[2] Enumerating WinRM Configuration" -ForegroundColor Yellow
try {
    $configParams = @{
        ComputerName = $ComputerName
    }
    if ($Credential) {
        $configParams.Credential = $Credential
    }
    
    $config = winrm enumerate winrm/config @configParams -ErrorAction Stop
    Write-Host "  Status: SUCCESS" -ForegroundColor Green
    Write-Host "  Configuration retrieved" -ForegroundColor Green
} catch {
    Write-Host "  Status: FAILED" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 3: Check listeners
Write-Host "[3] Checking Listeners" -ForegroundColor Yellow
try {
    $listenerParams = @{
        ComputerName = $ComputerName
    }
    if ($Credential) {
        $listenerParams.Credential = $Credential
    }
    
    $listeners = winrm enumerate winrm/config/listener @listenerParams -ErrorAction Stop
    Write-Host "  Status: SUCCESS" -ForegroundColor Green
    foreach ($listener in $listeners) {
        Write-Host "  - Transport: $($listener.Transport), Address: $($listener.Address)" -ForegroundColor Green
    }
} catch {
    Write-Host "  Status: FAILED" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Connectivity Test Complete ===" -ForegroundColor Cyan
