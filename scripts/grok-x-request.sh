#!/bin/bash
# Daily IA News — pide a Grok Bot reacciones de X para las noticias elegidas.
# Uso: grok-x-request.sh YYYY-MM-DD  (requiere tmp/x-request-FECHA.json ya escrito)
# Nunca falla el diario: siempre sale 0. No imprime la clave.
set -u
PROJECT_DIR="/home/openclaw/DAILY-IA-NEWS"
FECHA="${1:?fecha}"
REQ="$PROJECT_DIR/tmp/x-request-$FECHA.json"
ENV_FILE="/home/openclaw/.config/daily-ia-news/grokbot.env"
mkdir -p "$PROJECT_DIR/tmp"
date +%s > "$PROJECT_DIR/tmp/x-request-$FECHA.start"
log() { echo "[grok-x $(date '+%H:%M:%S')] $*"; }
if [ ! -s "$REQ" ] || ! python3 -m json.tool "$REQ" >/dev/null 2>&1; then
  log "SKIP: falta o es inválido $REQ"; exit 0; fi
[ -f "$ENV_FILE" ] && { set -a; . "$ENV_FILE"; set +a; }
URL="${GROKBOT_WEBHOOK_URL:-}"; KEY="${GROKBOT_WEBHOOK_KEY:-}"
case "$URL$KEY" in *REEMPLAZAR*) URL="";; esac
if [ -z "$URL" ] || [ -z "$KEY" ]; then
  log "SKIP POST: GROKBOT_WEBHOOK_URL/KEY no configurados ($ENV_FILE)"; exit 0; fi
CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 -X POST \
  -H "Content-Type: application/json" -H "Authorization: Bearer $KEY" -H "X-Webhook-Key: $KEY" \
  --data-binary "@$REQ" "$URL") || CODE="curl-error"
log "POST webhook -> HTTP $CODE"
exit 0
