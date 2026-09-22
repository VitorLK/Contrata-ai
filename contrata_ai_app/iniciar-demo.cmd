@echo off
title Contrata Ai - Demonstracao remota
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0iniciar-demo.ps1"
if errorlevel 1 (
  echo.
  echo A demonstracao nao foi iniciada. Consulte a mensagem acima.
  pause
)
