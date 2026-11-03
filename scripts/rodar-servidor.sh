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
#
# GUIA PARA QUEM NUNCA VIU SHELL AVANÇADO
# O QUE É: script de terminal (bash, Linux/WSL/Mac) que prepara e liga o backend do auraFarma neste PC e, por padrão,
# abre um túnel público (cloudflared) para o app no celular alcançar o backend mesmo fora do Wi-Fi.
# COMO RODAR: ./scripts/rodar-servidor.sh   (opções: --sem-tunel, --web, --help). Ctrl+C encerra tudo.
# PRECISA DE: git, curl e Node 20+ instalados; MongoDB (URI do Atlas ou um local). O script confere e avisa o que falta.
# As 11 primeiras linhas de comentário lá em cima são o texto do --help: a função ajuda() lê as linhas 2 a 12 do arquivo.
# Por isso NÃO se coloca nada entre elas; todo comentário novo fica daqui para baixo.
#
# 'set -e' = parar o script se qualquer comando falhar; '-u' = erro se usar variável que não existe;
# '-o pipefail' = num cano (a | b) falhar se qualquer parte falhar. Juntos evitam o script seguir 'cego' depois de um erro.
# (A linha 'set -euo pipefail' logo acima aparece no --help por causa do intervalo de linhas; é inofensivo.)
#
# 'set -m' liga o 'controle de jobs': cada processo em segundo plano (&) vira seu próprio grupo,
# e assim dá para matar o processo junto com tudo o que ele iniciou (veja a função limpar).
set -m # cada processo em segundo plano vira um grupo: dá para encerrar com tudo que ele criou

# REPO_BACKEND: de onde baixar o backend. '${VAR:-padrao}' significa 'use o valor da variável VAR; se ela estiver
# vazia ou não existir, use o padrão'. Assim dá para sobrescrever pelo terminal: REPO_BACKEND=... ./scripts/rodar-servidor.sh
REPO_BACKEND="${REPO_BACKEND:-https://github.com/akira113p/aura-farma.git}"
# RAIZ: pasta do projeto. BASH_SOURCE[0] é o caminho deste script; dirname pega a pasta dele; '/..' sobe um nível;
# 'cd ... && pwd' entra lá e imprime o caminho absoluto. $( ... ) captura essa saída para a variável.
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# DIR: onde fica a cópia do backend (padrão: pasta aura-farma dentro do projeto). LOGS: pasta dos arquivos de log.
DIR="${DIR_BACKEND:-$RAIZ/aura-farma}"
LOGS="$RAIZ/logs"
# Porta do backend (padrão 4000) e nome/caminho do programa cloudflared.
PORTA="${PORTA:-4000}"
CLOUDFLARED="${CLOUDFLARED:-cloudflared}"
# Interruptores (1 = ligado, 0 = desligado). Os argumentos --sem-tunel e --web mudam esses valores.
COM_TUNEL=1
COM_WEB=0

# ajuda(): imprime as linhas 2 a 12 deste arquivo (sed -n '2,12p') e tira o '# ' do começo de cada uma (segundo sed).
ajuda() { sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }
# msg(): imprime um título amarelo e em negrito (\033[...m são códigos de cor do terminal). $* = todos os argumentos.
msg() { printf '\n\033[1;33m==> %s\033[0m\n' "$*"; }
# erro(): imprime 'Erro:' em vermelho no canal de erros (>&2) e encerra o script com código 1 (= falhou).
erro() { printf '\033[1;31mErro:\033[0m %s\n' "$*" >&2; exit 1; }

# Lê cada argumento passado ao script ($@ = todos) e ajusta os interruptores; argumento desconhecido dá erro.
for a in "$@"; do
  case "$a" in
    --sem-tunel) COM_TUNEL=0 ;;
    --web) COM_WEB=1 ;;
    -h | --help) ajuda; exit 0 ;;
    *) erro "opção desconhecida: $a (use --help)" ;;
  esac
done

# Pré-requisitos: 'command -v X' diz se o programa X existe; '>/dev/null' esconde a saída; '|| erro ...' roda erro()
# se o comando falhar (ou seja, se o programa não existe).
# ---------------------------------------------------------------- pré-requisitos
command -v git >/dev/null || erro "git não encontrado. Instale: sudo apt install git"
command -v curl >/dev/null || erro "curl não encontrado. Instale: sudo apt install curl"
command -v node >/dev/null || erro "Node.js não encontrado. Instale o Node 20+ (https://nodejs.org ou: sudo apt install nodejs npm)"
# Pergunta ao Node qual a versão principal (ex.: 20) e confere se é >= 20 ('-ge' = maior ou igual).
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
[ "$NODE_MAJOR" -ge 20 ] || erro "Node $NODE_MAJOR é velho demais; precisa do Node 20 ou mais novo."

# instalar_cloudflared(): baixa o binário do cloudflared certo para o processador deste computador.
instalar_cloudflared() {
  # 'local' faz a variável existir só dentro desta função.
  local arq
  # uname -m diz o tipo de processador; cada tipo usa um arquivo diferente do cloudflared.
  case "$(uname -m)" in
    x86_64 | amd64) arq=amd64 ;;
    aarch64 | arm64) arq=arm64 ;;
    armv7l | armhf) arq=arm ;;
    *) erro "arquitetura $(uname -m) sem binário automático; instale à mão: https://github.com/cloudflare/cloudflared/releases" ;;
  esac
  # Cria a pasta de programas do usuário (-p = não reclama se já existe).
  mkdir -p "$HOME/.local/bin"
  # Baixa o arquivo: -f = falha de verdade se o servidor responder erro; -L = segue redirecionamentos; -o = onde salvar.
  curl -fL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$arq" \
    -o "$HOME/.local/bin/cloudflared"
  # Dá permissão de execução ao arquivo baixado.
  chmod +x "$HOME/.local/bin/cloudflared"
  # Põe essa pasta no PATH (lista de lugares onde o shell procura programas) só durante esta execução.
  export PATH="$HOME/.local/bin:$PATH"
}

# Se o túnel está ligado e o cloudflared não está instalado, oferece instalar.
if [ "$COM_TUNEL" = 1 ] && ! command -v "$CLOUDFLARED" >/dev/null; then
  echo "O túnel usa o 'cloudflared' (gratuito, sem conta), e ele não está instalado."
  # [ -t 0 ] é verdadeiro quando há uma pessoa digitando no terminal (entrada interativa). Se o script rodar
  # sem terminal (automação), não dá para perguntar, então ele só avisa o erro.
  if [ -t 0 ]; then
    # read -r -p mostra a pergunta e guarda a resposta em 'r' (-r: não interpreta barras invertidas).
    read -r -p "Baixar agora para ~/.local/bin? [s/N] " r
    case "$r" in s | S | y | Y) instalar_cloudflared ;; *) erro "sem cloudflared não há túnel. Instale-o ou rode com --sem-tunel." ;; esac
  else
    erro "cloudflared ausente. Instale-o (https://github.com/cloudflare/cloudflared/releases) ou rode com --sem-tunel."
  fi
fi

# Testa se a porta já está em uso: tenta abrir uma conexão TCP em 127.0.0.1:PORTA usando o recurso especial
# /dev/tcp do bash. Se conectar, alguém já escutou nessa porta (talvez o backend já rodando). Os parênteses isolam o teste
# e 2>/dev/null esconde a mensagem de erro quando a porta está livre.
if (echo >"/dev/tcp/127.0.0.1/$PORTA") 2>/dev/null; then
  erro "a porta $PORTA já está em uso (talvez o backend já esteja rodando). Use outra: PORTA=4001 $0"
fi

# Código do backend: baixa na primeira vez, atualiza nas próximas.
# ---------------------------------------------------------------- código do backend
mkdir -p "$LOGS"
# Se já existe um repositório git no DIR, só atualiza.
if [ -d "$DIR/.git" ]; then
  msg "Atualizando o backend ($DIR)"
  # git pull --ff-only só avança se for simples (sem mesclagens). Se falhar (sem internet etc.), segue com a versão local.
  git -C "$DIR" pull --ff-only || echo "(não deu para atualizar; seguindo com a versão que já está aqui)"
else
  msg "Baixando o backend de $REPO_BACKEND"
  # Primeira vez: clona (--depth 1 baixa só a versão mais recente, bem mais rápido).
  git clone --depth 1 "$REPO_BACKEND" "$DIR"
fi

# Instala as dependências do backend (npm install). A saída vai para um arquivo de log (>...log 2>&1 junta mensagens normais
# e de erro). Se falhar, mostra as últimas 20 linhas do log e para. A barra invertida no fim da linha continua o comando.
msg "Instalando dependências do backend (pode demorar na 1ª vez)"
npm --prefix "$DIR/backend" install --no-audit --no-fund >"$LOGS/npm-backend.log" 2>&1 \
  || { tail -20 "$LOGS/npm-backend.log"; erro "npm install falhou (log completo em $LOGS/npm-backend.log)"; }

# Configuração (.env): o backend precisa de um arquivo .env com segredos. Só é criado se ainda não existir.
# ---------------------------------------------------------------- configuração (.env)
ENV_FILE="$DIR/backend/.env"
if [ ! -f "$ENV_FILE" ]; then
  msg "Configurando o backend (só na 1ª vez)"
  # Pega a URI do Mongo da variável de ambiente; se não houver, fica vazia.
  MONGODB_URI="${MONGODB_URI:-}"
  # Se está vazia E há uma pessoa no terminal, pergunta (-z testa 'texto vazio').
  if [ -z "$MONGODB_URI" ] && [ -t 0 ]; then
    echo "Banco MongoDB. Cole a URI do MongoDB Atlas (mongodb+srv://...) ou deixe vazio para usar"
    echo "um MongoDB instalado neste PC (mongodb://127.0.0.1:27017/aurafarma)."
    read -r -p "MONGODB_URI: " MONGODB_URI
  fi
  # Se continuou vazia, usa um MongoDB local no próprio computador.
  MONGODB_URI="${MONGODB_URI:-mongodb://127.0.0.1:27017/aurafarma}"
  OPENROUTER_API_KEY="${OPENROUTER_API_KEY:-}"
  # Mesma ideia para a chave do OpenRouter (serviço de IA). Vazia = assistente de IA desligado.
  if [ -z "$OPENROUTER_API_KEY" ] && [ -t 0 ]; then
    echo "Chave do OpenRouter (https://openrouter.ai/keys, é grátis). Vazio = assistente de IA desligado."
    # read -s não mostra o que é digitado na tela (é uma chave secreta).
    read -r -s -p "OPENROUTER_API_KEY: " OPENROUTER_API_KEY
    echo
  fi
  # Gera um segredo aleatório de 96 caracteres com o Node; ele protege os cookies de sessão do backend.
  SESSION_SECRET="$(node -e "console.log(require('crypto').randomBytes(48).toString('hex'))")"
  # Os parênteses abrem um 'subshell' (mini-ambiente), para o umask abaixo valer só aqui dentro.
  (
    # Atenção: o texto do arquivo .env fica dentro do bloco 'cat <<EOF ... EOF' (heredoc); por isso NÃO há comentários dentro dele,
    # pois tudo ali vira conteúdo do arquivo. $PORTA e as outras variáveis são trocadas pelos valores reais.
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
# Sobe tudo. PIDS é a lista dos números (PIDs) dos processos que este script iniciou, para poder encerrá-los depois.
PIDS=()
# limpar(): chamada ao sair ou no Ctrl+C. Mata cada processo iniciado.
# 'trap - EXIT INT TERM' primeiro desliga o gancho para não rodar duas vezes.
limpar() {
  trap - EXIT INT TERM
  echo
  echo "Encerrando..."
  # kill -- -PID mata o GRUPO inteiro do processo (por isso o set -m); se falhar, tenta matar só o processo;
  # '|| true' garante que um erro aqui não interrompe a limpeza. A expansão estranha com '+' evita erro se a lista estiver vazia.
  for p in ${PIDS[@]+"${PIDS[@]}"}; do kill -- "-$p" 2>/dev/null || kill "$p" 2>/dev/null || true; done
}
# trap = 'armadilha': pede ao shell para rodar limpar() quando o script terminar (EXIT), receber Ctrl+C (INT) ou pedido de término (TERM).
trap limpar EXIT INT TERM

# esperar_http(url, segundos): tenta acessar a URL a cada segundo até responder ou o tempo acabar. Devolve 0 (sucesso) ou 1.
esperar_http() { # url, segundos
  # 'local i' = contador só desta função.
  local i
  # Repete de 0 até o limite. ${2:-60} = segundo argumento, ou 60 se não foi dado.
  for ((i = 0; i < ${2:-60}; i++)); do
    # curl -fs -m 3: -f falha se o servidor responder erro HTTP, -s fica quieto, -m 3 desiste após 3 segundos.
    # Se der certo, 'return 0' sai da função com sucesso.
    curl -fs -m 3 "$1" >/dev/null 2>&1 && return 0
    sleep 1
  done
  return 1
}

# Liga o backend em segundo plano (&), mandando o texto que ele imprime para um arquivo de log.
msg "Subindo o backend na porta $PORTA"
npm --prefix "$DIR/backend" start >"$LOGS/backend.log" 2>&1 &
# $! é o número do último processo iniciado em segundo plano; guardamos na lista.
PIDS+=("$!")
# Espera até 60 s o endereço /api/health responder. Se não responder, mostra o fim do log e para com uma dica.
if ! esperar_http "http://localhost:$PORTA/api/health" 60; then
  tail -25 "$LOGS/backend.log"
  erro "o backend não subiu. O problema mais comum é o MongoDB inacessível (confira MONGODB_URI em $ENV_FILE). Log: $LOGS/backend.log"
fi
echo "Backend no ar: http://localhost:$PORTA/api/health"

# Opcional (--web): instala e liga também o site (front-end) na porta 5173.
if [ "$COM_WEB" = 1 ]; then
  msg "Subindo o site (http://localhost:5173)"
  npm --prefix "$DIR/frontend" install --no-audit --no-fund >"$LOGS/npm-frontend.log" 2>&1 \
    || { tail -20 "$LOGS/npm-frontend.log"; erro "npm install do site falhou ($LOGS/npm-frontend.log)"; }
  # Variável antes do comando (VAR=valor comando) vale só para esse comando: aponta o site para este backend.
  VITE_API_BASE_URL="http://localhost:$PORTA/api" npm --prefix "$DIR/frontend" run dev >"$LOGS/site.log" 2>&1 &
  PIDS+=("$!")
fi

# Túnel público: o cloudflared cria um endereço https://....trycloudflare.com que chega até o backend deste PC.
URL=""
if [ "$COM_TUNEL" = 1 ]; then
  msg "Abrindo o túnel público (cloudflared)"
  # Liga o cloudflared em segundo plano; o endereço aparece no log dele.
  "$CLOUDFLARED" tunnel --no-autoupdate --url "http://localhost:$PORTA" >"$LOGS/tunel.log" 2>&1 &
  PIDS+=("$!")
  # Tenta até 45 vezes (1 por segundo) achar o endereço no log. seq 1 45 gera os números; '_' é um contador que não usamos.
  for _ in $(seq 1 45); do
    # grep -oE: -E usa expressão regular e -o imprime só o trecho que casou (o endereço https://...trycloudflare.com);
    # head -1 fica com o primeiro. '|| true' evita parar o script (por causa do set -e) quando ainda não achou nada.
    URL="$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$LOGS/tunel.log" | head -1 || true)"
    # Se achou algo (-n = texto não vazio), sai do laço.
    [ -n "$URL" ] && break
    sleep 1
  done
  # Se depois de 45 tentativas ainda não há endereço, mostra o fim do log e para.
  [ -n "$URL" ] || { tail -15 "$LOGS/tunel.log"; erro "o túnel não abriu (log: $LOGS/tunel.log)"; }
fi

# Mensagem final para a pessoa: o endereço a colar no app (ou os IPs da rede local, se estiver sem túnel).
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
  # hostname -I lista os IPs deste PC; tr troca espaços por quebras de linha; sed apaga linhas vazias e recua as demais.
  hostname -I 2>/dev/null | tr ' ' '\n' | sed '/^$/d;s/^/     /' || true
  echo " (Se não abrir, é o firewall: libere a porta $PORTA só para a rede local.)"
fi
[ "$COM_WEB" = 1 ] && echo " Site:     http://localhost:5173"
echo
echo " Ctrl+C para parar tudo. Logs em: $LOGS"
echo "=============================================================="

# 'wait' deixa o script parado esperando os processos em segundo plano. Ele só termina com Ctrl+C, que dispara o limpar().
wait
