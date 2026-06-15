# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Qué es este proyecto

Daily IA News no es una aplicación tradicional: es un **diario personal de IA generado por Claude todos los días**. El "código" es principalmente el prompt en `prompts/daily-pipeline.md` invocado vía `claude --print` desde un script bash. La mayoría de los cambios de comportamiento se hacen editando el prompt, no Python/JS.

Lector único: Rodrigo. Idioma: español rioplatense. Sin emojis. Sin tú/aquí. Reglas de voz completas en `prompts/daily-pipeline.md` y `README.md`.

## Dónde vive el proyecto

Solo dos lugares (la copia local de Mac fue eliminada el 2026-05-06):

- **Producción**: `/home/openclaw/DAILY-IA-NEWS` en `openclaw-rodri` (VPS Hetzner, accesible vía Tailscale `100.113.124.21`). Acá corre el cron diario, se genera el HTML y se pushea a GitHub. Acceso: `ssh openclaw@100.113.124.21`.
- **GitHub**: `https://github.com/roraag/daily-ia-news` (público). Espejo del server, actualizado por el cron al final de cada corrida.

**No hay copia local de desarrollo.** Para editar:
- Cambios chicos: `ssh openclaw@100.113.124.21` y editar directo con vim.
- Cambios grandes: `git clone git@github.com:roraag/daily-ia-news.git` en cualquier máquina, editar, `git push`, después `ssh openclaw@100.113.124.21 'cd /home/openclaw/DAILY-IA-NEWS && git pull'` para que el server tenga la versión nueva antes de la próxima corrida.

## Publicación: GitHub Pages

- URL pública: **`https://roraag.github.io/daily-ia-news/`** (sirve `index.html` = último día)
- Días anteriores: `https://roraag.github.io/daily-ia-news/archive/YYYY-MM-DD.html`
- El push se hace **desde el server** al final de `run-daily-vps.sh`, vía deploy key SSH (`~/.ssh/daily-ia-news-deploy` en el server, configurada en `~/.ssh/config` como `github.com-daily-ia-news`).
- Pages publica automáticamente 1-2 min después del push.

## Schedulers en el server

| Tarea | Mecanismo | Hora UYT |
|---|---|---|
| Genera el día (Claude + push a GitHub) | `cron` user `openclaw` → `scripts/run-daily-vps.sh` | 6:00 AM |

**No hay envío directo del daily** (Telegram / WhatsApp / mail). Hasta 2026-05-09 había un envío por Telegram via systemd user timer `daily-ia-news-send.timer` + script `/home/openclaw/scripts/daily-ia-news-send.sh` (bot `@rodri_pa_bot`), pero se discontinuó porque la lectura cotidiana se hace por GitHub Pages. El timer está `disabled`; el script queda en disco pero no se ejecuta. Para reactivarlo: re-enable el timer y verificar que el token en `~/secrets/telegram.yaml` sigue válido.

## Scripts en `scripts/`

- `run-daily-vps.sh` — **el activo**. Linux, locale `es_ES.UTF-8`, copia output a `/home/openclaw/daily-ia-news/` (espejo local para que Lucho/Hermes lo pueda leer si hace falta), hace `git push` a GitHub al final.
- `sync-archive-data.py` — actualiza el JS `ARCHIVE_DATA` en TODOS los HTML del histórico cada vez que se genera un día nuevo (para que el calendario lateral muestre todos los días). El JS canónico de este script DEBE matchear el del template — si tocás `templates/base.html`, tocá este script también.
- `run-daily.sh` y `com.rodrigoramosaguirre.daily-ia-news.plist` — **legacy Mac**, ya no se usan. Quedan en el repo por referencia histórica; se pueden eliminar.

## Comandos comunes (todos vía SSH al server)

```bash
# Disparar manualmente la corrida (fecha de hoy)
ssh openclaw@100.113.124.21 'bash /home/openclaw/DAILY-IA-NEWS/scripts/run-daily-vps.sh'

# Regenerar un día específico
ssh openclaw@100.113.124.21 'rm -f /home/openclaw/DAILY-IA-NEWS/archive/2026-05-06.html && bash /home/openclaw/DAILY-IA-NEWS/scripts/run-daily-vps.sh 2026-05-06'

# Ver log de la última corrida
ssh openclaw@100.113.124.21 'tail -50 /home/openclaw/DAILY-IA-NEWS/logs/run-$(date +%Y-%m-%d).log'

# Ver crontab activo
ssh openclaw@100.113.124.21 'crontab -l'

# Pull rápido en el server después de pushear cambios desde otra máquina
ssh openclaw@100.113.124.21 'cd /home/openclaw/DAILY-IA-NEWS && git pull'
```

## Arquitectura del pipeline (cómo se genera un día)

`run-daily-vps.sh` ejecuta esta cadena:

1. **Idempotencia**: si `archive/YYYY-MM-DD.html` ya existe, sale sin hacer nada.
2. **Llamada a Claude**: `claude --print --model sonnet` con `prompts/daily-pipeline.md` + header con paths absolutos. Claude tiene `Read Write Edit Bash Glob Grep WebFetch WebSearch` permitidos. Lee `config/sources.yaml`, fetchea, rankea, genera HTML usando `templates/base.html` con 10 placeholders (`{{TESIS_DIA}}`, `{{NEWS_ITEMS}}`, `{{ANTHROPIC_WATCH}}`, `{{BOLSILLO}}`, `{{EL_RESTO}}`, `{{BITCOIN_WATCH}}`, `{{DATE}}`, `{{DATE_ISO}}`, `{{TOTAL_COUNT}}`, `{{ARCHIVE_DATA}}`).
3. **Sync archive data**: `scripts/sync-archive-data.py` actualiza el JS `ARCHIVE_DATA` en TODOS los HTML del histórico.
4. **Resumen ejecutivo**: segunda llamada a Claude que lee el HTML del día y genera `archive/resumen-YYYY-MM-DD.txt` plano de 5-7 líneas. Originalmente para Telegram; hoy queda como artefacto disponible (lo puede leer Lucho si se lo pedís por WhatsApp / Telegram desde Hermes).
5. **Copia local**: HTML + resumen se copian a `/home/openclaw/daily-ia-news/` (espejo accesible localmente, fuera del repo git).
6. **Git push**: commit con mensaje `Daily: YYYY-MM-DD` y push a `origin main` → trigger automático de GitHub Pages (`https://roraag.github.io/daily-ia-news/`, ~1-2 min de latencia).

## Cascadas de fetch (definidas en el prompt)

Para fuentes (`sources`):
1. RSS directo si existe → 2. Google News RSS `site:DOMINIO AI when:1d` → 3. WebSearch.

Para voces del panel humano (`voices`):
1. RSS de blog/Substack si existe → 2. Si solo X: `nitter.net/HANDLE/rss` → `xcancel.com/HANDLE/rss` → Google News con `"@handle"`. Si los 3 fallan, voz silenciada hoy (cero relleno).

## Niveles A y B (sin cuota fija)

- **Nivel A** ("Lo que importa hoy"): score ≥ 12. Sin mínimo ni máximo rígido. Típicamente 3-7 noticias.
- **Nivel B** ("El resto"): score ≥ 8, cap 12. Una línea cada uno. Si hay menos de 3, omitir la sección entera (placeholder vacío).

## Deduplicación

`index-data.json` mantiene `recent_titles[]` con titulares de los últimos 7 días. El prompt los usa para no repetir noticias. Si tocás esa lógica, mirá tanto el prompt (paso de dedup) como `sync-archive-data.py`.

## Reglas no negociables al editar el template

- **Nunca usar f-strings de Python para embeber JavaScript** en HTML generado. Concatenación de strings o template engines (Jinja2). Los f-strings rompen la sintaxis JS con llaves dobles.
- HTML siempre **autocontenido**: CSS y JS inline, sin assets externos (excepto fonts).
- El JS de `templates/base.html` y de `scripts/sync-archive-data.py` deben estar **sincronizados byte-a-byte** en el bloque que maneja `ARCHIVE_DATA` y el botón "Llevame a Claude".

## Antes de declarar "listo" un cambio en el HTML

Correr `/dashboard-check <path>` (skill) — valida JS, IDs duplicados, contraste, canvas duplicados, e inventario de tabs/KPIs/charts.

## Archivos ignorables

`extracted/`, `logs/`, `*.zip`, `.claude/logs/`, `.DS_Store` están en `.gitignore`. `docs/superpowers/` son notas de skills/specs, no son parte del pipeline. El zip de WhatsApp en raíz es histórico.
