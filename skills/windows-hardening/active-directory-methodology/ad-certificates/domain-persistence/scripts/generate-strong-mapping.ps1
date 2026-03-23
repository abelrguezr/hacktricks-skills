# AD CS Strong Mapping Generator
# Generates strong certificate mappings for Full Enforcement environments
# Post-KB5014754 compatibility

param(
    [Parameter(Mandatory=$true)]
    [string]$TargetUser,
    
    [Parameter(Mandatory=$true)]
    [string]$IssuerDN,  # e.g., "DC=corp,DC=local,CN=CORP-DC-CA"
    
    [Parameter(Mandatory=$true)]
    [string]$SerialNumber,  # Certificate serial number (hex)
    
    [switch]$RemoveMapping
)

function ConvertTo-ReversedSerial {
    param([string]$Serial)
    
    # Convert serial to reversed byte order
    $bytes = [byte[]]::new($Serial.Length / 2)
    for ($i = 0; $i -lt $Serial.Length; $i += 2) {
        $bytes[$i / 2] = [Convert]::ToByte($Serial.Substring($i, 2), 16)
    }
    
    # Reverse the byte array
    [Array]::Reverse($bytes)
    
    # Convert back to hex string
    $reversed = -join ($bytes | ForEach-Object { $_.ToString('X2') })
    return $reversed
}

Write-Host "=== AD CS Strong Mapping Generator ===" -ForegroundColor Cyan
Write-Host ""

# Validate inputs
if (-not (Test-Path "AD:\$TargetUser")) {
    Write-Host "Error: User '$TargetUser' not found in Active Directory" -ForegroundColor Red
    exit 1
}

# Generate reversed serial
$SerialReversed = ConvertTo-ReversedSerial -Serial $SerialNumber

# Create strong mapping string
$Mapping = "X509:<I>$IssuerDN<SR>$SerialReversed"

Write-Host "Target User: $TargetUser" -ForegroundColor Green
Write-Host "Issuer DN: $IssuerDN" -ForegroundColor Green
Write-Host "Serial Number: $SerialNumber" -ForegroundColor Green
Write-Host "Reversed Serial: $SerialReversed" -ForegroundColor Green
Write-Host "Mapping String: $Mapping" -ForegroundColor Green
Write-Host ""

if ($RemoveMapping) {
    Write-Host "Removing mapping from user..." -ForegroundColor Yellow
    try {
        Set-ADUser -Identity $TargetUser -Remove @{altSecurityIdentities=$Mapping}
        Write-Host "Mapping removed successfully" -ForegroundColor Green
    } catch {
        Write-Host "Error removing mapping: $_" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Adding mapping to user..." -ForegroundColor Yellow
    try {
        Set-ADUser -Identity $TargetUser -Add @{altSecurityIdentities=$Mapping}
        Write-Host "Mapping added successfully" -ForegroundColor Green
        
        # Verify the mapping was added
        $user = Get-ADUser -Identity $TargetUser -Properties altSecurityIdentities
        if ($user.altSecurityIdentities -contains $Mapping) {
            Write-Host "Verification: Mapping confirmed in user object" -ForegroundColor Green
        } else {
            Write-Host "Warning: Mapping may not have been added correctly" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Error adding mapping: $_" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "=== Notes ===" -ForegroundColor Cyan
Write-Host "- This mapping works under Full Enforcement (post-KB5014754)" -ForegroundColor White
Write-Host "- The certificate must be valid and not expired" -ForegroundColor White
Write-Host "- Consider using SID embedding instead to avoid altSecurityIdentities monitoring" -ForegroundColor White
