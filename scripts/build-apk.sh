#!/usr/bin/env bash
# Gera o APK do app para instalar no celular Android.
#
#   ./scripts/build-apk.sh
#
# A URL do servidor NÃO precisa ir no APK: dá para trocar dentro do app, na tela de login.
# Se quiser fixar uma (opcional):  API_BASE_URL=https://meu-servidor.com/api ./scripts/build-apk.sh

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

command -v flutter >/dev/null || { echo "Erro: flutter não encontrado (veja o README, seção Linux)." >&2; exit 1; }

flutter pub get
flutter build apk --release ${API_BASE_URL:+--dart-define=API_BASE_URL="$API_BASE_URL"}

APK="build/app/outputs/flutter-apk/app-release.apk"
echo
echo "APK pronto: $(pwd)/$APK"
echo "Instalar com o celular no USB (depuração USB ligada):  adb install -r $APK"
echo "Ou copie o arquivo para o celular e abra-o (permita 'instalar apps desconhecidos')."
