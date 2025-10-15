@echo off
:: Run as admin
net session >nul 2>&1 || (echo [ERR] Please run this as Administrator.&pause&exit /b 1)

set "TASKNAME=WD-RT-AutoOff@Startup"
echo [*] Removing scheduled task "%TASKNAME%"...
schtasks /Delete /TN "%TASKNAME%" /F
if errorlevel 1 (echo [WARN] Task not found or could not be removed.) else (echo [OK] Task removed.)
echo.
echo Press any key to exit.
pause >nul
