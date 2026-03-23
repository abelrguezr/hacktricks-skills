# WinRM Configuration Audit Script
# Usage: .\check-winrm-config.ps1 [-ComputerName <target>]
# Purpose: Audit WinRM configuration for security issues

param(
    [string]$ComputerName = "localhost"
)

Write-Host "=== WinRM Configuration Audit ===" -ForegroundColor Cyan
Write-Host "Target: $ComputerName"
Write-Host ""

# Check WinRM service status
Write-Host "[1] WinRM Service Status" -ForegroundColor Yellow
try {
    $service = Get-Service -Name WinRM -ComputerName $ComputerName -ErrorAction Stop
    Write-Host "  Service Name: $($service.Name)" -ForegroundColor Green
    Write-Host "  Status: $($service.Status)" -ForegroundColor Green
    Write-Host "  StartType: $($service.StartType)" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: Could not query service - $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Check listeners
Write-Host "[2] WinRM Listeners" -ForegroundColor Yellow
try {
    $listeners = winrm enumerate winrm/config/listener -ComputerName $ComputerName -ErrorAction Stop
    if ($listeners) {
        foreach ($listener in $listeners) {
            Write-Host "  Transport: $($listener.Transport)" -ForegroundColor Green
            Write-Host "  Address: $($listener.Address)" -ForegroundColor Green
            Write-Host "  Hostname: $($listener.Hostname)" -ForegroundColor Green
            if ($listener.Transport -eq "HTTP") {
                Write-Host "  WARNING: HTTP listener detected (unencrypted)" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "  No listeners configured" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ERROR: Could not query listeners - $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Check authentication settings
Write-Host "[3] Authentication Configuration" -ForegroundColor Yellow
try {
    $auth = winrm enumerate winrm/config/service/Auth -ComputerName $ComputerName -ErrorAction Stop
    Write-Host "  Basic: $($auth.Basic)" -ForegroundColor Green
    Write-Host "  Kerberos: $($auth.Kerberos)" -ForegroundColor Green
    Write-Host "  Negotiate: $($auth.Negotiate)" -ForegroundColor Green
    Write-Host "  NTLM: $($auth.NTLM)" -ForegroundColor Green
    
    if ($auth.Basic -eq "true") {
        Write-Host "  WARNING: Basic authentication enabled (credentials in transit)" -ForegroundColor Red
    }
} catch {
    Write-Host "  ERROR: Could not query auth settings - $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Check service settings
Write-Host "[4] Service Configuration" -ForegroundColor Yellow
try {
    $serviceConfig = winrm enumerate winrm/config/service -ComputerName $ComputerName -ErrorAction Stop
    Write-Host "  AllowUnencrypted: $($serviceConfig.AllowUnencrypted)" -ForegroundColor Green
    Write-Host "  MaxEnvelopeSizekb: $($serviceConfig.MaxEnvelopeSizekb)" -ForegroundColor Green
    Write-Host "  MaxTimeoutms: $($serviceConfig.MaxTimeoutms)" -ForegroundColor Green
    
    if ($serviceConfig.AllowUnencrypted -eq "true") {
        Write-Host "  WARNING: Unencrypted messages allowed" -ForegroundColor Red
    }
} catch {
    Write-Host "  ERROR: Could not query service config - $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Check client settings
Write-Host "[5] Client Configuration" -ForegroundColor Yellow
try {
    $client = winrm enumerate winrm/config/client -ComputerName $ComputerName -ErrorAction Stop
    Write-Host "  TrustedHosts: $($client.TrustedHosts)" -ForegroundColor Green
    Write-Host "  AllowUnencrypted: $($client.AllowUnencrypted)" -ForegroundColor Green
    
    if ($client.TrustedHosts -and $client.TrustedHosts -ne "*") {
        Write-Host "  INFO: Trusted hosts configured" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ERROR: Could not query client config - $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Audit Complete ===" -ForegroundColor Cyan
