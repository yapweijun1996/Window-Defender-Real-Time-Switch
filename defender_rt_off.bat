@echo off
:: Run as admin
net session >nul 2>&1 || (echo Please run this as Administrator.&pause&exit /b 1)

:: If Tamper Protection is on, this will fail with AccessDenied
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue;" ^
  "$rt=(Get-MpComputerStatus).RealTimeProtectionEnabled;" ^
  "if($rt -eq $false){Write-Host '[OK] Real-time protection is OFF.'}else{Write-Host '[FAIL] Could not turn off RT. Is Tamper Protection ON?'}"
echo.
echo Press any key to exit.
pause >nul
