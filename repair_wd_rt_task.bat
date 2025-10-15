@echo off
setlocal EnableExtensions

:: Robust admin check
fltmc >nul 2>&1 || (echo [ERR] Please run this as Administrator.&pause&exit /b 1)

set "TASKNAME=WD-RT-AutoOff@Startup"
set "LOG=%ProgramData%\wd-rt-toggle.log"
set "DELAY_SECS=20"

echo.
echo === Repairing scheduled task "%TASKNAME%" (Boot trigger, SYSTEM, Highest) ===

:: Remove any old/broken task
schtasks /Delete /TN "%TASKNAME%" /F >nul 2>&1

:: Build the PowerShell payload
set "PS_CMD=Start-Sleep -Seconds %DELAY_SECS%; "
set "PS_CMD=%PS_CMD% Start-Service WinDefend -ErrorAction SilentlyContinue; "
set "PS_CMD=%PS_CMD% Set-MpPreference -DisableRealtimeMonitoring $true; "
set "PS_CMD=%PS_CMD% $ok=(Get-MpComputerStatus).RealTimeProtectionEnabled -eq $false; "
set "PS_CMD=%PS_CMD% '['+(Get-Date -Format o)+'] AutoOff result: '+$ok | Out-File -FilePath '%LOG%' -Append -Encoding utf8"

:: Recreate with a true Boot trigger
schtasks /Create ^
  /TN "%TASKNAME%" ^
  /SC ONSTART ^
  /RU "SYSTEM" ^
  /RL HIGHEST ^
  /TR "powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -Command \"%PS_CMD%\"" ^
  /F

if errorlevel 1 (
  echo [FAIL] Could not (re)create the task. Check policies / Tamper Protection.
  pause
  exit /b 2
)

echo.
echo --- Task details ---
for /f "tokens=1,* delims=:" %%A in ('
  schtasks /Query /TN "%TASKNAME%" /V /FO LIST ^| findstr /I "TaskName Run As User Run Level Triggers"
') do @echo %%A:%%B

:: Functional test now
echo.
echo === Functional test: run the task once now ===
schtasks /Run /TN "%TASKNAME%" >nul 2>&1
if errorlevel 1 (
  echo [WARN] Could not start now. It will still run next boot.
) else (
  echo [*] Waiting %DELAY_SECS%s for payload to finish...
  timeout /t %DELAY_SECS% /nobreak >nul
  echo [*] Checking Defender RT state...
  powershell -NoProfile -Command "(Get-MpComputerStatus).RealTimeProtectionEnabled" | find /i "False" >nul && (
    echo [OK] Real-time protection is OFF after test run.
  ) || (
    echo [WARN] RT appears ON. Likely Tamper Protection or GPO/MDM. Try turning TP OFF or increasing DELAY_SECS.
  )
)

echo.
echo [DONE] Repaired. Log file: %LOG%
pause
