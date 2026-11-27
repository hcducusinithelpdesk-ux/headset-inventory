@echo off
cd /d "%~dp0"
title Headset Inventory Portal

echo ========================================================
echo   Headset Inventory Portal - Starting Local Server...
echo ========================================================
echo.

set NODE_EXE="C:\Users\HCD-ADMIN\Downloads\Flutter_Web_IT_Helpdesk_LAN_OneClick_Updated\flutter_helpdesk\runtime\node\node.exe"

if exist %NODE_EXE% (
    start "" /b %NODE_EXE% "%~dp0server.js"
) else (
    start "" "%~dp0portal\index.html"
    exit /b
)

timeout /t 2 /nobreak >nul
start http://localhost:5050/
echo Portal opened at http://localhost:5050/
