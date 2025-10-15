@echo off
setlocal EnableExtensions

:: install_wd_rt_auto_off.bat  [/q]  - /q = quiet (no pause)

:: ---- settings ----
set "TASKNAME=WD-RT-AutoOff@Startup"
set "LOG=%ProgramData%\wd-rt-toggle.log"
set "DELAY_SECS=20"
set "QUIET="
if /i "%~1" equ "/q" set "QUIET=1"

:: ---- admin check ----
fltmc >nul 2>&1 || (
  echo [ERR] Please run this as Administrator.
  if not defined QUIET pause
  exit /b 1
)

echo.
echo === Installing/Updating scheduled task to disable Defender Real-time protection ===
echo Task Name: %TASKNAME%
echo.

:: ---- create task via PowerShell (more reliable than schtasks) ----
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference = 'Stop';" ^
  "try {" ^
  "  $Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -WindowStyle Hidden -Command ""Start-Sleep -Seconds %DELAY_SECS%; Set-MpPreference -DisableRealtimeMonitoring $true; $ok = !([Security.Principal.WindowsIdentity]::GetCurrent().IsSystem); ''''$(Get-Date -f o) AutoOff Result: $ok'''' | Out-File -FilePath ''%LOG%'' -Append -Encoding utf8""';" ^
  "  $Trigger = New-ScheduledTaskTrigger -AtStartup;" ^
  "  $Principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -RunLevel Highest;" ^
  "  $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries;" ^
  "  Register-ScheduledTask -TaskName '%TASKNAME%' -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force -ErrorAction Stop | Out-Null;" ^
  "  Write-Host '[OK] Scheduled task installed successfully.';" ^
  "  exit 0;" ^
  "} catch {" ^
  "  Write-Host ('[FAIL] Failed to create scheduled task: ' + $_.Exception.Message) -ForegroundColor Red;" ^
  "  exit 1;" ^
  "}"
  
set "RC=%ERRORLEVEL%"

if not %RC%==0 (
    echo.
    echo        Common causes:
    echo        - Tamper Protection is ON in Windows Security.
    echo        - Organizational policies (GPO/MDM) are restricting task creation.
)

if not defined QUIET (
  echo.
  echo Press any key to exit.
  pause >nul
)
exit /b %RC%
