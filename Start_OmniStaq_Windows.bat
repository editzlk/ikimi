@echo off
rem OmniStaq for Windows - double-click this file. No hosting / internet needed.
cd /d "%~dp0"
start "" powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0server.ps1"
timeout /t 2 /nobreak >nul
set URL=http://127.0.0.1:9101/
set C1=C:\Program Files\Google\Chrome\Application\chrome.exe
set C2=C:\Program Files (x86)\Google\Chrome\Application\chrome.exe
set C3=%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe
if exist "%C1%" start "" "%C1%" --app=%URL% & if exist "%C1%" exit /b
if exist "%C2%" start "" "%C2%" --app=%URL% & if exist "%C2%" exit /b
if exist "%C3%" start "" "%C3%" --app=%URL% & if exist "%C3%" exit /b
start "" msedge --app=%URL%
