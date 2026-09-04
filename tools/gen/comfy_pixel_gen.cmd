@echo off
chcp 65001 >nul
cd /d "%~dp0\..\.."
echo ComfyUI pick_004 flame_drake style -^> _studio/dragon/longren
python tools\gen\comfy_pixel_gen.py --preset flame_drake %*
if errorlevel 1 pause
