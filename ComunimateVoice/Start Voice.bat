@echo off
title Comunimate Voice
cd /d "%~dp0"
if not exist ".venv\Scripts\python.exe" (
  echo Run setup.ps1 first.
  pause
  exit /b 1
)
".venv\Scripts\python.exe" comunimate_voice.py %*
pause
