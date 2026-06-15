# Daily IA News

Diario personal de IA generado todos los días a las 6:00 AM hora Uruguay. **No es un agregador**: es un medio con voz, opinión declarada, y secciones recurrentes con marca propia. Lector único: Rodrigo.

## Uso diario

- Leélo online en **`https://roraag.github.io/daily-ia-news/`** (GitHub Pages publica el último día).
- También está local en el VPS: `index.html` se actualiza después de cada corrida.
- El pipeline corre automático todos los días a las 6:00 AM (hora Uruguay) vía **cron en el VPS Hetzner** (`openclaw-rodri`) + claude CLI.
- **No hay envío directo** (Telegram / WhatsApp / mail): la única vía de lectura es la URL de GitHub Pages.

## Vistas

Cada página diaria muestra una sola vista: **Daily IA News**.

(La pestaña “IA Práctica” se eliminó: no generó valor sostenido.)

## Estructura editorial del diario

Cada día el medio publica 6 bloques:

1. **La tesis del día** — 2-4 oraciones que conectan las noticias del día en un hilo. Postura editorial declarada.
2. **Lo que importa hoy** (Nivel A) — 3-7 noticias con desarrollo completo: título con voz, "Lo que pasó" (hechos crudos), **"El ángulo que nadie te va a dar"** (opinión + cita al panel humano), **"Para vos"** (acción concreta para Rodrigo), botón **"Llevame a Claude con esto"** (copia un prompt pre-armado al portapapeles).
3. **Anthropic Watch** — sección fija dedicada a Anthropic. Posts del blog, jobs nuevos, takes de Dario / Krieger / Clark.
4. **El Bolsillo** — quién hizo plata hoy con IA. Bullets con actor + monto + lectura. Cierra con patrón de la semana.
5. **El resto** (Nivel B) — hasta 12 noticias menores con score ≥ 8, en una línea cada una, sin desarrollo. Para que nada con peso se pierda.
6. **Bitcoin Watch** — la única sección fuera de la IA. Pulso de mercado (precio, dominancia, Fear & Greed), señales de alt season y una noticia de fondo. Datos vía API con fuente; señales, nunca profecías.

**Sin cuota fija de noticias.** El editor (el prompt) decide cuántas entran a Nivel A según el día. Algunos días son 3 grandes + 8 breves, otros 7 grandes + 4 breves.

## Componentes

- `config/sources.yaml` — pool con tres bloques:
  - `sources` (~26 medios editoriales de IA: TechCrunch, MIT TR, STAT, HBR, Stratechery, Platformer, Lenny's, Xataka, Anthropic Blog/Engineering/Careers, etc.)
  - `voices` (panel humano de 21 personas en 3 paneles: 10 founders, 6 especialistas, 5 críticos)
  - `crypto` (medios cripto + endpoints de datos de mercado; alimenta solo Bitcoin Watch, NO entra al ranking de IA)
- `templates/base.html` — plantilla con placeholders (`{{TESIS_DIA}}`, `{{NEWS_ITEMS}}`, `{{ANTHROPIC_WATCH}}`, `{{BOLSILLO}}`, `{{EL_RESTO}}`, `{{BITCOIN_WATCH}}`, `{{DATE}}`, `{{DATE_ISO}}`, `{{TOTAL_COUNT}}`, `{{ARCHIVE_DATA}}`).
- `prompts/daily-pipeline.md` — el prompt completo. 13 pasos. Define voz, secciones, criterios de ranking, panel humano.
- `prompts/manual-run.md` — versión de debug manual.
- `scripts/run-daily-vps.sh` — **el activo**. Bash en VPS, locale `es_ES.UTF-8`, genera HTML, resumen, copia local + `git push` a GitHub Pages al final. Acepta fecha opcional: `bash scripts/run-daily-vps.sh 2026-04-18`.
- `scripts/run-daily.sh` y `scripts/com.rodrigoramosaguirre.daily-ia-news.plist` — **legacy Mac (launchd)**. Ya no se usan; quedan por referencia histórica.
- `scripts/sync-archive-data.py` — sincroniza el JS canónico de los HTML del histórico cada vez que se genera un día nuevo (para que el calendario lateral muestre todo el archivo).
- `archive/YYYY-MM-DD.html` — histórico permanente por día.
- `index.html` — home (apunta al último).
- `index-data.json` — metadata del histórico (fechas, titulares recientes, tesis por día).
- `logs/` — logs de cada corrida del cron VPS.

## Panel humano (voices)

Las 21 voces NO producen noticias. Producen takes (que se citan en "El ángulo que nadie te va a dar") y señales tempranas (que alimentan Anthropic Watch y El Bolsillo). Si una voz no dijo nada relevante en 24h, no aparece. Cero relleno.

Cascada de fetch por voz:
1. Si tiene blog/RSS (Mollick, Willison, Lambert, Marcus, Zitron, Shipper, Karpathy, Chollet, Clark): WebFetch al RSS.
2. Si solo X: Nitter → xcancel → Google News con `"@handle"`.

## Roadmap de fases

- **Fase 1 (implementada 2026-04-25):** voz nueva + 5 secciones + panel humano + niveles A/B sin cuota fija.
- **Fase 2 (pendiente):** sumar **Cruces** rotativos (lunes-cruces / martes-Anthropic deep / miércoles-monetización / jueves-salud / viernes-deporte/cultura). Las obsesiones laterales son IA × Peñarol, IA × marihuana, IA × salud uruguaya, IA × monetización, IA × productividad personal.
- **Fase 3 (pendiente):** **La Pieza del viernes** — ensayo de 800 palabras hecho con Opus, deep-dive editorial sobre la noticia más importante.

## Gestión del cron (VPS)

El cron del usuario `openclaw` en el VPS `openclaw-rodri` (Tailscale `100.113.124.21`) corre:

```
0 6 * * * /home/openclaw/DAILY-IA-NEWS/scripts/run-daily-vps.sh >> /home/openclaw/logs/cron-daily.log 2>&1
```

```bash
# Ver crontab actual
ssh openclaw@100.113.124.21 'crontab -l'

# Editar crontab (cambiar hora, pausar, etc.)
ssh openclaw@100.113.124.21 'crontab -e'

# Disparar manualmente (sin esperar las 6 AM)
ssh openclaw@100.113.124.21 'bash /home/openclaw/DAILY-IA-NEWS/scripts/run-daily-vps.sh'

# Pausar: comentar la línea en crontab, o vaciar crontab
```

## Correr el pipeline a mano

```bash
ssh openclaw@100.113.124.21
cd /home/openclaw/DAILY-IA-NEWS
bash scripts/run-daily-vps.sh             # fecha de hoy
bash scripts/run-daily-vps.sh 2026-04-18  # fecha específica (recuperar días)
```

Para regenerar un día que ya existe, primero borrá el archive:
```bash
rm /home/openclaw/DAILY-IA-NEWS/archive/2026-04-25.html
bash /home/openclaw/DAILY-IA-NEWS/scripts/run-daily-vps.sh 2026-04-25
```

Output se loguea en `logs/run-YYYY-MM-DD.log`.

## Distribución

El daily se publica en **GitHub Pages**: `https://roraag.github.io/daily-ia-news/` (actualizado automáticamente con cada `git push` desde el VPS, ~1-2 min después).

**No hay envío directo** por Telegram, WhatsApp o mail. Estaba habilitado vía `daily-ia-news-send.timer` (systemd user) hasta el 2026-05-09; desde esa fecha se discontinuó porque el flujo a GitHub Pages cubre la lectura cotidiana.

El VPS corre 24/7, así que el cron de las 6 AM nunca falla por máquina apagada (cosa que sí pasaba en la versión Mac vía launchd).

## Debug

Si un día no generó dashboard, revisá:
```bash
ssh openclaw@100.113.124.21
cd /home/openclaw/DAILY-IA-NEWS

# Log de la última corrida del pipeline
ls -lt logs/run-*.log | head -1 | awk '{print $NF}' | xargs cat

# Log del cron (por si el script ni siquiera arrancó)
tail -50 /home/openclaw/logs/cron-daily.log
```

## Editar voz, fuentes o estructura

- **Cambiar tono o reglas editoriales:** `prompts/daily-pipeline.md` (sección "Voz editorial").
- **Sumar/sacar fuentes:** `config/sources.yaml > sources`.
- **Sumar/sacar voces del panel:** `config/sources.yaml > voices`.
- **Cambiar diseño visual:** `templates/base.html`.
- **Ajustar criterios de ranking:** `prompts/daily-pipeline.md` (Paso 5).

Los cambios toman efecto en la próxima corrida automática (o manual).
