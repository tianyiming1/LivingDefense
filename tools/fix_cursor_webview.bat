@echo off
REM Fix Cursor image Webview / ServiceWorker errors.
REM 1) Fully quit Cursor first (tray icon too)
REM 2) Run this script
REM 3) Reopen Cursor

set BASE=%APPDATA%\Cursor
echo Clearing caches under %BASE% ...

for %%D in ("Service Worker" "Cache" "Code Cache" "GPUCache" "DawnGraphiteCache" "DawnWebGPUCache") do (
  if exist "%BASE%\%%~D" (
    rmdir /s /q "%BASE%\%%~D"
    echo Cleared %%~D
  )
)

mkdir "%BASE%\Service Worker" 2>nul
echo.
echo Done. Start Cursor again, then open a PNG.
pause
