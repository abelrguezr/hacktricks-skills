# Print Spooler Detection Rules Generator
# Creates Sysmon and EDR detection rules for Print Spooler exploitation

param(
    [string]$OutputPath = ".\PrintSpooler_Detection_Rules.xml"
)

Write-Host "=== Print Spooler Detection Rules Generator ===" -ForegroundColor Cyan
Write-Host ""

# Generate Sysmon configuration
$sysmonConfig = @"
<?xml version="1.0" encoding="UTF-16"?>
<SysmonSchema version="400">
  <!-- Print Spooler Detection Rules -->
  <!-- CVE-2021-1675, CVE-2021-34527, CVE-2021-34481, CVE-2022-21999 -->
  
  <!-- Monitor file creation in spool driver directory -->
  <FileCreate>
    <TargetFilename condition="contains">C:\Windows\System32\spool\drivers\</TargetFilename>
    <ParentImage condition="is">C:\Windows\System32\spoolsv.exe</ParentImage>
  </FileCreate>
  
  <!-- Monitor DLL loading by spoolsv.exe -->
  <ImageLoad>
    <Image condition="is">C:\Windows\System32\spoolsv.exe</Image>
    <Hash condition="notStartsWith">0000000000000000000000000000000000000000</Hash>
  </ImageLoad>
  
  <!-- Monitor process creation from spoolsv.exe -->
  <ProcessCreate>
    <ParentImage condition="is">C:\Windows\System32\spoolsv.exe</ParentImage>
    <Image condition="notStartsWith">C:\Windows\System32\</Image>
  </ProcessCreate>
  
  <!-- Monitor suspicious child processes from spoolsv.exe -->
  <ProcessCreate>
    <ParentImage condition="is">C:\Windows\System32\spoolsv.exe</ParentImage>
    <Image condition="contains">cmd.exe</Image>
  </ProcessCreate>
  
  <ProcessCreate>
    <ParentImage condition="is">C:\Windows\System32\spoolsv.exe</ParentImage>
    <Image condition="contains">powershell.exe</Image>
  </ProcessCreate>
  
  <ProcessCreate>
    <ParentImage condition="is">C:\Windows\System32\spoolsv.exe</ParentImage>
    <Image condition="contains">rundll32.exe</Image>
  </ProcessCreate>
  
  <!-- Monitor network connections from spoolsv.exe (potential C2) -->
  <NetworkConnect>
    <ProcessGuid condition="is">*</ProcessGuid>
    <ProcessImage condition="is">C:\Windows\System32\spoolsv.exe</ProcessImage>
  </NetworkConnect>
  
  <!-- Monitor registry changes related to Print Spooler -->
  <RegistryEvent type="Set">
    <TargetObject condition="contains">HKLM\SYSTEM\CurrentControlSet\Services\Spooler</TargetObject>
  </RegistryEvent>
  
  <!-- Monitor creation of directories in spool path (SpoolFool technique) -->
  <FileCreate>
    <TargetFilename condition="contains">C:\Windows\System32\spool\</TargetFilename>
    <CreationCallName condition="is">CreateDirectory</CreationCallName>
  </FileCreate>
</SysmonSchema>
"@

Write-Host "[1] Generating Sysmon Configuration..." -ForegroundColor Yellow
try {
    $sysmonConfig | Out-File -FilePath "$OutputPath" -Encoding UTF16LE -ErrorAction Stop
    Write-Host "  Sysmon config saved to: $OutputPath" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: Failed to save Sysmon config: $_" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Generate Event ID reference
Write-Host "[2] Event ID Reference:" -ForegroundColor Yellow
Write-Host "  Sysmon Event ID 11: File creation in spool driver directory" -ForegroundColor Cyan
Write-Host "  Sysmon Event ID 7:  DLL loaded by spoolsv.exe" -ForegroundColor Cyan
Write-Host "  Sysmon Event ID 1:  Process creation from spoolsv.exe" -ForegroundColor Cyan
Write-Host "  Event ID 808:       Print Service operational log - plugin load failure" -ForegroundColor Cyan
Write-Host ""

# Generate Sigma rules
$sigmaRules = @"
# Print Spooler Exploitation Detection Rules
# Compatible with Sigma (https://github.com/SigmaHQ/sigma)

title: Print Spooler DLL Load
id: 12345678-1234-1234-1234-123456789012
description: Detects DLL loading by Print Spooler service (potential PrintNightmare exploitation)
author: PrintNightmare Hardening Skill
date: 2024/01/01
logsource:
  category: process_creation
  product: windows
  service: sysmon
  definition: 'Sysmon Event ID 7 (ImageLoad)'
selection:
  Image: 'C:\\Windows\\System32\\spoolsv.exe'
  ImageLoaded: '*\\spool\\drivers\\*'
condition: selection
level: high

title: Print Spooler Process Spawn
id: 12345678-1234-1234-1234-123456789013
description: Detects suspicious process spawning from Print Spooler service
author: PrintNightmare Hardening Skill
date: 2024/01/01
logsource:
  category: process_creation
  product: windows
  service: sysmon
  definition: 'Sysmon Event ID 1 (ProcessCreate)'
selection:
  ParentImage: 'C:\\Windows\\System32\\spoolsv.exe'
  Image|contains:
    - 'cmd.exe'
    - 'powershell.exe'
    - 'rundll32.exe'
condition: selection
level: critical

title: Print Spooler File Creation
id: 12345678-1234-1234-1234-123456789014
description: Detects file creation in Print Spooler driver directory
author: PrintNightmare Hardening Skill
date: 2024/01/01
logsource:
  category: file_event
  product: windows
  service: sysmon
  definition: 'Sysmon Event ID 11 (FileCreate)'
selection:
  TargetFilename|contains: 'C:\\Windows\\System32\\spool\\drivers\\'
  ParentImage: 'C:\\Windows\\System32\\spoolsv.exe'
condition: selection
level: high
"@

$sigmaPath = ".\PrintSpooler_Sigma_Rules.yml"
Write-Host "[3] Generating Sigma Rules..." -ForegroundColor Yellow
try {
    $sigmaRules | Out-File -FilePath $sigmaPath -Encoding UTF8 -ErrorAction Stop
    Write-Host "  Sigma rules saved to: $sigmaPath" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: Failed to save Sigma rules: $_" -ForegroundColor Red
}
Write-Host ""

# Generate EDR query examples
Write-Host "[4] EDR Query Examples:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  CrowdStrike Falcon:" -ForegroundColor Cyan
Write-Host "    process_name = 'spoolsv.exe' AND (child_process_name IN ('cmd.exe', 'powershell.exe', 'rundll32.exe'))" -ForegroundColor Gray
Write-Host ""
Write-Host "  Carbon Black:" -ForegroundColor Cyan
Write-Host "    process_name:spoolsv.exe AND (child_process_name:cmd.exe OR child_process_name:powershell.exe)" -ForegroundColor Gray
Write-Host ""
Write-Host "  SentinelOne:" -ForegroundColor Cyan
Write-Host "    process_name == 'spoolsv.exe' AND child_process_name IN ['cmd.exe', 'powershell.exe', 'rundll32.exe']" -ForegroundColor Gray
Write-Host ""

Write-Host "=== Detection Rules Generated ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Files created:" -ForegroundColor Yellow
Write-Host "  - $OutputPath (Sysmon configuration)" -ForegroundColor Green
Write-Host "  - $sigmaPath (Sigma detection rules)" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Deploy Sysmon configuration to target systems" -ForegroundColor Gray
Write-Host "  2. Import Sigma rules into your SIEM" -ForegroundColor Gray
Write-Host "  3. Configure EDR alerts using the query examples" -ForegroundColor Gray
Write-Host "  4. Monitor for Event ID 808 in Print Service operational logs" -ForegroundColor Gray
