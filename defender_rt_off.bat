@echo off
:: Run as admin
net session >nul 2>&1 || (echo Please run this as Administrator.&pause&exit /b 1)

:: If Tamper Protection is on, this will fail with AccessDenied
powershell -NoProfile -ExecutionPolicy Bypass ^
  -Command "Start-Service WinDefend -ErrorAction SilentlyContinue; Set-MpPreference -DisableRealtimeMonitoring $true; (Get-MpComputerStatus).RealTimeProtectionEnabled | Out-Host"
