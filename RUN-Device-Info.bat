@echo off
:: CNS IT - Device Info Collector
:: Right-click this file -> Run as Administrator
cd /d "%~dp0"
powershell -NoExit -ExecutionPolicy Bypass -File "%~dp0get-device-info-win.ps1"
