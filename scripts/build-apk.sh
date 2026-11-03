#!/usr/bin/env bash
# Gera o APK do app para instalar no celular Android.
#
#   ./scripts/build-apk.sh
#
# A URL do servidor NÃO precisa ir no APK: dá para trocar dentro do app, na tela de login.
# Se quiser fixar uma (opcional):  API_BASE_URL=https://meu-servidor.com/api ./scripts/build-apk.sh

# O QUE É: gera o APK (arquivo instalador de app Android) do auraFarma em modo release (versão final, otimizada).
# PRECISA DE: Flutter instalado e o Android SDK configurado. Resultado: build/app/outputs/flutter-apk/app-release.apk.
# 'set -euo pipefail': para o script no primeiro erro, trata variável inexistente como erro e falha se um cano falhar.
set -euo pipefail
# Entra na pasta raiz do projeto Flutter (uma acima de scripts/), não importa de onde o script foi chamado.
# BASH_SOURCE[0] = caminho deste script; dirname = a pasta dele.
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Confere se o comando 'flutter' existe; se não, avisa no canal de erros (>&2) e sai com código 1.
command -v flutter >/dev/null || { echo "Erro: flutter não encontrado (veja o README, seção Linux)." >&2; exit 1; }

# Baixa as dependências listadas no pubspec.yaml.
flutter pub get
# Gera o APK. A parte ${API_BASE_URL:+...} só entra no comando SE a variável API_BASE_URL tiver valor:
# assim, quem quiser fixar o servidor no APK passa a variável; quem não passar gera um APK normal (o servidor se troca dentro do app).
flutter build apk --release ${API_BASE_URL:+--dart-define=API_BASE_URL="$API_BASE_URL"}

# Caminho onde o Flutter coloca o APK pronto.
APK="build/app/outputs/flutter-apk/app-release.apk"
echo
# Mostra onde ficou o arquivo e como instalar no celular (via adb pelo USB, ou copiando o arquivo).
echo "APK pronto: $(pwd)/$APK"
echo "Instalar com o celular no USB (depuração USB ligada):  adb install -r $APK"
echo "Ou copie o arquivo para o celular e abra-o (permita 'instalar apps desconhecidos')."
