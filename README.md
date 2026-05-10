# Daily IA News

Diario personal de IA generado todos los días a las 7:00 AM hora Uruguay. **No es un agregador**: es un medio con voz, opinión declarada, y secciones recurrentes con marca propia. Lector único: Rodrigo.

## Uso diario

- Abrí `index.html` en cualquier navegador. Siempre muestra el último día generado.
- El pipeline corre automático todos los días a las 7:00 AM (hora Uruguay) vía launchd + claude CLI.

## Vistas (tabs)

Cada página diaria tiene 2 solapas:

- **Daily IA News**: el diario original (default).
- **IA Práctica**: una vista paralela enfocada en casos reales + playbooks + startups (LATAM + mundo) + ángulo Uruguay/Río de la Plata.

Notas:
- Si el navegador no ejecuta JS, se muestran ambas secciones una debajo de la otra (fallback).
- Para días viejos, “IA Práctica” puede aparecer con un placeholder hasta que se regenere con el pipeline.

## Estructura editorial del diario

Cada día el medio publica 5 bloques:

1. **La tesis del día** — 2-4 oraciones que conectan las noticias del día en un hilo. Postura editorial declarada.
2. **Lo que importa hoy** (Nivel A) — 3-7 noticias con desarrollo completo: título con voz, "Lo que pasó" (hechos crudos), **"El ángulo que nadie te va a dar"** (opinión + cita al panel humano), **"Para vos"** (acción concreta para Rodrigo), botón **"Llevame a Claude con esto"** (copia un prompt pre-armado al portapapeles).
3. **Anthropic Watch** — sección fija dedicada a Anthropic. Posts del blog, jobs nuevos, takes de Dario / Krieger / Clark.
4. **El Bolsillo** — quién hizo plata hoy con IA. Bullets con actor + monto + lectura. Cierra con patrón de la semana.
5. **El resto** (Nivel B) — hasta 12 noticias menores con score ≥ 8, en una línea cada una, sin desarrollo. Para que nada con peso se pierda.

**Sin cuota fija de noticias.** El editor (el prompt) decide cuántas entran a Nivel A según el día. Algunos días son 3 grandes + 8 breves, otros 7 grandes + 4 breves.

## Componentes

- `config/sources.yaml` — pool con dos bloques:
  - `sources` (23 medios editoriales: TechCrunch, MIT TR, STAT, HBR, Stratechery, Platformer, Anthropic Blog/Engineering/Careers, etc.)
  - `voices` (panel humano de 21 personas en 3 paneles: 10 founders, 6 especialistas, 5 críticos)
- `templates/base.html` — plantilla con placeholders (`{{TESIS_DIA}}`, `{{NEWS_ITEMS}}`, `{{ANTHROPIC_WATCH}}`, `{{BOLSILLO}}`, `{{EL_RESTO}}`, `{{DATE}}`, `{{DATE_ISO}}`, `{{TOTAL_COUNT}}`, `{{ARCHIVE_DATA}}`, `{{PRACTICAL_CONTENT}}`).
- `prompts/daily-pipeline.md` — el prompt completo. 13 pasos. Define voz, secciones, criterios de ranking, panel humano.
- `prompts/manual-run.md` — versión de debug manual.
- `scripts/run-daily.sh` — script bash que dispara launchd. Acepta fecha opcional para recuperar días perdidos: `bash scripts/run-daily.sh 2026-04-18`.
- `scripts/com.rodrigoramosaguirre.daily-ia-news.plist` — config de launchd.
- `scripts/sync-archive-data.py` — sincroniza el JS canónico de los HTML del histórico cada vez que se genera un día nuevo (para que el calendario lateral muestre todo el archivo).
- `archive/YYYY-MM-DD.html` — histórico permanente por día.
- `index.html` — home (apunta al último).
- `index-data.json` — metadata del histórico (fechas, titulares recientes, tesis por día).
- `logs/` — logs de cada corrida + logs de launchd.

## Panel humano (voices)

Las 21 voces NO producen noticias. Producen takes (que se citan en "El ángulo que nadie te va a dar") y señales tempranas (que alimentan Anthropic Watch y El Bolsillo). Si una voz no dijo nada relevante en 24h, no aparece. Cero relleno.

Cascada de fetch por voz:
1. Si tiene blog/RSS (Mollick, Willison, Lambert, Marcus, Zitron, Shipper, Karpathy, Chollet, Clark): WebFetch al RSS.
2. Si solo X: Nitter → xcancel → Google News con `"@handle"`.

## Roadmap de fases

- **Fase 1 (implementada 2026-04-25):** voz nueva + 5 secciones + panel humano + niveles A/B sin cuota fija.
- **Fase 2 (pendiente):** sumar **Cruces** rotativos (lunes-cruces / martes-Anthropic deep / miércoles-monetización / jueves-salud / viernes-deporte/cultura). Las obsesiones laterales son IA × Peñarol, IA × marihuana, IA × salud uruguaya, IA × monetización, IA × productividad personal.
- **Fase 3 (pendiente):** **La Pieza del viernes** — ensayo de 800 palabras hecho con Opus, deep-dive editorial sobre la noticia más importante.

## Gestión del cron (launchd)

El agente de launchd se llama `com.rodrigoramosaguirre.daily-ia-news`.

```bash
# Ver si está cargado (corriendo)
launchctl list | grep daily-ia-news

# Cargar (activar el cron)
launchctl load ~/Library/LaunchAgents/com.rodrigoramosaguirre.daily-ia-news.plist

# Descargar (pausar el cron)
launchctl unload ~/Library/LaunchAgents/com.rodrigoramosaguirre.daily-ia-news.plist

# Disparar manualmente (sin esperar las 7 AM)
launchctl start com.rodrigoramosaguirre.daily-ia-news

# Recargar después de cambiar el plist (ej. cambiar la hora)
launchctl unload ~/Library/LaunchAgents/com.rodrigoramosaguirre.daily-ia-news.plist
cp scripts/com.rodrigoramosaguirre.daily-ia-news.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.rodrigoramosaguirre.daily-ia-news.plist
```

## Correr el pipeline a mano

```bash
cd /Users/rodrigoramosaguirre/DAILY-IA-NEWS
bash scripts/run-daily.sh             # fecha de hoy
bash scripts/run-daily.sh 2026-04-18  # fecha específica (recuperar días)
```

Para regenerar un día que ya existe, primero borrá el archive:
```bash
rm /Users/rodrigoramosaguirre/DAILY-IA-NEWS/archive/2026-04-25.html
bash /Users/rodrigoramosaguirre/DAILY-IA-NEWS/scripts/run-daily.sh 2026-04-25
```

Output se loguea en `logs/run-YYYY-MM-DD.log`.

## Consideraciones de la Mac

**Importante:** launchd NO dispara si la Mac está apagada o durmiendo profundo.

- Si la Mac está **dormida** a las 7:00: el cron dispara al despertarla.
- Si la Mac está **apagada** a las 7:00: el cron NO dispara ese día.
- Si querés que la Mac se despierte sola a las 6:55:
  ```bash
  sudo pmset repeat wakeorpoweron MTWRFSU 06:55:00
  ```
  (Requiere contraseña de admin. Para cancelar: `sudo pmset repeat cancel`.)

## Debug

Si un día no generó dashboard, revisá:
```bash
# Log de la última corrida
ls -lt logs/run-*.log | head -1 | awk '{print $NF}' | xargs cat

# Log de launchd (por si el script ni siquiera arrancó)
cat logs/launchd.err.log
```

## Editar voz, fuentes o estructura

- **Cambiar tono o reglas editoriales:** `prompts/daily-pipeline.md` (sección "Voz editorial").
- **Sumar/sacar fuentes:** `config/sources.yaml > sources`.
- **Sumar/sacar voces del panel:** `config/sources.yaml > voices`.
- **Cambiar diseño visual:** `templates/base.html`.
- **Ajustar criterios de ranking:** `prompts/daily-pipeline.md` (Paso 5).

Los cambios toman efecto en la próxima corrida automática (o manual).
