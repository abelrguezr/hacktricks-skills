# RDP Connect - PowerShell Script for RDP Connection Automation
# Usage: .\rdp-connect.ps1 -Target <IP> -Username <user> [-Password <pass>]

param(
    [Parameter(Mandatory=$true)]
    [string]$Target,
    
    [Parameter(Mandatory=$true)]
    [string]$Username,
    
    [Parameter(Mandatory=$false)]
    [string]$Password,
    
    [Parameter(Mandatory=$false)]
    [switch]$AdminMode
)

# Security Warning
Write-Warning "WARNING: Only use this script on systems you own or have explicit authorization to access."

# Build RDP command
$rdpCommand = "mstsc /v:$Target"

if ($AdminMode) {
    $rdpCommand += " /admin"
}

Write-Host "Connecting to $Target as $Username..."
Write-Host "RDP Command: $rdpCommand"

# Launch RDP client
Start-Process mstsc -ArgumentList $rdpCommand

Write-Host "RDP connection initiated. Enter credentials when prompted."
