#!/usr/bin/env bash
# Sobe o backend do auraFarma neste PC e (por padrão) abre um túnel público, para o app no
# celular conseguir acessar mesmo no 4G. Tudo com um comando:
#
#   ./scripts/rodar-servidor.sh               # backend + túnel (celular no 4G)
#   ./scripts/rodar-servidor.sh --sem-tunel   # só backend (celular no mesmo Wi-Fi / emulador)
#   ./scripts/rodar-servidor.sh --web         # além disso, sobe o site (http://localhost:5173)
#
# Variáveis opcionais: MONGODB_URI, OPENROUTER_API_KEY (pulam as perguntas), PORTA (padrão 4000),
# DIR_BACKEND (onde clonar o backend), CLOUDFLARED (caminho do binário).

set -euo pipefail
set -m # cada processo em segundo plano vira um grupo: dá para encerrar com tudo que ele criou

REPO_BACKEND="${REPO_BACKEND:-https://github.com/akira113p/aura-farma.git}"
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="${DIR_BACKEND:-$RAIZ/aura-farma}"
LOGS="$RAIZ/logs"
PORTA="${PORTA:-4000}"
CLOUDFLARED="${CLOUDFLARED:-cloudflared}"
COM_TUNEL=1
COM_WEB=0

ajuda() { sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }
msg() { printf '\n\033[1;33m==> %s\033[0m\n' "$*"; }
erro() { printf '\033[1;31mErro:\033[0m %s\n' "$*" >&2; exit 1; }

for a in "$@"; do
  case "$a" in
    --sem-tunel) COM_TUNEL=0 ;;
    --web) COM_WEB=1 ;;
    -h | --help) ajuda; exit 0 ;;
    *) erro "opção desconhecida: $a (use --help)" ;;
  esac
done

# ---------------------------------------------------------------- pré-requisitos
command -v git >/dev/null || erro "git não encontrado. Instale: sudo apt install git"
command -v curl >/dev/null || erro "curl não encontrado. Instale: sudo apt install curl"
command -v node >/dev/null || erro "Node.js não encontrado. Instale o Node 20+ (https://nodejs.org ou: sudo apt install nodejs npm)"
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
[ "$NODE_MAJOR" -ge 20 ] || erro "Node $NODE_MAJOR é velho demais; precisa do Node 20 ou mais novo."

instalar_cloudflared() {
  local arq
  case "$(uname -m)" in
    x86_64 | amd64) arq=amd64 ;;
    aarch64 | arm64) arq=arm64 ;;
    armv7l | armhf) arq=arm ;;
    *) erro "arquitetura $(uname -m) sem binário automático; instale à mão: https://github.com/cloudflare/cloudflared/releases" ;;
  esac
  mkdir -p "$HOME/.local/bin"
  curl -fL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$arq" \
    -o "$HOME/.local/bin/cloudflared"
  chmod +x "$HOME/.local/bin/cloudflared"
  export PATH="$HOME/.local/bin:$PATH"
}

if [ "$COM_TUNEL" = 1 ] && ! command -v "$CLOUDFLARED" >/dev/null; then
  echo "O túnel usa o 'cloudflared' (gratuito, sem conta), e ele não está instalado."
  if [ -t 0 ]; then
    read -r -p "Baixar agora para ~/.local/bin? [s/N] " r
    case "$r" in s | S | y | Y) instalar_cloudflared ;; *) erro "sem cloudflared não há túnel. Instale-o ou rode com --sem-tunel." ;; esac
  else
    erro "cloudflared ausente. Instale-o (https://github.com/cloudflare/cloudflared/releases) ou rode com --sem-tunel."
  fi
fi

if (echo >"/dev/tcp/127.0.0.1/$PORTA") 2>/dev/null; then
  erro "a porta $PORTA já está em uso (talvez o backend já esteja rodando). Use outra: PORTA=4001 $0"
fi

# ---------------------------------------------------------------- código do backend
mkdir -p "$LOGS"
if [ -d "$DIR/.git" ]; then
  msg "Atualizando o backend ($DIR)"
  git -C "$DIR" pull --ff-only || echo "(não deu para atualizar; seguindo com a versão que já está aqui)"
else
  msg "Baixando o backend de $REPO_BACKEND"
  git clone --depth 1 "$REPO_BACKEND" "$DIR"
fi

msg "Instalando dependências do backend (pode demorar na 1ª vez)"
npm --prefix "$DIR/backend" install --no-audit --no-fund >"$LOGS/npm-backend.log" 2>&1 \
  || { tail -20 "$LOGS/npm-backend.log"; erro "npm install falhou (log completo em $LOGS/npm-backend.log)"; }

# ---------------------------------------------------------------- configuração (.env)
ENV_FILE="$DIR/backend/.env"
if [ ! -f "$ENV_FILE" ]; then
  msg "Configurando o backend (só na 1ª vez)"
  MONGODB_URI="${MONGODB_URI:-}"
  if [ -z "$MONGODB_URI" ] && [ -t 0 ]; then
    echo "Banco MongoDB. Cole a URI do MongoDB Atlas (mongodb+srv://...) ou deixe vazio para usar"
    echo "um MongoDB instalado neste PC (mongodb://127.0.0.1:27017/aurafarma)."
    read -r -p "MONGODB_URI: " MONGODB_URI
  fi
  MONGODB_URI="${MONGODB_URI:-mongodb://127.0.0.1:27017/aurafarma}"
  OPENROUTER_API_KEY="${OPENROUTER_API_KEY:-}"
  if [ -z "$OPENROUTER_API_KEY" ] && [ -t 0 ]; then
    echo "Chave do OpenRouter (https://openrouter.ai/keys, é grátis). Vazio = assistente de IA desligado."
    read -r -s -p "OPENROUTER_API_KEY: " OPENROUTER_API_KEY
    echo
  fi
  SESSION_SECRET="$(node -e "console.log(require('crypto').randomBytes(48).toString('hex'))")"
  (
    umask 077 # o .env tem segredos: só o seu usuário lê
    cat >"$ENV_FILE" <<EOF
PORT=$PORTA
NODE_ENV=development
MONGODB_URI=$MONGODB_URI
SESSION_SECRET=$SESSION_SECRET
FRONTEND_ORIGIN=http://localhost:5173
OPENROUTER_API_KEY=$OPENROUTER_API_KEY
OPENROUTER_MODEL=nvidia/nemotron-3-ultra-550b-a55b:free
OPENROUTER_FALLBACK_MODELS=poolside/laguna-s-2.1:free,nvidia/nemotron-3.5-lightning:free,google/gemma-4-31b-it:free
OPENROUTER_PLANNER_MODEL=poolside/laguna-s-2.1:free
EOF
  )
  echo "Criado $ENV_FILE (fora do git; para mudar algo, edite esse arquivo)."
fi

# ---------------------------------------------------------------- sobe tudo
PIDS=()
limpar() {
  trap - EXIT INT TERM
  echo
  echo "Encerrando..."
  for p in ${PIDS[@]+"${PIDS[@]}"}; do kill -- "-$p" 2>/dev/null || kill "$p" 2>/dev/null || true; done
}
trap limpar EXIT INT TERM

esperar_http() { # url, segundos
  local i
  for ((i = 0; i < ${2:-60}; i++)); do
    curl -fs -m 3 "$1" >/dev/null 2>&1 && return 0
    sleep 1
  done
  return 1
}

msg "Subindo o backend na porta $PORTA"
npm --prefix "$DIR/backend" start >"$LOGS/backend.log" 2>&1 &
PIDS+=("$!")
if ! esperar_http "http://localhost:$PORTA/api/health" 60; then
  tail -25 "$LOGS/backend.log"
  erro "o backend não subiu. O problema mais comum é o MongoDB inacessível (confira MONGODB_URI em $ENV_FILE). Log: $LOGS/backend.log"
fi
echo "Backend no ar: http://localhost:$PORTA/api/health"

if [ "$COM_WEB" = 1 ]; then
  msg "Subindo o site (http://localhost:5173)"
  npm --prefix "$DIR/frontend" install --no-audit --no-fund >"$LOGS/npm-frontend.log" 2>&1 \
    || { tail -20 "$LOGS/npm-frontend.log"; erro "npm install do site falhou ($LOGS/npm-frontend.log)"; }
  VITE_API_BASE_URL="http://localhost:$PORTA/api" npm --prefix "$DIR/frontend" run dev >"$LOGS/site.log" 2>&1 &
  PIDS+=("$!")
fi

URL=""
if [ "$COM_TUNEL" = 1 ]; then
  msg "Abrindo o túnel público (cloudflared)"
  "$CLOUDFLARED" tunnel --no-autoupdate --url "http://localhost:$PORTA" >"$LOGS/tunel.log" 2>&1 &
  PIDS+=("$!")
  for _ in $(seq 1 45); do
    URL="$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$LOGS/tunel.log" | head -1 || true)"
    [ -n "$URL" ] && break
    sleep 1
  done
  [ -n "$URL" ] || { tail -15 "$LOGS/tunel.log"; erro "o túnel não abriu (log: $LOGS/tunel.log)"; }
fi

echo
echo "=============================================================="
echo " auraFarma no ar"
echo "=============================================================="
if [ -n "$URL" ]; then
  echo " Endereço para o app (celular no 4G):"
  echo "     $URL"
  echo
  echo " No app: tela de login -> toque em \"Servidor: ...\" -> cole o endereço acima -> salvar."
  echo " (O endereço muda toda vez que este script reinicia.)"
else
  echo " Backend:  http://localhost:$PORTA/api"
  echo " Celular no mesmo Wi-Fi: use um destes IPs, ex.: http://<IP>:$PORTA"
  hostname -I 2>/dev/null | tr ' ' '\n' | sed '/^$/d;s/^/     /' || true
  echo " (Se não abrir, é o firewall: libere a porta $PORTA só para a rede local.)"
fi
[ "$COM_WEB" = 1 ] && echo " Site:     http://localhost:5173"
echo
echo " Ctrl+C para parar tudo. Logs em: $LOGS"
echo "=============================================================="

wait
