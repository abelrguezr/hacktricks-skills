@echo off
REM Enable LSA PPL Protection - SECURITY HARDENING
REM Run as Administrator

echo Enabling LSA PPL protection...
echo.

REM Set RunAsPPL to 1
reg add HKLM\SYSTEM\CurrentControlSet\Control\LSA /v RunAsPPL /t REG_DWORD /d 1 /f
if %errorlevel% neq 0 (
    echo ERROR: Failed to set RunAsPPL
    exit /b 1
)

echo.
echo LSA PPL has been enabled.
echo LSASS will run as a Protected Process Light after reboot.
echo.
echo IMPORTANT: A system reboot is required for changes to take effect.
echo Note: PPL may require Secure Boot to be enabled in UEFI settings.
echo.
