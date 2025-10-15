@echo off
setlocal EnableExtensions
REM verify_wd_rt_auto_off.bat  [waitSeconds] [/q]

REM -------- settings --------
set "TASKNAME=WD-RT-AutoOff@Startup"
set "WAIT_SECS=10"
set "QUIET="

:parse_args
if /i "%~1"=="/q" (
  set "QUIET=1"
  shift /1
  goto :parse_args
)
if not "%~1"=="" (
  set "WAIT_SECS=%~1"
)

REM -------- admin check --------
net session >nul 2>&1
if errorlevel 1 (
  echo [ERR] Please run this as Administrator.
  if not defined QUIET pause
  set "RC=3"
  goto :END
)

echo.
echo === Verifying scheduled task "%TASKNAME%" ===
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$tn='%TASKNAME%';" ^
  "function ok($m){Write-Host ('[OK]  ' + $m)}" ^
  "function warn($m){Write-Host ('[WARN] ' + $m)}" ^
  "$task=Get-ScheduledTask -TaskName $tn -ErrorAction SilentlyContinue;" ^
  "if(-not $task){Write-Host '[FAIL] Task not found. Run install_wd_rt_auto_off.bat first.'; exit 1}" ^
  "ok('Task exists');" ^
  "$isSystem = ($task.Principal.UserId -eq 'SYSTEM'); if($isSystem){ ok('Runs as SYSTEM') } else { warn('Runs as ' + $task.Principal.UserId + ' (expected SYSTEM)') }" ^
  "$isHighest = ($task.Principal.RunLevel -eq 'Highest'); if($isHighest){ ok('Highest privileges') } else { warn('Run level is not Highest') }" ^
  "$hasBoot = $false; foreach($t in $task.Triggers){ if($t.TriggerType -eq 'Boot'){ $hasBoot=$true } }" ^
  "if($hasBoot){ ok('Startup (Boot) trigger present') } else { warn('No Startup trigger found') }" ^
  "Write-Host ('LastRunTime     : ' + $task.LastRunTime); Write-Host ('LastTaskResult : ' + $task.LastTaskResult);" ^
  "" ^
  "Write-Host ''; Write-Host '=== Functional test: run the task now and check Defender RT ===';" ^
  "try{ Start-ScheduledTask -TaskName $tn -ErrorAction Stop } catch{ warn('Could not start task: ' + $_.Exception.Message) }" ^
  "Start-Sleep -Seconds %WAIT_SECS%;" ^
  "$rt = $null; $err = $null; try{ $rt=(Get-MpComputerStatus).RealTimeProtectionEnabled } catch { $err=$_.Exception.Message }" ^
  "if($err){ warn('Could not read Defender status: ' + $err); exit 2 }" ^
  "Write-Host ('RealTimeProtectionEnabled = ' + $rt);" ^
  "if($rt -eq $false){ ok('Real-time protection is OFF after task run'); exit 0 } else { warn('Real-time protection is still ON — Tamper Protection or policy may be re-enabling it.'); exit 2 }"

set "RC=%ERRORLEVEL%"

:END
echo.
if defined RC (
  if %RC%==0  echo RESULT: PASS
  if %RC%==1  echo RESULT: FAIL (Task missing or misconfigured)
  if %RC%==2  echo RESULT: WARN (Task ran but RT stayed ON — check Tamper Protection / GPO)
  if %RC%==3  echo RESULT: FAIL (Not admin)
)

if not defined QUIET (
  echo.
  echo Press any key to exit.
  pause >nul
)
