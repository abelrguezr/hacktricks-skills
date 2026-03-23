# Windows Credential Protections Checker
# Run as Administrator

Write-Host "=== Windows Credential Protections Audit ===" -ForegroundColor Cyan
Write-Host ""

# WDigest Status
Write-Host "[1] WDigest Protection" -ForegroundColor Yellow
try {
    $wdigest = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest" -ErrorAction Stop
    if ($wdigest.UseLogonCredential -eq 1) {
        Write-Host "  Status: ENABLED (INSECURE - plain text passwords in memory)" -ForegroundColor Red
    } else {
        Write-Host "  Status: DISABLED (secure)" -ForegroundColor Green
    }
} catch {
    Write-Host "  Status: DISABLED (registry key not found)" -ForegroundColor Green
}

# LSA PPL Status
Write-Host ""
Write-Host "[2] LSA PPL Protection" -ForegroundColor Yellow
try {
    $lsa = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\LSA" -ErrorAction Stop
    if ($lsa.RunAsPPL -eq 1) {
        Write-Host "  Status: ENABLED (LSASS is PPL protected)" -ForegroundColor Green
    } else {
        Write-Host "  Status: DISABLED (LSASS is unprotected)" -ForegroundColor Red
    }
} catch {
    Write-Host "  Status: DISABLED (registry key not found)" -ForegroundColor Red
}

# Credential Guard Status
Write-Host ""
Write-Host "[3] Credential Guard" -ForegroundColor Yellow
try {
    $cg = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\LSA" -ErrorAction Stop
    switch ($cg.LsaCfgFlags) {
        1 { Write-Host "  Status: ENABLED with UEFI lock" -ForegroundColor Green }
        2 { Write-Host "  Status: ENABLED without UEFI lock" -ForegroundColor Yellow }
        0 { Write-Host "  Status: DISABLED" -ForegroundColor Red }
        default { Write-Host "  Status: UNKNOWN" -ForegroundColor Gray }
    }
} catch {
    Write-Host "  Status: DISABLED (registry key not found)" -ForegroundColor Red
}

# Cached Logons Count
Write-Host ""
Write-Host "[4] Cached Credentials" -ForegroundColor Yellow
try {
    $cached = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction Stop
    Write-Host "  CachedLogonsCount: $($cached.CachedLogonsCount)" -ForegroundColor White
    if ($cached.CachedLogonsCount -gt 5) {
        Write-Host "  Recommendation: Consider reducing to 5 or less" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  Status: Default (10)" -ForegroundColor Gray
}

# Protected Users Group
Write-Host ""
Write-Host "[5] Protected Users Group" -ForegroundColor Yellow
try {
    $protectedUsers = Get-ADGroup -Identity "Protected Users" -ErrorAction Stop
    $members = Get-ADGroupMember -Identity "Protected Users" -ErrorAction Stop | Select-Object -ExpandProperty Name
    Write-Host "  Members: $($members.Count)" -ForegroundColor White
    if ($members.Count -gt 0) {
        Write-Host "  Sample members: $($members -join ", ")" -ForegroundColor Gray
    }
} catch {
    Write-Host "  Status: Cannot query (AD module not available or not domain-joined)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== Audit Complete ===" -ForegroundColor Cyan
