#!/bin/bash
# Vercel's build machines don't have Flutter installed, so this fetches it
# fresh on every deploy, then builds the web release. Runs automatically —
# Vercel just needs to be told to run this file (see vercel.json).
set -e  # stop immediately if any step fails, instead of limping on

echo "==> Fetching the Flutter SDK (stable channel)..."
git clone https://github.com/flutter/flutter.git -b stable --depth 1 _flutter_sdk
export PATH="$PATH:$(pwd)/_flutter_sdk/bin"

echo "==> Flutter version:"
flutter --version

echo "==> Enabling web support..."
flutter config --enable-web --no-analytics

echo "==> Fetching packages..."
flutter pub get

echo "==> Building release web bundle..."
flutter build web --release

echo "==> Done — output in build/web"
