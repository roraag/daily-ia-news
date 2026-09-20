#!/bin/bash
# Daily IA News - pipeline diario disparado por cron en el VPS de Lucho.
# Variante Linux del run-daily.sh original (Mac).

set -u

PROJECT_DIR="/home/openclaw/DAILY-IA-NEWS"
LOG_DIR="${PROJECT_DIR}/logs"
PROMPT_FILE="${PROJECT_DIR}/prompts/daily-pipeline.md"

# PATH explícito: nvm node + binarios estándar.
export PATH="/home/openclaw/.nvm/versions/node/v22.22.2/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Locale español (instalado vía locale-gen).
export LC_ALL="es_ES.UTF-8"
export LANG="es_ES.UTF-8"

mkdir -p "$LOG_DIR"

# Fecha
if [ $# -ge 1 ]; then
  FECHA_ISO="$1"
  if ! [[ "$FECHA_ISO" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "ERROR: fecha inválida '$FECHA_ISO'. Formato esperado: YYYY-MM-DD" >&2
    exit 1
  fi
  FECHA_ESP=$(LC_TIME=es_ES.UTF-8 date -d "$FECHA_ISO" +"%A %-d de %B de %Y" 2>/dev/null || echo "$FECHA_ISO")
else
  FECHA_ISO=$(date +"%Y-%m-%d")
  FECHA_ESP=$(LC_TIME=es_ES.UTF-8 date +"%A %-d de %B de %Y" 2>/dev/null || date +"%Y-%m-%d")
fi
FECHA_ESP_LOWER=$(echo "$FECHA_ESP" | tr '[:upper:]' '[:lower:]')

LOG_FILE="${LOG_DIR}/run-${FECHA_ISO}.log"

# Una sola corrida puede modificar/publicar el repositorio a la vez.
exec 9>"${LOG_DIR}/daily-pipeline.lock"
if ! flock -n 9; then
  echo "ERROR: otra corrida del Daily está activa" >> "$LOG_FILE"
  exit 75
fi

# Idempotencia
if [ -f "${PROJECT_DIR}/archive/${FECHA_ISO}.html" ]; then
  echo "[$(date '+%H:%M:%S')] Ya existe archive/${FECHA_ISO}.html — nada que hacer." >> "$LOG_FILE"
  exit 0
fi

{
  echo "=========================================="
  echo "INICIO: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "PROJECT_DIR: $PROJECT_DIR"
  echo "FECHA_ISO: $FECHA_ISO"
  echo "FECHA_ESP: $FECHA_ESP_LOWER"
  echo "=========================================="
} >> "$LOG_FILE"

cd "$PROJECT_DIR" || {
  echo "ERROR: no pude cd a $PROJECT_DIR" >> "$LOG_FILE"
  exit 1
}

PROMPT_HEADER="Contexto temporal: hoy es ${FECHA_ESP_LOWER}. Usá fecha ISO ${FECHA_ISO} para nombrar el archivo del archive.

Rutas absolutas a usar en todo momento:
- Proyecto: ${PROJECT_DIR}
- Config: ${PROJECT_DIR}/config/sources.yaml
- Template: ${PROJECT_DIR}/templates/base.html
- Archivo del día a generar: ${PROJECT_DIR}/archive/${FECHA_ISO}.html
- Home del dashboard: ${PROJECT_DIR}/index.html
- Metadata histórico: ${PROJECT_DIR}/index-data.json

---

"

FULL_PROMPT="${PROMPT_HEADER}$(cat "$PROMPT_FILE")"

# Reintentar SOLO una vez un corte transitorio del generador.
# Publicación y resumen quedan fuera del bucle para no duplicarlos.
run_generator() {
  local attempt output rc retry_prompt
  retry_prompt="$FULL_PROMPT
No hagas git commit, git push ni publicaciones externas: eso lo hace el script al terminar."
  for attempt in 1 2; do
    output=$(mktemp "${LOG_DIR}/generator-${FECHA_ISO}-XXXXXX") || return 1
    echo "[$(date '+%H:%M:%S')] Ejecutando claude (intento $attempt/2)..." >> "$LOG_FILE"
    claude --print --permission-mode bypassPermissions \
      --allowedTools "Read Write Edit Bash Glob Grep WebFetch WebSearch" \
      --model sonnet --output-format text "$retry_prompt" > "$output" 2>&1
    rc=$?
    cat "$output" >> "$LOG_FILE"
    if [ "$rc" -eq 0 ]; then
      return 0
    fi
    # Leer únicamente la salida del intento actual, no errores viejos del log.
    if [ "$attempt" -eq 2 ] || ! python3 - "$output" <<'PY'
import re, sys
from pathlib import Path
text = Path(sys.argv[1]).read_text(errors='replace')
auth = re.search(r'authentication_error|Failed to authenticate|OAuth.*expired|API Error: 401', text, re.I)
transient = re.search(r'Stream idle timeout|API Error:.*(?:timeout|529|503|502)|ECONNRESET|ETIMEDOUT', text, re.I)
sys.exit(0 if transient and not auth else 1)
PY
    then
      return "$rc"
    fi
    echo "[$(date '+%H:%M:%S')] Corte transitorio: único reintento en 30 segundos." >> "$LOG_FILE"
    sleep 30
    retry_prompt="$FULL_PROMPT
El intento anterior se interrumpió. Revisá los archivos parciales de hoy y completalos o corregilos; no des por terminado un HTML solo porque existe. No dupliques la fecha en index-data.json. No hagas git commit, git push ni publicaciones externas: eso lo hace el script al terminar."
  done
}

run_generator
EXIT_CODE=$?

# Sync ARCHIVE_DATA en HTML viejos
if [ $EXIT_CODE -eq 0 ] && [ -f "${PROJECT_DIR}/index-data.json" ]; then
  echo "[$(date '+%H:%M:%S')] Sincronizando ARCHIVE_DATA en HTML viejos..." >> "$LOG_FILE"
  python3 "${PROJECT_DIR}/scripts/sync-archive-data.py" "$PROJECT_DIR" >> "$LOG_FILE" 2>&1 || \
    echo "WARN: sync-archive-data.py falló (no bloquea)" >> "$LOG_FILE"
fi

# Resumen ejecutivo
SUMMARY_FILE="${PROJECT_DIR}/archive/resumen-${FECHA_ISO}.txt"
if [ $EXIT_CODE -eq 0 ] && [ -f "${PROJECT_DIR}/archive/${FECHA_ISO}.html" ]; then
  echo "[$(date '+%H:%M:%S')] Generando resumen ejecutivo..." >> "$LOG_FILE"
  claude \
    --print \
    --permission-mode bypassPermissions \
    --allowedTools "Read" \
    --model sonnet \
    --output-format text \
    "Leé el archivo ${PROJECT_DIR}/archive/${FECHA_ISO}.html que contiene el Daily IA News del día y devolveme un resumen ejecutivo en TEXTO PLANO con esta estructura: línea 1 la Tesis del día condensada en una oración. Líneas 2 a 4 tres titulares de 'Lo que importa hoy' (los más jugosos) una línea cada uno con verbo de acción. Línea 5 opcional una observación de qué prestar atención hoy. Reglas: 5 a 7 líneas total. Primera persona vos/te. Sin emojis. Sin markdown. Sin saludo. Sin firma. Sin links. Sin etiquetas HTML. No te disculpes ni expliques. Devolveme SOLO el texto del resumen, no crees archivos." \
    > "$SUMMARY_FILE" 2>> "$LOG_FILE"
  if [ -s "$SUMMARY_FILE" ]; then
    echo "[$(date '+%H:%M:%S')] Resumen generado ($(wc -c < "$SUMMARY_FILE") bytes)" >> "$LOG_FILE"
  else
    echo "WARN: resumen vacío" >> "$LOG_FILE"
  fi
fi

# Copia local a ~/daily-ia-news/ (donde Lucho lee). Reemplaza el rsync remoto del original.
TARGET_DIR="/home/openclaw/daily-ia-news"
if [ $EXIT_CODE -eq 0 ] && [ -f "${PROJECT_DIR}/archive/${FECHA_ISO}.html" ] && [ -s "$SUMMARY_FILE" ]; then
  echo "[$(date '+%H:%M:%S')] Copiando a $TARGET_DIR..." >> "$LOG_FILE"
  mkdir -p "$TARGET_DIR"
  cp "${PROJECT_DIR}/archive/${FECHA_ISO}.html" "$TARGET_DIR/" \
    && cp "$SUMMARY_FILE" "$TARGET_DIR/" \
    && echo "[$(date '+%H:%M:%S')] Copia OK" >> "$LOG_FILE" \
    || echo "WARN: copia local falló (no bloquea)" >> "$LOG_FILE"
fi

# Push a GitHub Pages -> https://roraag.github.io/daily-ia-news/
if [ $EXIT_CODE -eq 0 ] && [ -f "${PROJECT_DIR}/archive/${FECHA_ISO}.html" ]; then
  echo "[$(date '+%H:%M:%S')] Push a GitHub Pages..." >> "$LOG_FILE"
  cd "$PROJECT_DIR"
  git add -A >> "$LOG_FILE" 2>&1
  if git diff --cached --quiet; then
    echo "[$(date '+%H:%M:%S')] git: nada para commitear" >> "$LOG_FILE"
  else
    git commit -m "Daily: ${FECHA_ISO}" >> "$LOG_FILE" 2>&1
    if git push origin main >> "$LOG_FILE" 2>&1; then
      echo "[$(date '+%H:%M:%S')] Push OK -> https://roraag.github.io/daily-ia-news/" >> "$LOG_FILE"
    else
      echo "WARN: git push falló (no bloquea)" >> "$LOG_FILE"
    fi
  fi
fi

{
  echo ""
  echo "=========================================="
  echo "FIN: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "EXIT_CODE: $EXIT_CODE"
  if [ -f "${PROJECT_DIR}/archive/${FECHA_ISO}.html" ]; then
    echo "OK: archive/${FECHA_ISO}.html existe ($(wc -c < "${PROJECT_DIR}/archive/${FECHA_ISO}.html") bytes)"
  else
    echo "WARN: archive/${FECHA_ISO}.html NO existe"
  fi
  echo "=========================================="
} >> "$LOG_FILE"

exit $EXIT_CODE
