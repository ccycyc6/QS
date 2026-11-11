@echo off
rem Windows 一键入口：调用 WSL 里的 Verilator 跑单层
rem   tools\sim\run_layer.bat 20
setlocal
for /f "delims=" %%i in ('wsl wslpath -a "%~dp0..\.."') do set "ROOTWSL=%%i"
wsl -d Ubuntu-24.04 -- bash -lc "cd '%ROOTWSL%' && bash tools/sim/run_layer.sh %~1"
