@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-WhisperSeamless.ps1"
if errorlevel 1 (
  echo.
  echo Installation failed. Review the messages above.
  pause
)
