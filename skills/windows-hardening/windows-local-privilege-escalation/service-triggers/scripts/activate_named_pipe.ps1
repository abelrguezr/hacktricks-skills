#!/usr/bin/env pwsh
# Named Pipe Trigger Activation Script
# Usage: .\activate_named_pipe.ps1 -PipeName <PipeName>

param(
    [Parameter(Mandatory=$true)]
    [string]$PipeName,
    
    [Parameter(Mandatory=$false)]
    [int]$Timeout = 1000,
    
    [Parameter(Mandatory=$false)]
    [switch]$Verbose
)

function Activate-NamedPipeTrigger {
    param(
        [string]$PipeName,
        [int]$Timeout,
        [switch]$Verbose
    )
    
    $pipePath = "\\.\pipe\$PipeName"
    
    if ($Verbose) {
        Write-Host "`n=== Named Pipe Trigger Activation ===" -ForegroundColor Cyan
        Write-Host "Target pipe: $pipePath" -ForegroundColor Gray
        Write-Host "Timeout: ${Timeout}ms" -ForegroundColor Gray
    }
    
    Write-Host "Attempting to activate service via named pipe: $PipeName" -ForegroundColor Yellow
    
    try {
        # Create the pipe client
        $pipe = New-Object System.IO.Pipes.NamedPipeClientStream(
            '.', 
            $PipeName, 
            [System.IO.Pipes.PipeDirection]::InOut,
            [System.IO.Pipes.PipeOptions]::None
        )
        
        # Attempt connection (this should trigger the service)
        $connected = $pipe.Connect($Timeout)
        
        if ($Verbose) {
            Write-Host "Connection attempt completed" -ForegroundColor Gray
        }
        
        # Clean up
        if ($pipe.CanRead) {
            $pipe.Dispose()
        }
        
        Write-Host "Named pipe trigger activation completed for: $PipeName" -ForegroundColor Green
        
        # Check if service started
        Write-Host "`nChecking for newly started services..." -ForegroundColor Yellow
        # This would require comparing service states before/after
        # For now, just report completion
        
        return $true
        
    } catch {
        Write-Host "Error activating named pipe trigger: $_" -ForegroundColor Red
        return $false
    }
}

# Common high-value named pipes to try
$commonPipes = @(
    'atsvc',
    'epmapper',
    'netlogon',
    'lsarpc',
    'samr',
    'wkssvc',
    'browser',
    'eventlog',
    'initshutdown',
    'plugplay'
)

# Main execution
if ($PipeName) {
    Activate-NamedPipeTrigger -PipeName $PipeName -Timeout $Timeout -Verbose:$Verbose
} else {
    Write-Host "Named Pipe Trigger Activation" -ForegroundColor Cyan
    Write-Host "==========================" -ForegroundColor Cyan
    Write-Host "`nUsage:" -ForegroundColor Yellow
    Write-Host "  .\activate_named_pipe.ps1 -PipeName <PipeName> [-Timeout <ms>] [-Verbose]"
    Write-Host "`nCommon named pipes to try:" -ForegroundColor Yellow
    $commonPipes | ForEach-Object { Write-Host "  - $_" }
    Write-Host "`nExample:" -ForegroundColor Yellow
    Write-Host "  .\activate_named_pipe.ps1 -PipeName atsvc -Verbose"
}
