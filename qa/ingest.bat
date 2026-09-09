@echo off
setlocal
cd /d "%~dp0.."
python qa\ingest.py %*
exit /b %ERRORLEVEL%
