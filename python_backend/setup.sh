#!/bin/bash

echo "========================================"
echo "Face Recognition Backend - Quick Setup"
echo "========================================"
echo ""

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python 3 is not installed"
    echo "Please install Python 3.8 or higher"
    exit 1
fi

echo "[1/4] Python found"
python3 --version
echo ""

# Check if pip is available
if ! command -v pip3 &> /dev/null; then
    echo "ERROR: pip3 is not installed"
    exit 1
fi

echo "[2/4] pip found"
echo ""

# Install requirements
echo "[3/4] Installing Python packages..."
echo "This may take several minutes, especially for face_recognition and dlib"
echo ""

pip3 install -r requirements.txt

if [ $? -ne 0 ]; then
    echo ""
    echo "ERROR: Failed to install requirements"
    echo ""
    echo "If you're on Mac, try:"
    echo "  brew install cmake"
    echo "  pip3 install face-recognition"
    echo ""
    echo "If you're on Linux, try:"
    echo "  sudo apt-get update"
    echo "  sudo apt-get install build-essential cmake libopenblas-dev liblapack-dev"
    echo "  pip3 install -r requirements.txt"
    exit 1
fi

echo ""
echo "[4/4] Checking Firebase credentials..."
if [ ! -f "serviceAccountKey.json" ]; then
    echo ""
    echo "WARNING: serviceAccountKey.json not found!"
    echo ""
    echo "Please download your Firebase service account key:"
    echo "  1. Go to Firebase Console"
    echo "  2. Project Settings > Service Accounts"
    echo "  3. Click 'Generate New Private Key'"
    echo "  4. Save as serviceAccountKey.json in this directory"
    echo ""
else
    echo "Firebase credentials found!"
fi

# Copy .env.example to .env if not exists
if [ ! -f ".env" ]; then
    cp .env.example .env
    echo ".env file created from .env.example"
fi

echo ""
echo "========================================"
echo "Setup Complete!"
echo "========================================"
echo ""
echo "To start the server, run:"
echo "  python3 main.py"
echo ""
echo "Or use:"
echo "  uvicorn main:app --reload"
echo ""
