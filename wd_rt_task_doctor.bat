@echo off
setlocal EnableExtensions

:: ==== settings ====
set "TASKNAME=WD-RT-AutoOff@Startup"
set "LOG=%ProgramData%\wd-rt-toggle.log"
set "DELAY_SECS=20"

:: ==== robust admin check ====
fltmc >nul 2>&1 || (echo [ERR] Please run this as Administrator.&goto :END)

echo.
echo === WD-RT Task Doctor ===
echo Task  : %TASKNAME%
echo Delay : %DELAY_SECS%s
echo Log   : %LOG%
echo.

:: ==== 1) Check if task exists (schtasks + PowerShell) ====
set "FOUND_SCHTASKS="
for /f "tokens=1,* delims=:" %%A in ('schtasks /Query /TN "%TASKNAME%" /FO LIST 2^>nul ^| findstr /I /C:"TaskName:"') do set "FOUND_SCHTASKS=1"

powershell -NoProfile -Command "Get-ScheduledTask -TaskName '%TASKNAME%' -ErrorAction SilentlyContinue | Out-Null; if($?){exit 0}else{exit 1}"
if %ERRORLEVEL%==0 (
  set "FOUND_PS=1"
) else (
  set "FOUND_PS="
)

if defined FOUND_SCHTASKS if defined FOUND_PS (
  echo [OK] Task already exists.
  goto :SHOW_DETAILS
)

echo [INFO] Task missing or partial. Recreating...

:: ==== 2) Delete any stray task ====
schtasks /Delete /TN "%TASKNAME%" /F >nul 2>&1

:: ==== 3) Create task via PowerShell Register-ScheduledTask (most reliable) ====
set "PS_CMD_PAYLOAD=Start-Sleep -Seconds %DELAY_SECS%; Start-Service WinDefend -ErrorAction SilentlyContinue; Set-MpPreference -DisableRealtimeMonitoring $true; $ok=((Get-MpComputerStatus).RealTimeProtectionEnabled -eq $false); '['+(Get-Date -Format o)+'] AutoOff result: '+$ok | Out-File -FilePath '%LOG%' -Append -Encoding utf8"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$cmd = { %PS_CMD_PAYLOAD% };" ^
  "$act  = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -Command & $cmd' ;" ^
  "$trig = New-ScheduledTaskTrigger -AtStartup ;" ^
  "$prin = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -RunLevel Highest ;" ^
  "$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries;" ^
  "$task = New-ScheduledTask -Action $act -Trigger $trig -Principal $prin -Settings $settings;" ^
  "Register-ScheduledTask -TaskName '%TASKNAME%' -InputObject $task -Force | Out-Null"

if errorlevel 1 (
  echo [FAIL] Register-ScheduledTask failed. Possible causes:
  echo        - Tamper Protection/Policy won't block creation, but can block effect
  echo        - PowerShell policy/module issues
  echo Try: Windows PowerShell (x86/x64) run as Admin.
  goto :END
)

echo [OK] Task created.

:SHOW_DETAILS
echo.
echo --- schtasks view ---
schtasks /Query /TN "%TASKNAME%" /V /FO LIST 2>nul | findstr /I "TaskName Triggers Run Level Run As User Last Run Time Last Result"
echo.
echo --- PowerShell view ---
powershell -NoProfile -Command "Get-ScheduledTask -TaskName '%TASKNAME%' | Select-Object TaskName,State,Triggers,Principal | Format-List"

:: ==== 4) Functional test ====
echo.
echo === Functional test: run task now ===
schtasks /Run /TN "%TASKNAME%" >nul 2>&1
if errorlevel 1 (
  echo [WARN] Could not start task immediately (it will still run at next boot).
  goto :DONE
)
echo [*] Waiting %DELAY_SECS%s for payload...
timeout /t %DELAY_SECS% /nobreak >nul

echo [*] Checking Defender RT state...
powershell -NoProfile -Command "(Get-MpComputerStatus).RealTimeProtectionEnabled" | find /i "False" >nul && (
  echo [OK] Real-time protection is OFF after test run.
) || (
  echo [FAIL] Real-time protection is still ON.
  echo        Troubleshooting:
  echo        1. Turn OFF Tamper Protection in Windows Security and re-run this doctor.
  echo        2. Check if corporate Group Policy (GPO/MDM) is re-enabling it.
  echo        3. Increase the DELAY_SECS value at the top of this script and re-run.
)

:DONE
echo.
echo Done. Log: %LOG%

:END
echo.
echo Press any key to exit.
pause >nul
