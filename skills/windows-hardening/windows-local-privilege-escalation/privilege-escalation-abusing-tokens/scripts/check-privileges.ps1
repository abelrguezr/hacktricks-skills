# Windows Token Privilege Checker
# Usage: .\check-privileges.ps1

Write-Host "=== Windows Token Privilege Checker ===" -ForegroundColor Cyan
Write-Host ""

# Check current privileges
Write-Host "[+] Checking current privileges..." -ForegroundColor Yellow
$privileges = whoami /priv

Write-Host ""
Write-Host "Current Privileges:" -ForegroundColor Green
Write-Host $privileges

# Check for exploitable privileges
$exploitable = @(
    "SeImpersonatePrivilege",
    "SeAssignPrimaryTokenPrivilege",
    "SeTcbPrivilege",
    "SeBackupPrivilege",
    "SeRestorePrivilege",
    "SeCreateTokenPrivilege",
    "SeLoadDriverPrivilege",
    "SeTakeOwnershipPrivilege",
    "SeDebugPrivilege",
    "SeManageVolumePrivilege"
)

Write-Host ""
Write-Host "[+] Checking for exploitable privileges..." -ForegroundColor Yellow

foreach ($priv in $exploitable) {
    if ($privileges -match $priv) {
        $status = ($privileges | Select-String $priv).Line.Split("\t")[-1].Trim()
        Write-Host "  [!] $priv : $status" -ForegroundColor $(if ($status -eq "Enabled") { "Red" } else { "Yellow" })
    }
}

Write-Host ""
Write-Host "[+] If privileges are disabled, run EnableAllTokenPrivs.ps1 to enable them" -ForegroundColor Cyan
Write-Host "    Download from: https://raw.githubusercontent.com/fashionproof/EnableAllTokenPrivs/master/EnableAllTokenPrivs.ps1" -ForegroundColor Gray
