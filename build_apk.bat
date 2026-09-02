@echo off
title VIT Bus Tracker - Build APK
echo =========================================================
echo    Building VIT Bus Tracker Android APK Bundle
echo =========================================================
echo.

where flutter >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Flutter SDK was not found in your system PATH.
    echo Please make sure Flutter SDK is installed and added to your PATH.
    echo Download Flutter at: https://docs.flutter.dev/get-started/install/windows
    echo.
    pause
    exit /b 1
)

echo Running flutter pub get...
call flutter pub get

echo.
echo Building Release APK...
call flutter build apk --release

if %errorlevel% equ 0 (
    echo.
    echo =========================================================
    echo [SUCCESS] APK built successfully!
    echo File Location:
    echo %~dp0build\app\outputs\flutter-apk\app-release.apk
    echo =========================================================
    explorer "%~dp0build\app\outputs\flutter-apk"
) else (
    echo.
    echo [INFO] Trying debug APK build...
    call flutter build apk --debug
    if %errorlevel% equ 0 (
        echo.
        echo [SUCCESS] Debug APK built successfully!
        echo File Location:
        echo %~dp0build\app\outputs\flutter-apk\app-debug.apk
        explorer "%~dp0build\app\outputs\flutter-apk"
    )
)

echo.
pause
