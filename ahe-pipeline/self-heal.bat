@echo off
setlocal enabledelayedexpansion
title AHE Hub
set S=C:\Users\Administrator\Scripts
set PS=powershell -NoProfile -ExecutionPolicy Bypass -File

:menu
cls
echo === AHE Hub ===
echo.
echo  1. Quick Status
echo  2. Run Benchmark
echo  3. Self-Improve Pipeline
echo  4. Link CE Skills
echo  5. Update Plugins + Models
echo  6. Full System Check
echo  7. Sync to Obsidian
echo  8. Token Savings
echo  9. Cleanup Disk
echo 10. Security Audit
echo 11. Integrity Check
echo 12. System Check
echo 13. Optimize Windows Apps
echo 14. Game Mode
echo 15. Dev Mode
echo  0. Exit
echo.
set /p C="Choice: "

if "%C%"=="1" goto :status
if "%C%"=="2" goto :benchmark
if "%C%"=="3" goto :pipeline
if "%C%"=="4" goto :evolve
if "%C%"=="5" goto :update
if "%C%"=="6" %PS% "%S%\tools.ps1" check
if "%C%"=="7" %PS% "%S%\tools.ps1" sync
if "%C%"=="8" %PS% "%S%\tools.ps1" tokens
if "%C%"=="9" %PS% "%S%\tools.ps1" cleanup
if "%C%"=="10" %PS% "%S%\tools.ps1" audit
if "%C%"=="11" %PS% "%S%\archive\integrity-check.ps1" -Quick
if "%C%"=="12" %PS% "%S%\tools.ps1" check
if "%C%"=="13" %PS% "%S%\tools.ps1" optimize
if "%C%"=="14" %PS% "%S%\tools.ps1" game-mode
if "%C%"=="15" %PS% "%S%\tools.ps1" dev-mode
if "%C%"=="0" exit /b
goto :end

:status
cls
echo === Quick Status ===
%PS% "%S%\tools.ps1" status
goto :end

:benchmark
cls
echo === System Benchmark ===
echo Runs 28 tests, shows score.
%PS% "%S%\benchmark.ps1" -Runs 1
goto :end

:pipeline
cls
echo === Self-Improve Pipeline ===
echo Backup - Verify - Discover - Benchmark - Evolve - Sync
%PS% "%S%\pipeline.ps1"
goto :end

:evolve
cls
echo === Link CE Skills ===
%PS% "%S%\pipeline.ps1" -Phase link-ce-skills
goto :end

:update
cls
echo === Update Everything ===
%PS% "%S%\tools.ps1" update
%PS% "%S%\tools.ps1" mcpmodel
goto :end

:end
echo.
echo Press any key to return to menu...
pause >nul
goto menu
