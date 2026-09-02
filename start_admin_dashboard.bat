@echo off
title VIT Bus Tracker - Admin Control Center
echo =========================================================
echo    Starting VIT Bus Tracker Admin Web Dashboard
echo =========================================================
echo.
echo Opening dashboard at http://localhost:8080/
start http://localhost:8080/
echo.
echo Running server (Press Ctrl+C to stop)...
powershell -ExecutionPolicy Bypass -File "%~dp0admin_dashboard\serve.ps1"
pause
