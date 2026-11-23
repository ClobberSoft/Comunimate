@echo off
title Comunimate Voice - button test
cd /d "%~dp0"
echo Press buttons on your controller. The mic button should show as "15 (mic)".
echo Close this window when done.
echo.
".venv\Scripts\python.exe" comunimate_voice.py --buttons
pause
