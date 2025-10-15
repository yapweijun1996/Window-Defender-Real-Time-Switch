@echo off
:: Run as admin
net session >nul 2>&1 || (echo Please run this as Administrator.&pause&exit /b 1)

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue;" ^
  "$rt=(Get-MpComputerStatus).RealTimeProtectionEnabled;" ^
  "if($rt -eq $true){Write-Host '[OK] Real-time protection is ON.'}else{Write-Host '[FAIL] Could not turn on RT.'}"
echo.
echo Press any key to exit.
pause >nul
