# Active Directory Privileged Group Enumeration
# Usage: .\enumerate-groups.ps1 [-TargetGroup <group-name>]

param(
    [string]$TargetGroup,
    [switch]$AllGroups
)

$PrivilegedGroups = @(
    "Administrators",
    "Domain Admins",
    "Enterprise Admins",
    "Account Operators",
    "AdminSDHolder",
    "Backup Operators",
    "DnsAdmins",
    "Print Operators",
    "Server Operators",
    "Event Log Readers",
    "Exchange Windows Permissions",
    "Hyper-V Administrators",
    "Group Policy Creators Owners",
    "Organization Management",
    "Remote Desktop Users",
    "Remote Management Users"
)

function Test-Module {
    param([string]$ModuleName)
    try {
        Get-Module -ListAvailable -Name $ModuleName | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Get-GroupMembers {
    param([string]$GroupName)
    
    Write-Host "`n=== Enumerating: $GroupName ===" -ForegroundColor Cyan
    
    # Try PowerView first
    if (Test-Module "PowerView") {
        try {
            Import-Module PowerView -ErrorAction Stop
            $members = Get-NetGroupMember -Identity $GroupName -Recurse -ErrorAction SilentlyContinue
            if ($members) {
                $members | Select-Object MemberName, MemberDomain, MemberType | Format-Table -AutoSize
            } else {
                Write-Host "No members found or group does not exist" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "PowerView enumeration failed: $_" -ForegroundColor Red
        }
    }
    # Fallback to native cmdlets
    elseif (Test-Module "ActiveDirectory") {
        try {
            Import-Module ActiveDirectory -ErrorAction Stop
            $members = Get-ADGroupMember -Identity $GroupName -Recursive -ErrorAction SilentlyContinue
            if ($members) {
                $members | Select-Object Name, ObjectClass | Format-Table -AutoSize
            } else {
                Write-Host "No members found or group does not exist" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "AD module enumeration failed: $_" -ForegroundColor Red
        }
    }
    else {
        Write-Host "No enumeration module available. Install PowerView or ActiveDirectory module." -ForegroundColor Red
    }
}

# Main execution
if ($TargetGroup) {
    Get-GroupMembers -GroupName $TargetGroup
}
elseif ($AllGroups) {
    foreach ($group in $PrivilegedGroups) {
        Get-GroupMembers -GroupName $group
    }
}
else {
    Write-Host "Active Directory Privileged Group Enumerator" -ForegroundColor Green
    Write-Host "Usage: .\enumerate-groups.ps1 [-TargetGroup <group-name>] [-AllGroups]" -ForegroundColor Yellow
    Write-Host "`nAvailable privileged groups:" -ForegroundColor Cyan
    $PrivilegedGroups | ForEach-Object { Write-Host "  - $_" }
}
