#!/usr/bin/env pwsh
# Find users with non-default primary group (not Domain Users, RID 513)
# Usage: ./find-nondefault-pgid.ps1

Write-Host "Searching for users with non-default primary group..."
Write-Host "Default Domain Users RID: 513"
Write-Host ""

$users = Get-ADUser -Filter * -Properties primaryGroup, primaryGroupID -ErrorAction SilentlyContinue

$nonDefault = $users | Where-Object { $_.primaryGroupID -ne 513 -and $_.primaryGroupID -ne $null }

if ($nonDefault.Count -eq 0) {
    Write-Host "No users with non-default primary group found."
} else {
    Write-Host "Found $($nonDefault.Count) user(s) with non-default primary group:"
    Write-Host ""
    $nonDefault | Select-Object Name, SamAccountName, primaryGroupID, primaryGroup | Format-Table -AutoSize
}

# Also check for hidden primaryGroupID
Write-Host ""
Write-Host "Checking for users with hidden primaryGroupID (DACL deny)..."
$hidden = Get-ADUser -Filter * -Properties primaryGroupID -ErrorAction SilentlyContinue | Where-Object { -not $_.primaryGroupID }

if ($hidden.Count -eq 0) {
    Write-Host "No users with hidden primaryGroupID found."
} else {
    Write-Host "Found $($hidden.Count) user(s) with hidden primaryGroupID:"
    Write-Host ""
    $hidden | Select-Object Name, SamAccountName | Format-Table -AutoSize
}
