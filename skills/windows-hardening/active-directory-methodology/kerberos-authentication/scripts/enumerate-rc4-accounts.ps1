#!/usr/bin/env pwsh
# Enumerate AD accounts with RC4 encryption enabled
# Use this to identify Kerberoast targets before RC4 deprecation

param(
    [string]$Domain = $env:USERDNSDOMAIN,
    [string]$OutputFile = "rc4-accounts.txt"
)

Write-Host "[*] Enumerating accounts with RC4 encryption enabled..."
Write-Host "[*] Domain: $Domain"

try {
    # LDAP filter for msDS-SupportedEncryptionTypes = 4 (RC4-HMAC)
    $accounts = Get-ADObject -LDAPFilter '(msDS-SupportedEncryptionTypes=4)' -Properties msDS-SupportedEncryptionTypes -SearchBase "DC=$Domain" -ErrorAction Stop

    if ($accounts.Count -eq 0) {
        Write-Host "[!] No accounts with RC4 encryption found"
        exit 0
    }

    Write-Host "[*] Found $($accounts.Count) accounts with RC4 enabled"
    
    $results = foreach ($account in $accounts) {
        [PSCustomObject]@{
            DistinguishedName = $account.DistinguishedName
            Name = $account.Name
            ObjectClass = $account.ObjectClass
            EncryptionTypes = $account."msDS-SupportedEncryptionTypes"
        }
    }

    # Save to file
    $results | Export-Csv -Path $OutputFile -NoTypeInformation
    Write-Host "[*] Results saved to: $OutputFile"
    
    # Display summary
    $results | Format-Table -AutoSize

} catch {
    Write-Host "[!] Error: $_"
    exit 1
}
