# Service Permission Checker
# Identifies services with weak permissions

param(
    [string]$Username = $env:USERNAME,
    [string]$OutputFile = "service-permissions.txt"
)

Write-Host "[*] Checking Service Permissions for: $Username" -ForegroundColor Cyan

$results = @()

# Get all services
$services = Get-WmiObject Win32_Service

foreach ($service in $services) {
    try {
        # Get service registry key
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$($service.Name)"
        $acl = Get-Acl $regPath -ErrorAction SilentlyContinue
        
        if ($acl) {
            # Check for weak permissions
            $weakPerms = @("FullControl", "Write", "Modify", "WriteDAC", "WriteOwner")
            
            foreach ($access in $acl.Access) {
                if ($access.IdentityReference -match "$Username|Everyone|Users|Authenticated Users|BUILTIN\\Users") {
                    foreach ($perm in $weakPerms) {
                        if ($access.FileSystemRights -match $perm) {
                            $results += [PSCustomObject]@{
                                ServiceName = $service.Name
                                DisplayName = $service.DisplayName
                                PathName = $service.PathName
                                User = $access.IdentityReference
                                Permission = $access.FileSystemRights
                                Inherited = $access.IsInherited
                            }
                        }
                    }
                }
            }
        }
    }
    catch {
        # Skip services we can't access
    }
}

# Output results
if ($results.Count -gt 0) {
    Write-Host "`n[!] Found $($results.Count) services with potentially weak permissions:" -ForegroundColor Red
    $results | Format-Table ServiceName, DisplayName, User, Permission -AutoSize
    
    # Save to file
    $results | Export-Csv -Path $OutputFile -NoTypeInformation
    Write-Host "[+] Results saved to: $OutputFile" -ForegroundColor Green
} else {
    Write-Host "[+] No weak service permissions found" -ForegroundColor Green
}
