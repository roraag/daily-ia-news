#!/bin/bash
# Espera tmp/x-reactions-FECHA.json de Grok Bot. Plazo total 12 min desde el request,
# chequeo cada 20 s; cada llamada bloquea como máximo MAX_SLICE s (default 280) para no
# chocar con el timeout del Bash de claude.
# Salida: 0 = llegó y es válido (imprime el JSON) · 2 = sigue esperando, volver a llamar · 1 = timeout/ inválido → fallback.
set -u
PROJECT_DIR="${PROJECT_DIR:-/home/openclaw/DAILY-IA-NEWS}"
FECHA="${1:?fecha}"; MAX_SLICE="${MAX_SLICE:-280}"; TOTAL="${GROK_X_TIMEOUT:-720}"; STEP="${GROK_X_STEP:-20}"
RES="$PROJECT_DIR/tmp/x-reactions-$FECHA.json"; START_F="$PROJECT_DIR/tmp/x-request-$FECHA.start"
START=$(cat "$START_F" 2>/dev/null || date +%s); SLICE_END=$(( $(date +%s) + MAX_SLICE ))
log() { echo "[grok-x $(date '+%H:%M:%S')] $*" >&2; }
valid() { python3 - "$RES" "$FECHA" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
assert d.get("date")==sys.argv[2] and isinstance(d.get("stories"),list)
for s in d["stories"]:
    for p in s.get("posts",[]): assert p.get("handle") and p.get("url","").startswith(("https://x.com/","https://twitter.com/"))
PY
}
while :; do
  if [ -s "$RES" ]; then
    sleep 2
    if valid 2>/dev/null; then log "x-reactions recibido ($RES)"; cat "$RES"; exit 0; fi
    log "x-reactions inválido; uso fallback"; exit 1
  fi
  NOW=$(date +%s)
  if [ $((NOW-START)) -ge "$TOTAL" ]; then log "TIMEOUT: Grok Bot no respondió en $TOTAL s; uso fallback"; exit 1; fi
  if [ "$NOW" -ge "$SLICE_END" ]; then log "sigue esperando ($((NOW-START)) s); volver a llamar"; exit 2; fi
  sleep "$STEP"
done
