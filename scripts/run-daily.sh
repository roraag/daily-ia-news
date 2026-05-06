#!/bin/bash
# Daily IA News - pipeline diario disparado por launchd
# Se ejecuta todos los días a las 7:00 AM hora Uruguay.

set -u  # falla si se usa variable no definida (pero no set -e; queremos loguear errores)

PROJECT_DIR="/Users/rodrigoramosaguirre/DAILY-IA-NEWS"
LOG_DIR="${PROJECT_DIR}/logs"
PROMPT_FILE="${PROJECT_DIR}/prompts/daily-pipeline.md"

# Path que necesita Claude (homebrew en Apple Silicon, local, etc.)
export PATH="/Users/rodrigoramosaguirre/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

# Fecha
# Uso: ./run-daily.sh              → usa la fecha de hoy
#      ./run-daily.sh 2026-04-18   → fuerza esa fecha (para recuperar días perdidos)
if [ $# -ge 1 ]; then
  FECHA_ISO="$1"
  if ! [[ "$FECHA_ISO" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "ERROR: fecha inválida '$FECHA_ISO'. Formato esperado: YYYY-MM-DD" >&2
    exit 1
  fi
  FECHA_ESP=$(LC_TIME=es_ES.UTF-8 date -j -f "%Y-%m-%d" "$FECHA_ISO" +"%A %-d de %B de %Y" 2>/dev/null || echo "$FECHA_ISO")
else
  FECHA_ISO=$(date +"%Y-%m-%d")
  FECHA_ESP=$(LC_TIME=es_ES.UTF-8 date +"%A %-d de %B de %Y" 2>/dev/null || date +"%Y-%m-%d")
fi
FECHA_ESP_LOWER=$(echo "$FECHA_ESP" | tr '[:upper:]' '[:lower:]')

LOG_FILE="${LOG_DIR}/run-${FECHA_ISO}.log"

# Idempotencia: si ya corrió hoy con éxito, salir
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

# Construir el prompt: inyectar fecha + contenido del pipeline
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

# Ejecutar Claude en modo non-interactive
# --permission-mode bypassPermissions: no pide permisos en runtime (automático)
# --allowedTools: tools que puede usar (defensive — redundante con bypassPermissions pero explícito)
# --model opus: usar Opus para el razonamiento de ranking (cambiá a sonnet si querés más barato)
# --output-format text: salida plana para loguear limpio

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

# Sync: reescribe el <script> de todos los HTML (index + archives) con el
# ARCHIVE_DATA actualizado desde index-data.json, para que los días viejos
# vean el histórico completo en el calendario lateral.
if [ $EXIT_CODE -eq 0 ] && [ -f "${PROJECT_DIR}/index-data.json" ]; then
  echo "[$(date '+%H:%M:%S')] Sincronizando ARCHIVE_DATA en HTML viejos..." >> "$LOG_FILE"
  python3 "${PROJECT_DIR}/scripts/sync-archive-data.py" "$PROJECT_DIR" >> "$LOG_FILE" 2>&1 || \
    echo "WARN: sync-archive-data.py falló (no bloquea)" >> "$LOG_FILE"
fi

# Generar resumen ejecutivo del día (Sonnet) — lo manda Lucho por Telegram desde el VPS.
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

# Push del HTML + resumen al VPS de Lucho (Tailscale). Si falla no rompe el cron;
# Lucho simplemente no manda Telegram ese día.
if [ $EXIT_CODE -eq 0 ] && [ -f "${PROJECT_DIR}/archive/${FECHA_ISO}.html" ] && [ -s "$SUMMARY_FILE" ]; then
  echo "[$(date '+%H:%M:%S')] Push al VPS..." >> "$LOG_FILE"
  rsync -az --timeout=30 \
    "${PROJECT_DIR}/archive/${FECHA_ISO}.html" \
    "$SUMMARY_FILE" \
    openclaw@100.113.124.21:~/daily-ia-news/ \
    >> "$LOG_FILE" 2>&1 \
    && echo "[$(date '+%H:%M:%S')] Push OK" >> "$LOG_FILE" \
    || echo "WARN: rsync al VPS falló (no bloquea)" >> "$LOG_FILE"
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
