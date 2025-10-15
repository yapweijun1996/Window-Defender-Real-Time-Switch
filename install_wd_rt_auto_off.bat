@echo off
setlocal EnableExtensions
REM install_wd_rt_auto_off.bat  [/q]  -> /q = quiet (no pause)

:: ---- settings ----
set "TASKNAME=WD-RT-AutoOff@Startup"
set "LOG=%ProgramData%\wd-rt-toggle.log"
set "DELAY_SECS=20"
set "QUIET="

if /i "%~1"=="/q" set "QUIET=1"

:: ---- robust admin check (works even if 'Server' service is stopped) ----
fltmc >nul 2>&1
if errorlevel 1 (
  echo [ERR] Please run this as Administrator.
  if not defined QUIET pause
  goto :END
)

echo.
echo === Create startup task to disable Defender Real-time protection ===
echo Task Name : %TASKNAME%
echo Log File  : %LOG%
echo Delay (s) : %DELAY_SECS%
echo.

:: ---- PowerShell payload (delay -> disable RT -> log) ----
set "PS_CMD=Start-Sleep -Seconds %DELAY_SECS%; "
set "PS_CMD=%PS_CMD% Start-Service WinDefend -ErrorAction SilentlyContinue; "
set "PS_CMD=%PS_CMD% Set-MpPreference -DisableRealtimeMonitoring $true; "
set "PS_CMD=%PS_CMD% $ok = (Get-MpComputerStatus).RealTimeProtectionEnabled -eq $false; "
set "PS_CMD=%PS_CMD% '['+(Get-Date -Format o)+'] AutoOff result: '+$ok | Out-File -FilePath '%LOG%' -Append -Encoding utf8"

:: ---- create (or replace) task ----
echo [*] Creating task (SYSTEM, Highest, At Startup) ...
schtasks /Create ^
  /TN "%TASKNAME%" ^
  /SC ONSTART ^
  /RU "SYSTEM" ^
  /RL HIGHEST ^
  /TR "powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -Command \"%PS_CMD%\"" ^
  /F

set "RC=%ERRORLEVEL%"
if not %RC%==0 (
  echo [FAIL] schtasks /Create failed (errorlevel=%RC%).
  echo        Common causes:
  echo        - Tamper Protection ON (blocks effect at runtime)
  echo        - Policy/GPO restrictions
  echo        - PowerShell policy issues
  goto :END
)

:: ---- show key task details ----
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

:END
if not defined QUIET (
  echo.
  echo Press any key to exit.
  pause >nul
)
