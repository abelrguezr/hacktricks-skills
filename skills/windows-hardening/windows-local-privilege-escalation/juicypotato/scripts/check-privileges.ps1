# Check for JuicyPotato required privileges
# Run this to verify if the current user can use JuicyPotato

Write-Host "[*] Checking for JuicyPotato required privileges..." -ForegroundColor Cyan

$requiredPrivs = @(
    "SeImpersonatePrivilege",
    "SeAssignPrimaryTokenPrivilege"
)

$privileges = whoami /priv | Select-String "SeImpersonatePrivilege|SeAssignPrimaryTokenPrivilege"

$found = $false
foreach ($priv in $requiredPrivs) {
    if ($privileges -match $priv) {
        Write-Host "[+] Found: $priv" -ForegroundColor Green
        $found = $true
    }
}

if ($found) {
    Write-Host "`n[+] Privileges present - JuicyPotato should work!" -ForegroundColor Green
} else {
    Write-Host "`n[-] Required privileges not found - JuicyPotato will not work" -ForegroundColor Red
    Write-Host "    Consider other LPE techniques or privilege escalation paths" -ForegroundColor Yellow
}
