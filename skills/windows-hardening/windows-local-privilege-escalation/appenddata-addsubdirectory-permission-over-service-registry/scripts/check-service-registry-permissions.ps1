#!/usr/bin/env pwsh
# Windows Service Registry Permission Checker
# Checks for AppendData/AddSubdirectory permissions on service registry keys
# For authorized security testing and assessment only

param(
    [string]$ServiceName = "",
    [string]$OutputFile = "",
    [switch]$Verbose
)

# Common vulnerable service names to check
$DefaultServices = @(
    "RpcEptMapper",
    "Dnscache",
    "LanmanServer",
    "LanmanWorkstation",
    "Spooler",
    "BITS"
)

function Get-ServiceRegistryPath {
    param([string]$ServiceName)
    return "HKLM:\SYSTEM\CurrentControlSet\Services\$ServiceName"
}

function Test-RegistryPermission {
    param(
        [string]$RegistryPath,
        [string]$PermissionName
    )
    
    try {
        $key = Get-Item -Path $RegistryPath -ErrorAction SilentlyContinue
        if (-not $key) {
            return $null
        }
        
        $acl = Get-Acl -Path $RegistryPath -ErrorAction SilentlyContinue
        if (-not $acl) {
            return $null
        }
        
        $permissions = @()
        foreach ($ace in $acl.Access) {
            if ($ace.AccessControlType -eq "Allow") {
                $perm = @{
                    Identity = $ace.IdentityReference.ToString()
                    Rights = @()
                }
                
                foreach ($right in $ace.RegistryRights) {
                    $perm.Rights += $right
                }
                
                $permissions += $perm
            }
        }
        
        return $permissions
    }
    catch {
        Write-Warning "Error checking permissions for $RegistryPath: $_"
        return $null
    }
}

function Check-ServiceVulnerability {
    param([string]$ServiceName)
    
    $registryPath = Get-ServiceRegistryPath -ServiceName $ServiceName
    $permissions = Test-RegistryPermission -RegistryPath $registryPath -PermissionName "AppendData"
    
    $result = @{
        ServiceName = $ServiceName
        RegistryPath = $registryPath
        IsVulnerable = $false
        VulnerableUsers = @()
        Permissions = $permissions
        Recommendation = ""
    }
    
    if ($permissions) {
        foreach ($perm in $permissions) {
            # Check for AppendData/AddSubdirectory or CreateSubKey
            if ($perm.Rights -contains "CreateSubKey" -or $perm.Rights -contains "SetValue") {
                # Exclude well-known administrative accounts
                if ($perm.Identity -notmatch "(NT AUTHORITY\\SYSTEM|BUILTIN\\Administrators|NT AUTHORITY\\NETWORK SERVICE|NT AUTHORITY\\LOCAL SERVICE)") {
                    $result.IsVulnerable = $true
                    $result.VulnerableUsers += $perm.Identity
                }
            }
        }
    }
    
    if ($result.IsVulnerable) {
        $result.Recommendation = "Remove AppendData/AddSubdirectory permission from non-administrative users"
    }
    else {
        $result.Recommendation = "No immediate action required"
    }
    
    return $result
}

function Format-Report {
    param([array]$Results)
    
    $report = @()
    $report += "=" * 60
    $report += "Windows Service Registry Permission Audit Report"
    $report += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $report += "=" * 60
    $report += ""
    
    $vulnerableCount = 0
    $totalCount = 0
    
    foreach ($result in $Results) {
        $totalCount++
        $report += "Service: $($result.ServiceName)"
        $report += "Path: $($result.RegistryPath)"
        
        if ($result.IsVulnerable) {
            $vulnerableCount++
            $report += "Status: VULNERABLE"
            $report += ""
            $report += "Vulnerable Users/Groups:"
            foreach ($user in $result.VulnerableUsers) {
                $report += "  - $user"
            }
            $report += ""
            $report += "Recommendation: $($result.Recommendation)"
        }
        else {
            $report += "Status: OK"
            $report += "Recommendation: $($result.Recommendation)"
        }
        
        $report += ""
        $report += "-" * 60
        $report += ""
    }
    
    $report += ""
    $report += "Summary:"
    $report += "  Total Services Checked: $totalCount"
    $report += "  Vulnerable Services: $vulnerableCount"
    $report += "  Secure Services: $($totalCount - $vulnerableCount)"
    $report += ""
    $report += "=" * 60
    
    return ($report -join "`n")
}

# Main execution
Write-Host "Starting Windows Service Registry Permission Audit..." -ForegroundColor Cyan

if ($ServiceName) {
    $servicesToCheck = @($ServiceName)
} else {
    $servicesToCheck = $DefaultServices
}

$allResults = @()

foreach ($service in $servicesToCheck) {
    Write-Host "Checking service: $service" -ForegroundColor Yellow
    if ($Verbose) {
        Write-Host "  Path: $(Get-ServiceRegistryPath -ServiceName $service)"
    }
    
    $result = Check-ServiceVulnerability -ServiceName $service
    $allResults += $result
}

$report = Format-Report -Results $allResults

if ($OutputFile) {
    $report | Out-File -FilePath $OutputFile -Encoding UTF8
    Write-Host "Report saved to: $OutputFile" -ForegroundColor Green
}

Write-Host ""
Write-Host $report

# Exit with appropriate code
$vulnerableCount = ($allResults | Where-Object { $_.IsVulnerable }).Count
if ($vulnerableCount -gt 0) {
    Write-Host ""
    Write-Host "WARNING: $vulnerableCount vulnerable service(s) found!" -ForegroundColor Red
    exit 1
} else {
    Write-Host ""
    Write-Host "No vulnerabilities detected." -ForegroundColor Green
    exit 0
}
