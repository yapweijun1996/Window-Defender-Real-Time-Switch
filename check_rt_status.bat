@echo off
echo [*] Checking Windows Defender Real-Time Protection status...
powershell -NoProfile -Command "(Get-MpComputerStatus).RealTimeProtectionEnabled"
echo.
echo Press any key to exit.
pause >nul
