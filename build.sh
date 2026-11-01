#!/bin/bash
set -e

echo "Installing Flutter..."
FLUTTER_SDK_PATH="$HOME/flutter"
if [ ! -d "$FLUTTER_SDK_PATH" ]; then
  git clone --branch stable https://github.com/flutter/flutter.git $FLUTTER_SDK_PATH
fi
export PATH="$FLUTTER_SDK_PATH/bin:$PATH"

echo "Getting dependencies..."
flutter pub get

echo "Building web..."
flutter build web --release