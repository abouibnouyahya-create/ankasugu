#!/bin/bash
set -e

# Télécharge Flutter s'il n'est pas déjà là
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable
fi

# Ajoute Flutter au PATH
export PATH="$PATH:`pwd`/flutter/bin"

# Active le web et compile
flutter config --enable-web
flutter pub get
flutter build web --release