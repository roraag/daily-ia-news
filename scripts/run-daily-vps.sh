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

echo "[$(date '+%H:%M:%S')] Ejecutando claude..." >> "$LOG_FILE"

claude \
  --print \
  --permission-mode bypassPermissions \
  --allowedTools "Read Write Edit Bash Glob Grep WebFetch WebSearch" \
  --model sonnet \
  --output-format text \
  "$FULL_PROMPT" \
  >> "$LOG_FILE" 2>&1

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
