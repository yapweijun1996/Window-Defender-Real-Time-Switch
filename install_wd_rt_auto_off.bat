@echo off
setlocal EnableExtensions

:: install_wd_rt_auto_off.bat [/q] - /q = quiet (no pause)

:: ---- settings ----
set "TASKNAME=WD-RT-AutoOff@Startup"
set "LOG=%ProgramData%\wd-rt-toggle.log"
set "DELAY_SECS=20"
set "WAIT_SECS=5"
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

:: ---- create temporary PowerShell script ----
set "PS_SCRIPT=%TEMP%\install_wd_task.ps1"
del "%PS_SCRIPT%" 2>nul

echo $ErrorActionPreference = 'Stop' > "%PS_SCRIPT%"
echo $quiet = if ('%QUIET%' -eq '1') { $true } else { $false } >> "%PS_SCRIPT%"
echo $tn = '%TASKNAME%' >> "%PS_SCRIPT%"
echo function ok($m){Write-Host ('[OK]  ' + $m) -ForegroundColor Green} >> "%PS_SCRIPT%"
echo function warn($m){Write-Host ('[WARN] ' + $m) -ForegroundColor Yellow} >> "%PS_SCRIPT%"
echo function fail($m){Write-Host ('[FAIL] ' + $m) -ForegroundColor Red} >> "%PS_SCRIPT%"
echo try { >> "%PS_SCRIPT%"
echo   $Command = 'Start-Sleep -Seconds %DELAY_SECS%; Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue; $isSystem = [Security.Principal.WindowsIdentity]::GetCurrent().IsSystem; $timestamp = Get-Date -Format o; $rt = $null; $rtError = $null; try { $rt = (Get-MpComputerStatus).RealTimeProtectionEnabled } catch { $rtError = $_.Exception.Message }; $logLine = if ($rtError) { ''{0} AutoOff Result: IsSystem={1} RTError={2}'' -f $timestamp, $isSystem, $rtError } else { ''{0} AutoOff Result: IsSystem={1} RealTimeProtectionEnabled={2}'' -f $timestamp, $isSystem, $rt }; $logLine ^| Out-File -FilePath ''%LOG%'' -Append -Encoding utf8' >> "%PS_SCRIPT%"
echo   $Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -Command `"$($Command)`"" >> "%PS_SCRIPT%"
echo   $Trigger = New-ScheduledTaskTrigger -AtStartup >> "%PS_SCRIPT%"
echo   $Principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -RunLevel Highest >> "%PS_SCRIPT%"
echo   $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries >> "%PS_SCRIPT%"
echo   Register-ScheduledTask -TaskName $tn -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force -ErrorAction Stop ^| Out-Null >> "%PS_SCRIPT%"
echo   ok('Scheduled task installed successfully.') >> "%PS_SCRIPT%"
echo } catch { >> "%PS_SCRIPT%"
echo   fail('Failed to create scheduled task: ' + $_.Exception.Message) >> "%PS_SCRIPT%"
echo   warn('       Common causes:') >> "%PS_SCRIPT%"
echo   warn('       - Tamper Protection is ON in Windows Security.') >> "%PS_SCRIPT%"
echo   warn('       - Organizational policies (GPO/MDM) are restricting task creation.') >> "%PS_SCRIPT%"
echo   if (-not $quiet) { Write-Host ''; Write-Host 'Press any key to exit.'; [System.Console]::ReadKey() ^| Out-Null } >> "%PS_SCRIPT%"
echo   exit 1 >> "%PS_SCRIPT%"
echo } >> "%PS_SCRIPT%"
echo. >> "%PS_SCRIPT%"
echo Write-Host ''; Write-Host '=== Verifying scheduled task... ===' >> "%PS_SCRIPT%"
echo $task=Get-ScheduledTask -TaskName $tn -ErrorAction SilentlyContinue >> "%PS_SCRIPT%"
echo if(-not $task){ fail('Task not found after creation.'); exit 1 } >> "%PS_SCRIPT%"
echo ok('Task exists') >> "%PS_SCRIPT%"
echo $isSystem = ($task.Principal.UserId -eq 'SYSTEM'); if($isSystem){ ok('Runs as SYSTEM') } else { warn('Runs as ' + $task.Principal.UserId + ' (expected SYSTEM)') } >> "%PS_SCRIPT%"
echo $isHighest = ($task.Principal.RunLevel -eq 'Highest'); if($isHighest){ ok('Highest privileges') } else { warn('Run level is not Highest') } >> "%PS_SCRIPT%"
echo $triggerTypes = @(); if($task.Triggers){ $triggerTypes = $task.Triggers ^| ForEach-Object { $_.TriggerType } } >> "%PS_SCRIPT%"
echo $matchingTrigger = $triggerTypes ^| Where-Object { $_ -in @('Boot','AtStartup','Startup') } >> "%PS_SCRIPT%"
echo if($matchingTrigger){ ok('Startup trigger present') } else { >> "%PS_SCRIPT%"
echo   $typesText = '(none)'; if($triggerTypes -and $triggerTypes.Count){ $typesText = $triggerTypes -join ', ' } >> "%PS_SCRIPT%"
echo   warn('No Startup trigger found; found types: ' + $typesText) >> "%PS_SCRIPT%"
echo } >> "%PS_SCRIPT%"
echo Write-Host ''; Write-Host '=== Functional test: run the task now and check Defender RT ===' >> "%PS_SCRIPT%"
echo try{ Start-ScheduledTask -TaskName $tn -ErrorAction Stop } catch{ warn('Could not start task: ' + $_.Exception.Message) } >> "%PS_SCRIPT%"
echo Write-Host 'Waiting %WAIT_SECS% seconds for task to complete...' >> "%PS_SCRIPT%"
echo Start-Sleep -Seconds %WAIT_SECS% >> "%PS_SCRIPT%"
echo $rt = $null; $err = $null; try{ $rt=(Get-MpComputerStatus).RealTimeProtectionEnabled } catch { $err=$_.Exception.Message } >> "%PS_SCRIPT%"
echo if($err){ warn('Could not read Defender status: ' + $err); exit 2 } >> "%PS_SCRIPT%"
echo Write-Host ('RealTimeProtectionEnabled = ' + $rt) >> "%PS_SCRIPT%"
echo if($rt -eq $false){ ok('Real-time protection is OFF after task run') } else { warn('Real-time protection is still ON — Tamper Protection or policy may be re-enabling it.') } >> "%PS_SCRIPT%"
echo. >> "%PS_SCRIPT%"
echo if (-not $quiet) { Write-Host ''; Write-Host 'Press any key to exit.'; [System.Console]::ReadKey() ^| Out-Null } >> "%PS_SCRIPT%"
echo exit 0 >> "%PS_SCRIPT%"

:: ---- execute the PowerShell script ----
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%"

:: ---- cleanup ----
del "%PS_SCRIPT%" 2>nul

goto :EOF
