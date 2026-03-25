@echo off
echo ========================================
echo Face Recognition Backend - Quick Setup
echo ========================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python 3.8 or higher from https://www.python.org/
    pause
    exit /b 1
)

echo [1/4] Python found
python --version
echo.

REM Check if pip is available
pip --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: pip is not installed
    pause
    exit /b 1
)

echo [2/4] pip found
echo.

REM Install requirements
echo [3/4] Installing Python packages...
echo This may take several minutes, especially for face_recognition and dlib
echo.
pip install -r requirements.txt
if errorlevel 1 (
    echo.
    echo ERROR: Failed to install requirements
    echo.
    echo If you're on Windows and face_recognition fails to install, try:
    echo   1. Install Visual Studio Build Tools
    echo   2. Or use: pip install face-recognition --no-cache-dir
    pause
    exit /b 1
)

echo.
echo [4/4] Checking Firebase credentials...
if not exist "serviceAccountKey.json" (
    echo.
    echo WARNING: serviceAccountKey.json not found!
    echo.
    echo Please download your Firebase service account key:
    echo   1. Go to Firebase Console
    echo   2. Project Settings ^> Service Accounts
    echo   3. Click "Generate New Private Key"
    echo   4. Save as serviceAccountKey.json in this directory
    echo.
    pause
) else (
    echo Firebase credentials found!
)

echo.
echo ========================================
echo Setup Complete!
echo ========================================
echo.
echo To start the server, run:
echo   python main.py
echo.
echo Or use:
echo   uvicorn main:app --reload
echo.
pause
