@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0build-cytoid-player.ps1" %*
if errorlevel 1 (
    echo Build failed.
    pause
    exit /b 1
)
echo Build succeeded.
pause
