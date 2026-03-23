#!/usr/bin/env pwsh
# Get SDDL for an AD object
# Usage: ./get-object-sddl.ps1 -LdapPath "LDAP://CN=Users,DC=domain,DC=tld"

param(
    [Parameter(Mandatory=$true)]
    [string]$LdapPath
)

try {
    $entry = New-Object System.DirectoryServices.DirectoryEntry($LdapPath)
    $sddl = $entry.psbase.ObjectSecurity.Sddl
    Write-Output $sddl
} catch {
    Write-Error "Failed to retrieve SDDL: $_"
    exit 1
}
