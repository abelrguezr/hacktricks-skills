# Windows Autorun Enumeration Script
# Comprehensive check of all major autorun persistence mechanisms
# Output saved to autorun-enumeration.txt

$OutputFile = "autorun-enumeration.txt"
$Results = @()

function Write-Result {
    param($Category, $Command, $Output)
    $Results += "`n=== $Category ==="
    $Results += "Command: $Command"
    $Results += "Output:"
    $Results += $Output
    $Results += ""
}

# 1. WMIC Startup
$Results += "`n========================================"
$Results += "Windows Autorun Enumeration Report"
$Results += "Generated: $(Get-Date)"
$Results += "========================================"

# WMIC
$wmicOutput = wmic startup get caption,command 2>$null
Write-Result "WMIC Startup" "wmic startup get caption,command" $wmicOutput

# CIM Startup
$cimOutput = Get-CimInstance Win32_StartupCommand | Select-Object Name, Command, Location, User | Format-List | Out-String
Write-Result "CIM Startup Commands" "Get-CimInstance Win32_StartupCommand" $cimOutput

# 2. Scheduled Tasks
$schtasksOutput = schtasks /query /fo TABLE /nh 2>$null | Select-String -Pattern "disable|deshab" -NotMatch
Write-Result "Scheduled Tasks" "schtasks /query /fo TABLE /nh" $schtasksOutput

# SYSTEM tasks
$schtasksList = schtasks /query /fo LIST 2>$null
$systemTasks = $schtasksList | Select-String "SYSTEM|Task To Run" -Context 1,0
Write-Result "SYSTEM Scheduled Tasks" "schtasks /query /fo LIST | findstr SYSTEM" $systemTasks

# PowerShell scheduled tasks
$psTasks = Get-ScheduledTask | Where-Object {$_.TaskPath -notlike "\Microsoft*"} | Format-Table TaskName, TaskPath, State | Out-String
Write-Result "PowerShell Scheduled Tasks" "Get-ScheduledTask" $psTasks

# 3. Startup Folders
$startupFolders = @(
    "C:\Documents and Settings\All Users\Start Menu\Programs\Startup",
    "C:\Documents and Settings\$env:USERNAME\Start Menu\Programs\Startup",
    "$env:programdata\Microsoft\Windows\Start Menu\Programs\Startup",
    "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup",
    "C:\Users\All Users\Start Menu\Programs\Startup",
    "C:\Users\$env:USERNAME\Start Menu\Programs\Startup"
)

$Results += "`n=== Startup Folders ==="
foreach ($folder in $startupFolders) {
    if (Test-Path $folder) {
        $files = Get-ChildItem $folder -ErrorAction SilentlyContinue
        $Results += "`nFolder: $folder"
        $Results += $files | Format-Table Name, Length, LastWriteTime | Out-String
    } else {
        $Results += "`nFolder: $folder (NOT FOUND)"
    }
}
$Results += ""

# 4. Registry Run Keys
$runKeys = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKCU:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Terminal Server\Install\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Terminal Server\Install\Software\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Terminal Server\Install\Software\Microsoft\Windows\CurrentVersion\RunOnceEx"
)

foreach ($key in $runKeys) {
    try {
        $items = Get-ItemProperty -Path $key -ErrorAction Stop
        $output = $items | Format-List | Out-String
        Write-Result "Registry: $key" "Get-ItemProperty $key" $output
    } catch {
        Write-Result "Registry: $key" "Get-ItemProperty $key" "Key not found or access denied"
    }
}

# 5. RunServices Keys
$runServiceKeys = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunServices",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunServicesOnce",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunServices",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunServicesOnce",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\RunServices",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\RunServicesOnce"
)

foreach ($key in $runServiceKeys) {
    try {
        $items = Get-ItemProperty -Path $key -ErrorAction Stop
        $output = $items | Format-List | Out-String
        Write-Result "RunServices: $key" "Get-ItemProperty $key" $output
    } catch {
        Write-Result "RunServices: $key" "Get-ItemProperty $key" "Key not found or access denied"
    }
}

# 6. RunOnceEx Keys
$runOnceExKeys = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnceEx",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\RunOnceEx",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnceEx",
    "HKCU:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\RunOnceEx"
)

foreach ($key in $runOnceExKeys) {
    try {
        $items = Get-ItemProperty -Path $key -ErrorAction Stop
        $output = $items | Format-List | Out-String
        Write-Result "RunOnceEx: $key" "Get-ItemProperty $key" $output
    } catch {
        Write-Result "RunOnceEx: $key" "Get-ItemProperty $key" "Key not found or access denied"
    }
}

# 7. Startup Path Registry
$shellFolderKeys = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
)

foreach ($key in $shellFolderKeys) {
    try {
        $items = Get-ItemProperty -Path $key -Name "Common Startup" -ErrorAction Stop
        $output = $items | Format-List | Out-String
        Write-Result "Shell Folders: $key" "Get-ItemProperty $key -Name 'Common Startup'" $output
    } catch {
        Write-Result "Shell Folders: $key" "Get-ItemProperty $key -Name 'Common Startup'" "Key not found or access denied"
    }
}

# 8. Winlogon Keys
try {
    $userinit = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "Userinit" -ErrorAction Stop
    $shell = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "Shell" -ErrorAction Stop
    $output = "Userinit: $($userinit.Userinit)`nShell: $($shell.Shell)"
    Write-Result "Winlogon Keys" "Get-ItemProperty Winlogon" $output
} catch {
    Write-Result "Winlogon Keys" "Get-ItemProperty Winlogon" "Key not found or access denied"
}

# 9. Policy Settings
try {
    $policyRun = Get-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "Run" -ErrorAction Stop
    Write-Result "Policy Run (HKLM)" "Get-ItemProperty Policies\Explorer -Name Run" $policyRun.Run
} catch {
    Write-Result "Policy Run (HKLM)" "Get-ItemProperty Policies\Explorer -Name Run" "Key not found or access denied"
}

try {
    $policyRun = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "Run" -ErrorAction Stop
    Write-Result "Policy Run (HKCU)" "Get-ItemProperty Policies\Explorer -Name Run" $policyRun.Run
} catch {
    Write-Result "Policy Run (HKCU)" "Get-ItemProperty Policies\Explorer -Name Run" "Key not found or access denied"
}

# 10. AlternateShell
try {
    $alternateShell = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SafeBoot" -Name "AlternateShell" -ErrorAction Stop
    Write-Result "AlternateShell" "Get-ItemProperty SafeBoot -Name AlternateShell" $alternateShell.AlternateShell
} catch {
    Write-Result "AlternateShell" "Get-ItemProperty SafeBoot -Name AlternateShell" "Key not found or access denied"
}

# 11. Active Setup
$activeSetupKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components",
    "HKCU:\SOFTWARE\Microsoft\Active Setup\Installed Components",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Active Setup\Installed Components",
    "HKCU:\SOFTWARE\Wow6432Node\Microsoft\Active Setup\Installed Components"
)

foreach ($key in $activeSetupKeys) {
    try {
        $components = Get-ChildItem -Path $key -ErrorAction Stop
        $output = @()
        foreach ($comp in $components) {
            try {
                $stubPath = Get-ItemProperty -Path $comp.PSPath -Name "StubPath" -ErrorAction SilentlyContinue
                $isInstalled = Get-ItemProperty -Path $comp.PSPath -Name "IsInstalled" -ErrorAction SilentlyContinue
                $output += "Component: $($comp.Name)"
                if ($stubPath) { $output += "  StubPath: $($stubPath.StubPath)" }
                if ($isInstalled) { $output += "  IsInstalled: $($isInstalled.IsInstalled)" }
            } catch {}
        }
        Write-Result "Active Setup: $key" "Get-ChildItem $key" ($output -join "`n")
    } catch {
        Write-Result "Active Setup: $key" "Get-ChildItem $key" "Key not found or access denied"
    }
}

# 12. Browser Helper Objects
try {
    $bhoKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Browser Helper Objects",
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\Browser Helper Objects"
    )
    $output = @()
    foreach ($bhoKey in $bhoKeys) {
        $bhos = Get-ChildItem -Path $bhoKey -ErrorAction SilentlyContinue
        foreach ($bho in $bhos) {
            $output += "BHO CLSID: $($bho.Name)"
            try {
                $clsidInfo = Get-ItemProperty -Path "HKLM:\SOFTWARE\Classes\CLSID\$($bho.Name)" -ErrorAction SilentlyContinue
                if ($clsidInfo) { $output += "  Info: $($clsidInfo | Out-String)" }
            } catch {}
        }
    }
    Write-Result "Browser Helper Objects" "Get-ChildItem BHO keys" ($output -join "`n")
} catch {
    Write-Result "Browser Helper Objects" "Get-ChildItem BHO keys" "Error enumerating BHOs"
}

# 13. Font Drivers
try {
    $fontDrivers = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Font Drivers" -ErrorAction Stop
    Write-Result "Font Drivers (HKLM)" "Get-ItemProperty Font Drivers" ($fontDrivers | Format-List | Out-String)
} catch {
    Write-Result "Font Drivers (HKLM)" "Get-ItemProperty Font Drivers" "Key not found or access denied"
}

# 14. HTML Open Command
try {
    $htmlOpen = Get-ItemProperty -Path "HKLM:\SOFTWARE\Classes\htmlfile\shell\open\command" -Name "" -ErrorAction Stop
    Write-Result "HTML Open Command" "Get-ItemProperty htmlfile\shell\open\command" $htmlOpen.
} catch {
    Write-Result "HTML Open Command" "Get-ItemProperty htmlfile\shell\open\command" "Key not found or access denied"
}

# Save output
$Results | Out-File -FilePath $OutputFile -Encoding UTF8
Write-Host "Enumeration complete. Results saved to: $OutputFile"
Write-Host "Total sections: $($Results.Count)"
