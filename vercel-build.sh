#!/bin/bash
# Vercel's build machines don't have Flutter installed, so this fetches it
# fresh on every deploy, then builds the web release. Runs automatically —
# Vercel just needs to be told to run this file (see vercel.json).
set -e  # stop immediately if any step fails, instead of limping on

# Captured once, up front, and explicitly `cd`'d back into before every
# command that needs pubspec.yaml — a completely fresh Flutter SDK clone
# triggers a first-run artifact precache on its first invocation, and on
# at least some Flutter versions that appears to leave the shell's working
# directory in an unexpected state afterwards ("Expected to find project
# root in current working directory" right after the precache finishes).
# Not trusting the CWD to hold across steps sidesteps that entirely,
# whatever the exact cause.
PROJECT_ROOT="$(pwd)"
echo "==> Project root: $PROJECT_ROOT"

echo "==> Fetching the Flutter SDK (stable channel)..."
git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$PROJECT_ROOT/_flutter_sdk"
export PATH="$PATH:$PROJECT_ROOT/_flutter_sdk/bin"

echo "==> Flutter version:"
flutter --version

echo "==> Precaching web artifacts (done as its own step so 'pub get'"
echo "    below never has to trigger this implicitly)..."
flutter precache --web

echo "==> Enabling web support..."
flutter config --enable-web --no-analytics

cd "$PROJECT_ROOT"
if [ ! -f "pubspec.yaml" ]; then
  echo "ERROR: pubspec.yaml not found in $PROJECT_ROOT — directory contents:"
  ls -la
  exit 1
fi

echo "==> Fetching packages..."
flutter pub get

cd "$PROJECT_ROOT"
echo "==> Building release web bundle..."
flutter build web --release

echo "==> Done — output in build/web"
