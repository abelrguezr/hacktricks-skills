#!/usr/bin/env pwsh
# Find OUs where the current user can create objects
# Usage: .\find-writable-ous.ps1

param(
    [string]$Domain = $env:USERDNSDOMAIN
)

Write-Host "[*] Finding writable OUs in domain: $Domain" -ForegroundColor Cyan

try {
    $searcher = New-Object System.DirectoryServices.DirectorySearcher
    $searcher.SearchRoot = [ADSI]"LDAP://$Domain"
    $searcher.Filter = "(objectClass=organizationalUnit)"
    $searcher.PropertiesToLoad.Add('distinguishedname') | Out-Null
    $searcher.PropertiesToLoad.Add('name') | Out-Null
    
    $ous = $searcher.FindAll()
    $writableOus = @()
    
    foreach ($ou in $ous) {
        $ouPath = $ou.Properties['distinguishedname'][0]
        
        try {
            $ouObj = [ADSI]"LDAP://$ouPath"
            $acl = $ouObj.ObjectSecurity
            
            # Check if current user has CreateChild permission
            $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
            
            $hasCreate = $false
            foreach ($ace in $acl.GetAccessRules($true, $true, [System.Security.Principal.NTAccount])) {
                if ($ace.IdentityReference.Value -eq $currentUser -or 
                    $ace.IdentityReference.Value -eq 'Authenticated Users' -or
                    $ace.IdentityReference.Value -eq 'Domain Users') {
                    if ($ace.AccessControlType -eq 'Allow' -and 
                        $ace.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::CreateChild) {
                        $hasCreate = $true
                        break
                    }
                }
            }
            
            if ($hasCreate) {
                $writableOus += @{
                    Name = $ou.Properties['name'][0]
                    DN = $ouPath
                }
            }
        } catch {
            # Skip OUs we can't access
        }
    }
    
    if ($writableOus.Count -gt 0) {
        Write-Host "[+] Found $($writableOus.Count) writable OUs:" -ForegroundColor Green
        foreach ($ou in $writableOus) {
            Write-Host "    - $($ou.Name)" -ForegroundColor Gray
            Write-Host "      DN: $($ou.DN)" -ForegroundColor Gray
        }
    } else {
        Write-Host "[-] No writable OUs found" -ForegroundColor Red
        Write-Host "    You need 'Create All Child Objects' or 'Create msDS-DelegatedManagedServiceAccount' permission" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "[!] Error: $_" -ForegroundColor Red
    exit 1
}
