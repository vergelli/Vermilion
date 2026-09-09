@echo off
setlocal
cd /d "%~dp0.."
python -m robot --outputdir qa\robot\output qa\robot\gate.robot
set "RC=%ERRORLEVEL%"
if "%1"=="--open" start "" "qa\robot\output\report.html"
exit /b %RC%
