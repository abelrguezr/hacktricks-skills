#!/usr/bin/env pwsh
# AD CS Certificate File Search Script
# Searches for certificate files in specified paths

param(
    [string]$Path = "C:\Users\",
    [switch]$Recurse,
    [switch]$AllPaths,
    [string]$OutputFile = ""
)

# Certificate file extensions to search for
$CertExtensions = @(
    "*.pfx", "*.p12", "*.pkcs12",  # PKCS#12 files
    "*.pem",                        # PEM files
    "*.key",                        # Private keys
    "*.crt", "*.cer",              # Certificates
    "*.csr",                        # Certificate Signing Requests
    "*.jks", "*.keystore", "*.keys" # Java Keystores
)

# Define search paths
$SearchPaths = @(
    "C:\Users\",
    "C:\Temp\",
    "C:\Windows\Temp\",
    "C:\ProgramData\"
)

if ($AllPaths) {
    $SearchPaths += @(
        "C:\Program Files\",
        "C:\Program Files (x86)\",
        "C:\inetpub\"
    )
}

Write-Host "[*] Searching for certificate files..." -ForegroundColor Cyan
Write-Host "[*] Extensions: $($CertExtensions -join ", ")" -ForegroundColor Gray

$Results = @()

foreach ($SearchPath in $SearchPaths) {
    if (Test-Path $SearchPath) {
        Write-Host "[*] Scanning: $SearchPath" -ForegroundColor Yellow
        
        foreach ($Ext in $CertExtensions) {
            try {
                $Files = Get-ChildItem -Path $SearchPath -Include $Ext -Recurse -ErrorAction SilentlyContinue -File | Select-Object FullName, Length, LastWriteTime
                
                foreach ($File in $Files) {
                    $Results += [PSCustomObject]@{
                        Path = $File.FullName
                        Size = $File.Length
                        LastModified = $File.LastWriteTime
                        Extension = $File.Extension
                    }
                }
            } catch {
                Write-Host "[!] Error scanning $SearchPath: $_" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "[!] Path not found: $SearchPath" -ForegroundColor Red
    }
}

# Output results
if ($Results.Count -gt 0) {
    Write-Host "`n[*] Found $($Results.Count) certificate file(s):" -ForegroundColor Green
    $Results | Format-Table -AutoSize
    
    if ($OutputFile) {
        $Results | Export-Csv -Path $OutputFile -NoTypeInformation
        Write-Host "[*] Results exported to: $OutputFile" -ForegroundColor Green
    }
} else {
    Write-Host "[!] No certificate files found." -ForegroundColor Yellow
}

# Summary by extension
Write-Host "`n[*] Summary by file type:" -ForegroundColor Cyan
$Results | Group-Object Extension | Sort-Object Count -Descending | ForEach-Object {
    Write-Host "    $($_.Name): $($_.Count)" -ForegroundColor Gray
}
