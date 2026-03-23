#!/usr/bin/env pwsh
# Certificate Usage Checker
# Analyzes a certificate's Enhanced Key Usage and capabilities

param(
    [Parameter(Mandatory=$true)]
    [string]$CertPath,
    
    [string]$Password = ""
)

try {
    Write-Host "[*] Analyzing certificate: $CertPath" -ForegroundColor Cyan
    
    # Load the certificate
    if ($Password) {
        $Cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $CertPath, $Password
    } else {
        $Cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $CertPath
    }
    
    # Display certificate information
    Write-Host "`n=== Certificate Information ===" -ForegroundColor Yellow
    Write-Host "Subject: $($Cert.Subject)" -ForegroundColor White
    Write-Host "Issuer: $($Cert.Issuer)" -ForegroundColor White
    Write-Host "Valid From: $($Cert.NotBefore)" -ForegroundColor White
    Write-Host "Valid To: $($Cert.NotAfter)" -ForegroundColor White
    Write-Host "Serial Number: $($Cert.SerialNumber)" -ForegroundColor White
    Write-Host "Thumbprint: $($Cert.Thumbprint)" -ForegroundColor White
    
    # Enhanced Key Usage
    Write-Host "`n=== Enhanced Key Usage ===" -ForegroundColor Yellow
    if ($Cert.Extensions) {
        foreach ($Ext in $Cert.Extensions) {
            if ($Ext.Oid.FriendlyName -eq "Enhanced Key Usage") {
                Write-Host "Enhanced Key Usage:" -ForegroundColor Green
                foreach ($Oid in $Ext.EnhancedKeyUsages) {
                    Write-Host "  - $Oid" -ForegroundColor Gray
                }
            }
        }
    }
    
    # Key Usage
    Write-Host "`n=== Key Usage ===" -ForegroundColor Yellow
    if ($Cert.Extensions) {
        foreach ($Ext in $Cert.Extensions) {
            if ($Ext.Oid.FriendlyName -eq "Key Usage") {
                Write-Host "Key Usage: $($Ext.Format(0))" -ForegroundColor Green
            }
        }
    }
    
    # Check for private key
    Write-Host "`n=== Private Key ===" -ForegroundColor Yellow
    try {
        $HasPrivateKey = $Cert.HasPrivateKey
        Write-Host "Has Private Key: $HasPrivateKey" -ForegroundColor $(if($HasPrivateKey){"Green"}else{"Red"})
        
        if ($HasPrivateKey) {
            Write-Host "Key Exportable: $($Cert.PrivateKey.CanExport)" -ForegroundColor Gray
        }
    } catch {
        Write-Host "Could not determine private key status: $_" -ForegroundColor Red
    }
    
    # AD CS specific checks
    Write-Host "`n=== AD CS Attack Potential ===" -ForegroundColor Yellow
    
    $EKUList = $Cert.EnhancedKeyUsageList | ForEach-Object { $_.FriendlyName }
    
    # Check for authentication EKU
    if ($EKUList -match "Client Authentication" -or $EKUList -match "1.3.6.1.5.5.7.3.2") {
        Write-Host "[!] Client Authentication EKU found - Can be used for PKINIT" -ForegroundColor Red
    }
    
    if ($EKUList -match "Smart Card Logon" -or $EKUList -match "1.3.6.1.4.1.311.20.2.2") {
        Write-Host "[!] Smart Card Logon EKU found - High value target" -ForegroundColor Red
    }
    
    if ($EKUList -match "Email Protection" -or $EKUList -match "1.3.6.1.5.5.7.3.1") {
        Write-Host "[!] Email Protection EKU found - Can be used for S/MIME" -ForegroundColor Yellow
    }
    
    if ($EKUList -match "Code Signing" -or $EKUList -match "1.3.6.1.5.5.7.3.3") {
        Write-Host "[!] Code Signing EKU found - Can sign executables" -ForegroundColor Yellow
    }
    
    # Check for Enterprise CA
    if ($Cert.Issuer -match "Enterprise" -or $Cert.Issuer -match "AD CS") {
        Write-Host "[!] Issued by Enterprise CA - Potentially high trust" -ForegroundColor Red
    }
    
    Write-Host "`n[*] Analysis complete." -ForegroundColor Green
    
} catch {
    Write-Host "[!] Error: $_" -ForegroundColor Red
    exit 1
}
