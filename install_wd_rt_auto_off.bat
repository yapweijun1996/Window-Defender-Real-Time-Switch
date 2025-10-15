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

:: ---- create task via PowerShell and exit from there to avoid cmd parsing bugs ----
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference = 'Stop';" ^
  "$quiet = if ('%QUIET%' -eq '1') { $true } else { $false };" ^
  "try {" ^
  "  $Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -WindowStyle Hidden -Command ""Start-Sleep -Seconds %DELAY_SECS%; Set-MpPreference -DisableRealtimeMonitoring $true; $ok = !([Security.Principal.WindowsIdentity]::GetCurrent().IsSystem); ''''$(Get-Date -f o) AutoOff Result: $ok'''' | Out-File -FilePath ''%LOG%'' -Append -Encoding utf8""';" ^
  "  $Trigger = New-ScheduledTaskTrigger -AtStartup;" ^
  "  $Principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -RunLevel Highest;" ^
  "  $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries;" ^
  "  Register-ScheduledTask -TaskName '%TASKNAME%' -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force -ErrorAction Stop | Out-Null;" ^
  "  Write-Host '[OK] Scheduled task installed successfully.';" ^
  "  if (-not $quiet) { Write-Host ''; Write-Host 'Press any key to exit.'; [System.Console]::ReadKey() | Out-Null; }" ^
  "  exit 0;" ^
  "} catch {" ^
  "  Write-Host ('[FAIL] Failed to create scheduled task: ' + $_.Exception.Message) -ForegroundColor Red;" ^
  "  Write-Host '        Common causes:';" ^
  "  Write-Host '        - Tamper Protection is ON in Windows Security.'; " ^
  "  Write-Host '        - Organizational policies (GPO/MDM) are restricting task creation.';" ^
  "  if (-not $quiet) { Write-Host ''; Write-Host 'Press any key to exit.'; [System.Console]::ReadKey() | Out-Null; }" ^
  "  exit 1;" ^
  "}"
