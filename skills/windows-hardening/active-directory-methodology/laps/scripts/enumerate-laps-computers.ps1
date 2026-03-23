# LAPS Computer Enumerator
# Find all computers with LAPS enabled in the domain

param(
    [string]$SearchBase = "",
    [string]$OutputFile = "laps-computers.csv"
)

Write-Host "=== LAPS Computer Enumeration ===" -ForegroundColor Cyan

# Import required modules
try {
    Import-Module ActiveDirectory -ErrorAction Stop
} catch {
    Write-Host "  Warning: ActiveDirectory module not available, using PowerView" -ForegroundColor Yellow
}

# Build search filter
$filter = "(&(objectClass=computer)(ms-mcs-admpwdexpirationtime=*))"

Write-Host "`nSearching for LAPS-enabled computers..." -ForegroundColor Yellow

if ($SearchBase) {
    Write-Host "  Search Base: $SearchBase" -ForegroundColor Gray
    $computers = Get-DomainObject -SearchBase $SearchBase -Filter $filter -Properties "ms-mcs-admpwdexpirationtime","ms-mcs-AdmPwd" -ErrorAction SilentlyContinue
} else {
    Write-Host "  Search Base: Entire domain" -ForegroundColor Gray
    $computers = Get-DomainObject -Filter $filter -Properties "ms-mcs-admpwdexpirationtime","ms-mcs-AdmPwd" -ErrorAction SilentlyContinue
}

if ($computers) {
    Write-Host "`nFound $($computers.Count) LAPS-enabled computers:" -ForegroundColor Green
    
    $results = @()
    foreach ($comp in $computers) {
        $expTime = $comp."ms-mcs-admpwdexpirationtime"
        $expDate = if ($expTime) {
            [DateTime]::FromFileTime($expTime).ToString("yyyy-MM-dd HH:mm:ss")
        } else { "N/A" }
        
        $results += [PSCustomObject]@{
            ComputerName = $comp.DnsHostname
            DistinguishedName = $comp.DistinguishedName
            ExpirationTime = $expDate
            HasPassword = if ($comp."ms-mcs-AdmPwd") { "Yes" } else { "No" }
        }
    }
    
    # Display results
    $results | Select-Object ComputerName, ExpirationTime, HasPassword | Format-Table -AutoSize
    
    # Export to CSV
    $results | Export-Csv -Path $OutputFile -NoTypeInformation
    Write-Host "`nResults exported to: $OutputFile" -ForegroundColor Gray
} else {
    Write-Host "`nNo LAPS-enabled computers found" -ForegroundColor Red
}

Write-Host "`n=== Enumeration Complete ===" -ForegroundColor Cyan
