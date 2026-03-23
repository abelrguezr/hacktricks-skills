@echo off
REM Disable WDigest - SECURITY HARDENING
REM Run as Administrator

echo Disabling WDigest credential storage...
echo.

REM Set UseLogonCredential to 0
reg add HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest /v UseLogonCredential /t REG_DWORD /d 0 /f
if %errorlevel% neq 0 (
    echo ERROR: Failed to set UseLogonCredential
    exit /b 1
)

REM Set Negotiate to 0
reg add HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest /v Negotiate /t REG_DWORD /d 0 /f
if %errorlevel% neq 0 (
    echo ERROR: Failed to set Negotiate
    exit /b 1
)

echo.
echo WDigest has been disabled.
echo Plain text passwords will no longer be stored in LSASS memory.
echo.
echo IMPORTANT: A system reboot is required for changes to take full effect.
echo.
