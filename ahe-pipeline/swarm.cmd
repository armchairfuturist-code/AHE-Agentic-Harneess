@echo off
REM AHE Swarm CLI — invoke multi-agent swarm with natural language
REM Usage: swarm.cmd "your goal here"
REM        swarm.cmd deep "your persistent goal here"

setlocal
set GOAL=%1
set MODE=%1

if "%1"=="" (
    echo Usage: swarm "your goal here"
    echo        swarm deep "persistent goal"
    echo        swarm custom "goal" --agents 4 --iterations 3
    exit /b 1
)

if "%1"=="deep" (
    set GOAL=%2
    echo === Deep Swarm: %GOAL% ===
    python "%USERPROFILE%\Scripts\archive\ahe-ralph-loop.py" %GOAL%
    exit /b 0
)

if "%1"=="custom" (
    set GOAL=%2
    echo === Custom Swarm: %GOAL% ===
    python "%USERPROFILE%\Scripts\archive\ahe-ralph-loop.py" --iterations %4 %GOAL%
    exit /b 0
)

echo === Quick Swarm: %GOAL% ===
echo Launching 4 agents across 3 models...
python "%USERPROFILE%\Scripts\archive\ahe-smoke-test.py" "%GOAL%"
