#!/usr/bin/env pwsh
# Find suspicious Windows services that may indicate SCMExec lateral movement
# Usage: .\find-suspicious-services.ps1 [-ComputerName <name>] [-OutputFile <path>]

param(
    [string]$ComputerName = $env:COMPUTERNAME,
    [string]$OutputFile = "suspicious-services-report.json"
)

$SuspiciousPaths = @(
    "temp",
    "appdata",
    "users.*documents",
    "users.*downloads",
    "users.*desktop",
    "programdata",
    "windows\syswow64",
    "c:\\users\\.*\\appdata\\local\\temp"
)

$Results = @()

try {
    # Get all services
    $Services = Get-Service -ErrorAction SilentlyContinue
    
    foreach ($Service in $Services) {
        try {
            $ServiceKey = "HKLM:\\SYSTEM\\CurrentControlSet\\Services\\$($Service.Name)"
            $ServiceInfo = Get-ItemProperty $ServiceKey -ErrorAction SilentlyContinue
            
            if ($ServiceInfo) {
                $ImagePath = $ServiceInfo.ImagePath
                $DisplayName = $ServiceInfo.DisplayName
                $StartType = $ServiceInfo.Start
                $Type = $ServiceInfo.Type
                
                $IsSuspicious = $false
                $Reasons = @()
                
                # Check for suspicious paths
                foreach ($Pattern in $SuspiciousPaths) {
                    if ($ImagePath -match $Pattern) {
                        $IsSuspicious = $true
                        $Reasons += "Suspicious path pattern: $Pattern"
                    }
                }
                
                # Check for services with random-looking names
                if ($Service.Name -match "^[a-zA-Z0-9]{8,}$" -and $Service.Name -notmatch "^[A-Z]+$") {
                    $IsSuspicious = $true
                    $Reasons += "Random-looking service name"
                }
                
                # Check for services with suspicious display names
                if ($DisplayName -match "debug|test|temp|update|service" -and $ImagePath -notmatch "\\windows\\system32\\") {
                    $IsSuspicious = $true
                    $Reasons += "Suspicious display name with non-system path"
                }
                
                # Check for services that run as SYSTEM but have unusual paths
                if ($ImagePath -notmatch "\\windows\\system32\\" -and $ImagePath -notmatch "\\windows\\syswow64\\") {
                    $IsSuspicious = $true
                    $Reasons += "Non-standard system path"
                }
                
                if ($IsSuspicious) {
                    $Results += [PSCustomObject]@{
                        ServiceName = $Service.Name
                        DisplayName = $DisplayName
                        ImagePath = $ImagePath
                        StartType = $StartType
                        Status = $Service.Status
                        ComputerName = $ComputerName
                        Reasons = ($Reasons -join "; ")
                        Timestamp = Get-Date -Format "o"
                    }
                }
            }
        } catch {
            Write-Warning "Error processing service $($Service.Name): $_"
        }
    }
    
    # Output results
    if ($Results.Count -gt 0) {
        $Report = @{
            ScanDate = Get-Date -Format "o"
            ComputerName = $ComputerName
            TotalServicesScanned = $Services.Count
            SuspiciousServicesFound = $Results.Count
            SuspiciousServices = $Results
        }
        
        # Save to file
        $Report | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputFile -Encoding UTF8
        Write-Host "Found $($Results.Count) suspicious services. Report saved to: $OutputFile" -ForegroundColor Yellow
        
        # Display summary
        Write-Host "`nSuspicious Services Summary:" -ForegroundColor Cyan
        foreach ($Result in $Results) {
            Write-Host "  - $($Result.ServiceName): $($Result.Reasons)" -ForegroundColor Red
        }
    } else {
        Write-Host "No suspicious services found on $ComputerName" -ForegroundColor Green
        @{
            ScanDate = Get-Date -Format "o"
            ComputerName = $ComputerName
            TotalServicesScanned = $Services.Count
            SuspiciousServicesFound = 0
            SuspiciousServices = @()
        } | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputFile -Encoding UTF8
    }
    
} catch {
    Write-Error "Error scanning services: $_"
    exit 1
}
