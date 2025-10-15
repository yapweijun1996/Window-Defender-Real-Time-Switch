@echo off
:: Run as admin
net session >nul 2>&1 || (echo Please run this as Administrator.&pause&exit /b 1)

powershell -NoProfile -ExecutionPolicy Bypass ^
  -Command "Start-Service WinDefend -ErrorAction SilentlyContinue; Set-MpPreference -DisableRealtimeMonitoring $false; (Get-MpComputerStatus).RealTimeProtectionEnabled | Out-Host"
