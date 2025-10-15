@echo off
set "TASKNAME=WD-RT-AutoOff@Startup"
schtasks /Delete /TN "%TASKNAME%" /F
if errorlevel 1 (echo [WARN] Task not found or could not be removed.) else (echo [OK] Task removed.)
pause
