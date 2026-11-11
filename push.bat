@echo off
title Push ShieldAuth to GitHub
echo ================================================================
echo   Pushing ShieldAuth to GitHub (sharmashivprasad2006-design)
echo ================================================================
echo.
cd /d "%~dp0"
echo Running: git push -u origin main
echo.
git push -u origin main
echo.
echo ================================================================
echo Execution complete.
echo ================================================================
pause
