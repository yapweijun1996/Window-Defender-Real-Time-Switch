@echo off
powershell -NoProfile -Command "(Get-MpComputerStatus).RealTimeProtectionEnabled"
pause
