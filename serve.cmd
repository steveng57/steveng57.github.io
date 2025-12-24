@echo off
REM Legacy batch file - now calls the enhanced PowerShell script
REM Use serve.ps1 directly for more options
powershell.exe -ExecutionPolicy Bypass -File "serve.ps1" %*