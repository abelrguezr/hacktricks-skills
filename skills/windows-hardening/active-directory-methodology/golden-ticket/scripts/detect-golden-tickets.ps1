# Golden Ticket Detection Script
# PowerShell script to detect potential Golden Ticket activity

param(
    [switch]$QuickScan,
    [switch]$Verbose,
    [int]$MaxEvents = 100
)

function Write-Header {
    param([string]$Text)
    Write-Host "`n=== $Text ===" -ForegroundColor Cyan
}

function Write-Warning {
    param([string]$Text)
    Write-Host "[!] $Text" -ForegroundColor Yellow
}

function Write-Alert {
    param([string]$Text)
    Write-Host "[!] ALERT: $Text" -ForegroundColor Red
}

function Write-Info {
    param([string]$Text)
    Write-Host "[+] $Text" -ForegroundColor Green
}

# Check for admin privileges
Write-Header "Privilege Check"
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    Write-Info "Running with administrator privileges"
} else {
    Write-Warning "Not running as administrator - some checks may be limited"
}

# Check 1: TGS requests without TGT requests (Event 4769 without 4768)
Write-Header "TGS Without TGT Detection"
Write-Info "Looking for Event 4769 (TGS requests) without prior Event 4768 (TGT requests)"

try {
    $tgsEvents = Get-WinEvent -FilterHashtable @{LogName='Security';Id=4769} -MaxEvents $MaxEvents -ErrorAction Stop
    $tgtEvents = Get-WinEvent -FilterHashtable @{LogName='Security';Id=4768} -MaxEvents $MaxEvents -ErrorAction Stop
    
    $suspiciousCount = 0
    
    foreach ($tgs in $tgsEvents) {
        $tgsTime = $tgs.TimeCreated
        $tgsUser = ($tgs.Properties[8]).ToString()
        $tgsService = ($tgs.Properties[0]).ToString()
        
        # Look for TGT request within 5 minutes before this TGS
        $priorTgt = $tgtEvents | Where-Object {
            $tgtTime = $_.TimeCreated
            $tgtUser = ($_.Properties[8]).ToString()
            $timeDiff = ($tgsTime - $tgtTime).TotalMinutes
            $timeDiff -ge 0 -and $timeDiff -le 5 -and $tgtUser -eq $tgsUser
        }
        
        if (-not $priorTgt) {
            $suspiciousCount++
            if ($Verbose) {
                Write-Host "  Suspicious TGS: User=$tgsUser, Service=$tgsService, Time=$tgsTime" -ForegroundColor Yellow
            }
        }
    }
    
    if ($suspiciousCount -gt 0) {
        Write-Alert "Found $suspiciousCount TGS requests without prior TGT requests - potential Golden Ticket activity"
    } else {
        Write-Info "No suspicious TGS patterns detected in sampled events"
    }
} catch {
    Write-Warning "Could not query event logs: $_"
}

# Check 2: Admin account logons (Event 4672)
Write-Header "Privileged Account Activity"
Write-Info "Checking for privileged account logons (Event 4672)"

try {
    $adminLogons = Get-WinEvent -FilterHashtable @{LogName='Security';Id=4672} -MaxEvents 10 -ErrorAction Stop
    
    if ($adminLogons.Count -gt 0) {
        Write-Info "Recent privileged logons:"
        foreach ($logon in $adminLogons) {
            $user = ($logon.Properties[0]).ToString()
            $time = $logon.TimeCreated
            Write-Host "  - $user at $time" -ForegroundColor White
        }
    } else {
        Write-Info "No recent privileged logons detected"
    }
} catch {
    Write-Warning "Could not query event logs: $_"
}

# Check 3: Account logons (Event 4624)
Write-Header "Account Logon Activity"
Write-Info "Checking for account logons (Event 4624)"

try {
    $logons = Get-WinEvent -FilterHashtable @{LogName='Security';Id=4624} -MaxEvents 10 -ErrorAction Stop
    
    if ($logons.Count -gt 0) {
        Write-Info "Recent account logons:"
        foreach ($logon in $logons) {
            $user = ($logon.Properties[5]).ToString()
            $logonType = ($logon.Properties[8]).ToString()
            $time = $logon.TimeCreated
            Write-Host "  - $user (Type $logonType) at $time" -ForegroundColor White
        }
    }
} catch {
    Write-Warning "Could not query event logs: $_"
}

# Check 4: Kerberos policy
Write-Header "Kerberos Policy Check"
Write-Info "Checking domain Kerberos policy"

try {
    if (Get-Command Get-DomainPolicy -ErrorAction SilentlyContinue) {
        $policy = Get-DomainPolicy | Select-Object -ExpandProperty KerberosPolicy
        Write-Host "Kerberos Policy: $policy" -ForegroundColor White
    } else {
        Write-Warning "Get-DomainPolicy not available (requires PowerView/AD module)"
    }
} catch {
    Write-Warning "Could not retrieve Kerberos policy: $_"
}

# Summary
Write-Header "Detection Summary"
Write-Info "Golden Ticket detection checks completed"
Write-Info ""
Write-Info "Key indicators to monitor:"
Write-Host "  1. Event 4769 (TGS) without prior Event 4768 (TGT)" -ForegroundColor White
Write-Host "  2. Unusual ticket lifetimes (default 10 years is anomalous)" -ForegroundColor White
Write-Host "  3. Privileged account TGS requests" -ForegroundColor White
Write-Host "  4. Kerberos traffic with unusual patterns" -ForegroundColor White
Write-Info ""
Write-Info "For comprehensive detection, consider:"
Write-Host "  - Implementing Kerberos traffic monitoring" -ForegroundColor White
Write-Host "  - Setting up alerts for sensitive account activity" -ForegroundColor White
Write-Host "  - Regular krbtgt password rotation" -ForegroundColor White
Write-Host "  - Using tools like BloodHound for attack path analysis" -ForegroundColor White
