# Check PowerShell Configuration
# Run this script to check PowerShell language mode and execution policy

Write-Host "=== PowerShell Configuration Check ===" -ForegroundColor Cyan

# Check language mode
Write-Host "`nLanguage Mode:" -ForegroundColor Yellow
$mode = $ExecutionContext.SessionState.LanguageMode
Write-Host "  Current Mode: $mode" -ForegroundColor White

if ($mode -eq "ConstrainedLanguage") {
    Write-Host "  WARNING: Constrained Language Mode is active" -ForegroundColor Red
    Write-Host "  Consider bypass methods: PSv2, PSByPassCLM, ReflectivePick" -ForegroundColor Yellow
}

# Check execution policy
Write-Host "`nExecution Policy:" -ForegroundColor Yellow
$policies = Get-ExecutionPolicy -List -ErrorAction SilentlyContinue
foreach ($policy in $policies) {
    Write-Host "  $($policy.Scope): $($policy.ExecutionPolicy)" -ForegroundColor White
}

# Check available PowerShell versions
Write-Host "`nPowerShell Versions:" -ForegroundColor Yellow
$psPaths = @(
    "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe",
    "C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe",
    "C:\Windows\System32\WindowsPowerShell\v1.0\powershell_ise.exe"
)
foreach ($path in $psPaths) {
    if (Test-Path $path) {
        Write-Host "  Found: $path" -ForegroundColor Green
    }
}
