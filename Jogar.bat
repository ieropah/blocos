@echo off
setlocal
set "GODOT_GUI=D:\Antigravity\Godot\Godot_v4.7.2-stable_win64.exe"

if exist "%GODOT_GUI%" (
    start "" "%GODOT_GUI%" --path "%~dp0."
) else (
    start "" godot --path "%~dp0."
)
