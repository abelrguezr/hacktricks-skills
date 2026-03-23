#!/usr/bin/env pwsh
# Check Windows Event Log for service creation events (SCMExec indicators)
# Usage: .\check-service-events.ps1 [-ComputerName <name>] [-Hours <number>] [-OutputFile <path>]

param(
    [string]$ComputerName = $env:COMPUTERNAME,
    [int]$Hours = 24,
    [string]$OutputFile = "service-events-report.json"
)

$StartTime = (Get-Date).AddHours(-$Hours)
$Results = @()

try {
    # Event IDs for service creation/modification
    $EventIds = @(
        @{ Id = 7045; Name = "New Service Installed" },
        @{ Id = 7040; Name = "Service Changed" },
        @{ Id = 7046; Name = "Service Installed with New Type" }
    )
    
    foreach ($Event in $EventIds) {
        try {
            $Events = Get-WinEvent -FilterHashtable @{
                LogName = "System"
                Id = $Event.Id
                StartTime = $StartTime
            } -ErrorAction SilentlyContinue
            
            foreach ($WinEvent in $Events) {
                $Message = $WinEvent.Message
                $TimeCreated = $WinEvent.TimeCreated
                
                # Extract service name from message
                $ServiceName = $null
                if ($Message -match "Service name:\s*([^\r\n]+)") {
                    $ServiceName = $Matches[1].Trim()
                }
                
                $Results += [PSCustomObject]@{
                    EventId = $Event.Id
                    EventName = $Event.Name
                    TimeCreated = $TimeCreated.ToString("o")
                    ServiceName = $ServiceName
                    Message = $Message -replace "\r\n", " " -replace "\n", " "
                    ComputerName = $ComputerName
                    RecordId = $WinEvent.Id
                }
            }
        } catch {
            Write-Warning "Error retrieving Event ID $($Event.Id): $_"
        }
    }
    
    # Output results
    $Report = @{
        ScanDate = Get-Date -Format "o"
        ComputerName = $ComputerName
        TimeRangeHours = $Hours
        StartTime = $StartTime.ToString("o")
        TotalEventsFound = $Results.Count
        Events = $Results
    }
    
    # Save to file
    $Report | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputFile -Encoding UTF8
    
    if ($Results.Count -gt 0) {
        Write-Host "Found $($Results.Count) service-related events in the last $Hours hours. Report saved to: $OutputFile" -ForegroundColor Yellow
        
        Write-Host "`nRecent Service Events:" -ForegroundColor Cyan
        foreach ($Result in $Results | Select-Object -First 10) {
            Write-Host "  [$($Result.TimeCreated)] Event $($Result.EventId) - $($Result.ServiceName)" -ForegroundColor White
        }
        
        if ($Results.Count -gt 10) {
            Write-Host "  ... and $($Results.Count - 10) more events" -ForegroundColor Gray
        }
    } else {
        Write-Host "No service-related events found in the last $Hours hours" -ForegroundColor Green
    }
    
} catch {
    Write-Error "Error scanning event logs: $_"
    exit 1
}
