@echo off
setlocal EnableExtensions
REM install_wd_rt_auto_off.bat  [/q]  -> /q = quiet (no pause)

:: ---- settings ----
set "TASKNAME=WD-RT-AutoOff@Startup"
set "LOG=%ProgramData%\wd-rt-toggle.log"
set "DELAY_SECS=20"
set "QUIET="

if /i "%~1"=="/q" set "QUIET=1"

:: ---- admin check ----
net session >nul 2>&1
if errorlevel 1 (
  echo [ERR] Please run this as Administrator.
  if not defined QUIET pause
  exit /b 1
)

echo.
echo === Create startup task to disable Defender Real-time protection ===

:: ---- PowerShell payload (delay -> disable RT -> log) ----
set "PS_CMD=Start-Sleep -Seconds %DELAY_SECS%; "
set "PS_CMD=%PS_CMD% Start-Service WinDefend -ErrorAction SilentlyContinue; "
set "PS_CMD=%PS_CMD% Set-MpPreference -DisableRealtimeMonitoring $true; "
set "PS_CMD=%PS_CMD% $ok = (Get-MpComputerStatus).RealTimeProtectionEnabled -eq $false; "
set "PS_CMD=%PS_CMD% '['+(Get-Date -Format o)+'] AutoOff result: '+$ok | Out-File -FilePath '%LOG%' -Append -Encoding utf8"

:: ---- create (or replace) task ----
echo [*] Creating task "%TASKNAME%" (SYSTEM, highest, at startup) ...
schtasks /Create ^
  /TN "%TASKNAME%" ^
  /SC ONSTART ^
  /RU "SYSTEM" ^
  /RL HIGHEST ^
  /TR "powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -Command \"%PS_CMD%\"" ^
  /F

if errorlevel 1 (
  echo [FAIL] schtasks /Create failed. Possible causes:
  echo        - Tamper Protection ON (blocks Set-MpPreference effects at runtime)
  echo        - Policy/GPO restrictions
  echo        - PowerShell execution policy restrictions
  if not defined QUIET pause
  exit /b 2
)

:: ---- confirm task exists ----
for /f "tokens=1,* delims=:" %%A in ('schtasks /Query /TN "%TASKNAME%" /V /FO LIST ^| findstr /I "TaskName Run As User Run Level Triggers Last Run Time Last Result"') do (
  echo %%A:%%B
)

:: ---- optional: quick functional test now ----
echo.
echo === Functional test: run the task once now ===
schtasks /Run /TN "%TASKNAME%" >nul 2>&1
if errorlevel 1 (
  echo [WARN] Could not start the task immediately (it will still run at next boot).
) else (
  echo [*] Waiting %DELAY_SECS%s for the task payload to finish...
  timeout /t %DELAY_SECS% /nobreak >nul
  echo [*] Checking Defender RT state...
  powershell -NoProfile -Command "(Get-MpComputerStatus).RealTimeProtectionEnabled" | find /i "False" >nul && (
    echo [OK] Real-time protection is OFF after test run.
  ) || (
    echo [WARN] Real-time protection appears ON.
    echo        - Turn OFF Tamper Protection and try again
    echo        - Org GPO/MDM may be re-enabling it
    echo        - Increase DELAY_SECS and reinstall task
  )
)

echo.
echo [DONE] Task "%TASKNAME%" installed. A log will be written to:
echo        %LOG%
if not defined QUIET pause
exit /b 0
