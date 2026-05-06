# Daily IA News Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construir un dashboard HTML local autocontenido que se actualiza cada día a las 7:00 AM Uruguay con 5-7 noticias curadas de IA desde ~20 fuentes diversificadas, ejecutándose vía scheduled task nativo de Claude Code.

**Architecture:** No hay backend ni API externa. Todo corre dentro de Claude Code: un scheduled task dispara un prompt fijo que lee `sources.yaml`, usa `WebFetch`/`WebSearch` para juntar candidatos, los rankea, y escribe un HTML por día en `archive/`. El `index.html` siempre muestra el último. Histórico permanente navegable vía `index-data.json` + sidebar calendario.

**Tech Stack:** YAML (config de fuentes), HTML/CSS/JS vanilla (dashboard), JSON (metadata del histórico), Markdown (prompt del pipeline), Scheduled Tasks de Claude Code (cron), herramientas nativas `WebFetch` / `WebSearch`.

---

## File Structure

Archivos que vamos a crear o modificar:

| Ruta | Responsabilidad |
|---|---|
| `config/sources.yaml` | Lista de ~20 fuentes con URL, categoría, peso, idioma. Única fuente de verdad del pool. |
| `templates/base.html` | Plantilla HTML del dashboard (estructura, estilos inline, JS mínimo). Se copia a cada `archive/YYYY-MM-DD.html`. |
| `prompts/daily-pipeline.md` | Prompt que el scheduled task le pasa a Claude: instrucciones para leer, fetchear, rankear, escribir. |
| `prompts/manual-run.md` | Versión del prompt que Rodrigo puede disparar a mano para debuggear (idéntico al diario pero sin el wrapper de scheduled task). |
| `archive/YYYY-MM-DD.html` | Output diario. Un archivo por día, histórico permanente. |
| `index.html` | Home del dashboard. Carga el último día (via fetch de `archive/` + lectura de `index-data.json`). |
| `index-data.json` | Metadata del histórico: lista de fechas disponibles, metadata por día (# noticias, fuentes usadas). Lo lee la sidebar-calendario. |
| `README.md` | Instrucciones para Rodrigo: cómo correr el pipeline a mano, cómo ajustar fuentes, cómo ver logs del scheduled task. |

---

## Task 1: Inicializar estructura del proyecto

**Files:**
- Create: `config/`
- Create: `templates/`
- Create: `prompts/`
- Create: `archive/`
- Create: `README.md`
- Create: `.gitignore`

- [ ] **Step 1: Crear la estructura de carpetas**

```bash
cd /Users/rodrigoramosaguirre/DAILY-IA-NEWS
mkdir -p config templates prompts archive
```

- [ ] **Step 2: Verificar que las carpetas existen**

```bash
ls -la /Users/rodrigoramosaguirre/DAILY-IA-NEWS
```
Expected: ver `config/`, `templates/`, `prompts/`, `archive/`, `docs/` listados.

- [ ] **Step 3: Crear `.gitignore` (por si después se inicializa git)**

Contenido de `/Users/rodrigoramosaguirre/DAILY-IA-NEWS/.gitignore`:
```
.DS_Store
extracted/
*.zip
.claude/logs/
```

- [ ] **Step 4: Crear README.md mínimo**

Contenido de `/Users/rodrigoramosaguirre/DAILY-IA-NEWS/README.md`:
```markdown
# Daily IA News

Dashboard local diario con noticias de IA curadas por Claude Code.

## Uso

- Abrí `index.html` en cualquier navegador. Siempre muestra el último día.
- El pipeline corre automático todos los días a las 7:00 AM (hora Uruguay).

## Componentes

- `config/sources.yaml` — pool de fuentes. Editá para sumar/sacar.
- `templates/base.html` — plantilla del dashboard.
- `prompts/daily-pipeline.md` — prompt del scheduled task.
- `prompts/manual-run.md` — para correr a mano en debug.
- `archive/YYYY-MM-DD.html` — histórico por día.
- `index.html` — home (apunta al último).
- `index-data.json` — metadata del histórico.

## Correr a mano

En una sesión de Claude Code, pegá el contenido de `prompts/manual-run.md`.
```

- [ ] **Step 5: Verificar estructura final**

```bash
ls -la /Users/rodrigoramosaguirre/DAILY-IA-NEWS
```
Expected: ver todos los archivos y carpetas nuevos.

---

## Task 2: Definir `config/sources.yaml`

**Files:**
- Create: `config/sources.yaml`

- [ ] **Step 1: Escribir el archivo con las 20 fuentes del spec**

Contenido de `/Users/rodrigoramosaguirre/DAILY-IA-NEWS/config/sources.yaml`:

```yaml
# Pool de fuentes para Daily IA News
# Categorías: tech | business | health
# Peso: 1 (básico) a 3 (alta prioridad). Pondera en el ranking.
# Language: en | es

sources:
  # ===== TECH / IA GENERAL (~40%) =====
  - name: TechCrunch AI
    url: https://techcrunch.com/category/artificial-intelligence/
    rss: https://techcrunch.com/category/artificial-intelligence/feed/
    category: tech
    weight: 2
    language: en

  - name: The Verge AI
    url: https://www.theverge.com/ai-artificial-intelligence
    rss: https://www.theverge.com/rss/ai-artificial-intelligence/index.xml
    category: tech
    weight: 2
    language: en

  - name: Ars Technica
    url: https://arstechnica.com/ai/
    rss: https://feeds.arstechnica.com/arstechnica/technology-lab
    category: tech
    weight: 2
    language: en

  - name: MIT Technology Review
    url: https://www.technologyreview.com/topic/artificial-intelligence/
    rss: https://www.technologyreview.com/feed/
    category: tech
    weight: 3
    language: en

  - name: VentureBeat AI
    url: https://venturebeat.com/category/ai/
    rss: https://venturebeat.com/category/ai/feed/
    category: tech
    weight: 2
    language: en

  - name: Anthropic Blog
    url: https://www.anthropic.com/news
    rss: https://www.anthropic.com/news/rss.xml
    category: tech
    weight: 3
    language: en

  - name: OpenAI Blog
    url: https://openai.com/blog
    rss: https://openai.com/blog/rss.xml
    category: tech
    weight: 3
    language: en

  - name: Google DeepMind
    url: https://deepmind.google/discover/blog/
    rss: https://deepmind.google/blog/rss.xml
    category: tech
    weight: 3
    language: en

  - name: Hugging Face Blog
    url: https://huggingface.co/blog
    rss: https://huggingface.co/blog/feed.xml
    category: tech
    weight: 2
    language: en

  - name: Import AI (Jack Clark)
    url: https://importai.substack.com/
    rss: https://importai.substack.com/feed
    category: tech
    weight: 3
    language: en

  - name: TLDR AI
    url: https://tldr.tech/ai
    rss: null  # no tienen RSS público; usar WebFetch sobre la home
    category: tech
    weight: 2
    language: en

  # ===== NEGOCIO / IA APLICADA (~30%) =====
  - name: Harvard Business Review - AI
    url: https://hbr.org/topic/artificial-intelligence
    rss: null
    category: business
    weight: 3
    language: en

  - name: MIT Sloan Management Review
    url: https://sloanreview.mit.edu/topic/artificial-intelligence/
    rss: https://sloanreview.mit.edu/feed/
    category: business
    weight: 3
    language: en

  - name: Andreessen Horowitz (a16z)
    url: https://a16z.com/ai/
    rss: https://a16z.com/feed/
    category: business
    weight: 2
    language: en

  - name: Stratechery
    url: https://stratechery.com/
    rss: https://stratechery.com/feed/
    category: business
    weight: 3
    language: en

  - name: McKinsey Insights - AI
    url: https://www.mckinsey.com/capabilities/quantumblack/our-insights
    rss: null
    category: business
    weight: 2
    language: en

  - name: The Information
    url: https://www.theinformation.com/
    rss: null  # paywall fuerte; sólo accesible preview + newsletter público
    category: business
    weight: 2
    language: en
    notes: paywall

  # ===== IA EN SALUD (~30%) =====
  - name: STAT News - Health Tech
    url: https://www.statnews.com/category/health-tech/
    rss: https://www.statnews.com/category/health-tech/feed/
    category: health
    weight: 3
    language: en

  - name: Fierce Healthcare
    url: https://www.fiercehealthcare.com/ai-and-machine-learning
    rss: https://www.fiercehealthcare.com/rss/xml
    category: health
    weight: 2
    language: en

  - name: NEJM AI
    url: https://ai.nejm.org/
    rss: null
    category: health
    weight: 3
    language: en

  - name: Healthcare IT News
    url: https://www.healthcareitnews.com/taxonomy/term/23086
    rss: https://www.healthcareitnews.com/home/feed
    category: health
    weight: 2
    language: en

  - name: MobiHealthNews
    url: https://www.mobihealthnews.com/
    rss: https://www.mobihealthnews.com/feed
    category: health
    weight: 2
    language: en
```

- [ ] **Step 2: Validar que el YAML parsea correctamente**

```bash
cd /Users/rodrigoramosaguirre/DAILY-IA-NEWS
python3 -c "import yaml; data = yaml.safe_load(open('config/sources.yaml')); print(f'OK: {len(data[\"sources\"])} fuentes cargadas')"
```
Expected: `OK: 22 fuentes cargadas` (o número similar; si falla por `yaml` no instalado, instalar con `pip install pyyaml` o validar abriendo el archivo a ojo).

- [ ] **Step 3: Verificar distribución por categoría**

```bash
python3 -c "
import yaml
from collections import Counter
data = yaml.safe_load(open('/Users/rodrigoramosaguirre/DAILY-IA-NEWS/config/sources.yaml'))
print(Counter(s['category'] for s in data['sources']))
"
```
Expected: algo como `Counter({'tech': 11, 'business': 6, 'health': 5})`. Si la distribución está muy desbalanceada (ej. health con 2 solas fuentes), revisar y ajustar el YAML.

---

## Task 3: Crear `templates/base.html` (plantilla del dashboard)

**Files:**
- Create: `templates/base.html`

Esta plantilla es el esqueleto HTML con CSS y JS inline. El pipeline diario la copia a `archive/YYYY-MM-DD.html` sustituyendo los placeholders `{{DATE}}`, `{{NEWS_ITEMS}}`, `{{ARCHIVE_DATA}}`, `{{TOTAL_COUNT}}`.

- [ ] **Step 1: Escribir el HTML base completo**

Contenido de `/Users/rodrigoramosaguirre/DAILY-IA-NEWS/templates/base.html`:

```html
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Daily IA News — {{DATE}}</title>
<style>
  :root {
    --bg: #fdfcf8;
    --fg: #1a1a1a;
    --muted: #666;
    --border: #e5e5e0;
    --accent: #2952a3;
    --tag-tech: #2952a3;
    --tag-business: #6b4a1f;
    --tag-health: #1e6e3a;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --bg: #1a1a1a;
      --fg: #e8e8e4;
      --muted: #999;
      --border: #333;
      --accent: #7fa8d9;
      --tag-tech: #7fa8d9;
      --tag-business: #c9a876;
      --tag-health: #7fc998;
    }
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    background: var(--bg);
    color: var(--fg);
    font-size: 18px;
    line-height: 1.6;
    display: grid;
    grid-template-columns: 240px 1fr;
    min-height: 100vh;
  }
  body.sidebar-collapsed { grid-template-columns: 0 1fr; }
  aside {
    border-right: 1px solid var(--border);
    padding: 1.5rem 1rem;
    overflow: hidden;
    transition: all 0.2s;
  }
  aside h2 { font-size: 0.85rem; text-transform: uppercase; color: var(--muted); letter-spacing: 0.05em; margin-bottom: 0.75rem; }
  .calendar-nav { display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.5rem; }
  .calendar-nav button { background: none; border: none; color: var(--muted); cursor: pointer; font-size: 1rem; }
  .calendar-grid { display: grid; grid-template-columns: repeat(7, 1fr); gap: 2px; font-size: 0.85rem; }
  .calendar-grid .day { aspect-ratio: 1; display: flex; align-items: center; justify-content: center; color: var(--muted); border-radius: 3px; }
  .calendar-grid .day.has-news { color: var(--fg); font-weight: 600; cursor: pointer; }
  .calendar-grid .day.has-news:hover { background: var(--border); }
  .calendar-grid .day.today { outline: 2px solid var(--accent); }
  .calendar-grid .dow { color: var(--muted); font-size: 0.7rem; text-transform: uppercase; }
  main { padding: 2rem 3rem; max-width: 780px; }
  header { margin-bottom: 2.5rem; display: flex; flex-direction: column; gap: 1rem; }
  .title { font-family: "IBM Plex Serif", Georgia, serif; font-size: 2rem; font-weight: 600; }
  .date { color: var(--muted); font-size: 1rem; }
  .controls { display: flex; gap: 0.5rem; flex-wrap: wrap; }
  .chip {
    padding: 0.4rem 0.8rem;
    border: 1px solid var(--border);
    border-radius: 20px;
    background: none;
    color: var(--fg);
    cursor: pointer;
    font-size: 0.85rem;
  }
  .chip.active { background: var(--accent); color: white; border-color: var(--accent); }
  .news-list { display: flex; flex-direction: column; }
  .news-item { padding: 1.5rem 0; border-bottom: 1px solid var(--border); cursor: pointer; }
  .news-item:last-child { border-bottom: none; }
  .news-header { display: flex; gap: 1rem; align-items: baseline; }
  .news-number { font-family: "IBM Plex Serif", Georgia, serif; color: var(--muted); font-size: 1.1rem; min-width: 2rem; }
  .news-title-wrap { flex: 1; }
  .news-title { font-family: "IBM Plex Serif", Georgia, serif; font-size: 1.35rem; font-weight: 600; line-height: 1.3; }
  .news-tag { display: inline-block; font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.05em; margin-left: 0.5rem; font-weight: 500; }
  .news-tag.tech { color: var(--tag-tech); }
  .news-tag.business { color: var(--tag-business); }
  .news-tag.health { color: var(--tag-health); }
  .news-summary { color: var(--muted); margin-top: 0.5rem; font-size: 1rem; }
  .news-detail { display: none; margin-top: 1rem; padding-left: 3rem; }
  .news-item.expanded .news-detail { display: block; }
  .news-detail h4 { font-size: 0.8rem; text-transform: uppercase; color: var(--muted); letter-spacing: 0.05em; margin-top: 1rem; margin-bottom: 0.4rem; }
  .news-detail h4:first-child { margin-top: 0; }
  .news-detail ul { padding-left: 1.2rem; }
  .news-detail li { margin-bottom: 0.3rem; }
  .news-detail .source-link { color: var(--accent); text-decoration: none; font-size: 0.9rem; }
  .news-detail .source-link:hover { text-decoration: underline; }
  footer { margin-top: 3rem; padding-top: 1.5rem; border-top: 1px solid var(--border); color: var(--muted); font-size: 0.85rem; }
  @media (max-width: 800px) {
    body { grid-template-columns: 1fr; }
    aside { display: none; }
    main { padding: 1.5rem 1rem; }
  }
</style>
</head>
<body>

<aside>
  <h2>Histórico</h2>
  <div class="calendar-nav">
    <button id="prev-month">‹</button>
    <span id="calendar-title">Abril 2026</span>
    <button id="next-month">›</button>
  </div>
  <div class="calendar-grid" id="calendar"></div>
</aside>

<main>
  <header>
    <div>
      <div class="title">Daily IA News</div>
      <div class="date">{{DATE}}</div>
    </div>
    <div class="controls">
      <button class="chip active" data-filter="all">Todos</button>
      <button class="chip" data-filter="tech">Tech</button>
      <button class="chip" data-filter="business">Negocio</button>
      <button class="chip" data-filter="health">Salud</button>
      <button class="chip" id="toggle-sidebar" style="margin-left: auto;">📅</button>
    </div>
  </header>

  <div class="news-list" id="news-list">
    {{NEWS_ITEMS}}
  </div>

  <footer>
    {{TOTAL_COUNT}} noticias curadas. Dashboard generado por Claude Code.
  </footer>
</main>

<script>
  const ARCHIVE_DATA = {{ARCHIVE_DATA}};
  const TODAY_ISO = "{{DATE_ISO}}";

  document.querySelectorAll('.news-item').forEach(item => {
    item.addEventListener('click', () => item.classList.toggle('expanded'));
  });

  document.querySelectorAll('.chip[data-filter]').forEach(chip => {
    chip.addEventListener('click', () => {
      document.querySelectorAll('.chip[data-filter]').forEach(c => c.classList.remove('active'));
      chip.classList.add('active');
      const filter = chip.dataset.filter;
      document.querySelectorAll('.news-item').forEach(item => {
        item.style.display = (filter === 'all' || item.dataset.category === filter) ? '' : 'none';
      });
    });
  });

  document.getElementById('toggle-sidebar').addEventListener('click', () => {
    document.body.classList.toggle('sidebar-collapsed');
  });

  let currentMonth = new Date(TODAY_ISO);
  function renderCalendar(date) {
    const year = date.getFullYear();
    const month = date.getMonth();
    document.getElementById('calendar-title').textContent =
      date.toLocaleDateString('es-UY', { month: 'long', year: 'numeric' });
    const firstDay = new Date(year, month, 1).getDay();
    const daysInMonth = new Date(year, month + 1, 0).getDate();
    const grid = document.getElementById('calendar');
    grid.innerHTML = '';
    ['D','L','M','M','J','V','S'].forEach(d => {
      const el = document.createElement('div');
      el.className = 'dow';
      el.textContent = d;
      grid.appendChild(el);
    });
    for (let i = 0; i < firstDay; i++) {
      const el = document.createElement('div');
      el.className = 'day';
      grid.appendChild(el);
    }
    for (let d = 1; d <= daysInMonth; d++) {
      const el = document.createElement('div');
      el.className = 'day';
      el.textContent = d;
      const iso = `${year}-${String(month+1).padStart(2,'0')}-${String(d).padStart(2,'0')}`;
      if (ARCHIVE_DATA.dates && ARCHIVE_DATA.dates.includes(iso)) {
        el.classList.add('has-news');
        el.addEventListener('click', () => window.location.href = `archive/${iso}.html`);
      }
      if (iso === TODAY_ISO) el.classList.add('today');
      grid.appendChild(el);
    }
  }
  document.getElementById('prev-month').addEventListener('click', () => {
    currentMonth.setMonth(currentMonth.getMonth() - 1);
    renderCalendar(currentMonth);
  });
  document.getElementById('next-month').addEventListener('click', () => {
    currentMonth.setMonth(currentMonth.getMonth() + 1);
    renderCalendar(currentMonth);
  });
  renderCalendar(currentMonth);
</script>
</body>
</html>
```

- [ ] **Step 2: Verificar que el HTML renderiza sin datos aún**

Crear un archivo de prueba temporal con placeholders sustituidos a mano por valores dummy:

```bash
cd /Users/rodrigoramosaguirre/DAILY-IA-NEWS
cp templates/base.html /tmp/test-render.html
sed -i '' 's|{{DATE}}|jueves 17 de abril de 2026|g; s|{{DATE_ISO}}|2026-04-17|g; s|{{NEWS_ITEMS}}|<div class="news-item" data-category="tech"><div class="news-header"><div class="news-number">1</div><div class="news-title-wrap"><div class="news-title">Ejemplo de noticia <span class="news-tag tech">Tech</span></div><div class="news-summary">Este es un resumen de ejemplo para probar el render.</div></div></div><div class="news-detail"><h4>Qué pasó</h4><ul><li>Punto uno.</li><li>Punto dos.</li></ul><h4>Por qué importa</h4><p>Explicación corta.</p><h4>Para quién</h4><p>PMs evaluando adopción.</p><h4>Fuente</h4><a class="source-link" href="#">techcrunch.com</a></div></div>|g; s|{{ARCHIVE_DATA}}|{"dates": ["2026-04-17"]}|g; s|{{TOTAL_COUNT}}|1|g' /tmp/test-render.html
open /tmp/test-render.html
```
Expected: se abre en el navegador y se ve: header, sidebar-calendario con el día 17 marcado, una noticia clickeable que expande al click, filtros funcionales.

- [ ] **Step 3: Ajustar cualquier issue visual que notes**

Issues típicos a chequear:
- ¿La tipografía se ve bien en claro y oscuro?
- ¿El calendario renderiza el día de hoy destacado?
- ¿Los filtros de categoría filtran correctamente?
- ¿El toggle de sidebar funciona?

Si hay algún bug, editá `templates/base.html` y repetí el paso 2.

- [ ] **Step 4: Borrar el archivo de prueba**

```bash
rm /tmp/test-render.html
```

---

## Task 4: Escribir el prompt del pipeline (`prompts/daily-pipeline.md`)

**Files:**
- Create: `prompts/daily-pipeline.md`
- Create: `prompts/manual-run.md`

- [ ] **Step 1: Escribir el prompt principal del pipeline**

Contenido de `/Users/rodrigoramosaguirre/DAILY-IA-NEWS/prompts/daily-pipeline.md`:

````markdown
# Daily IA News Pipeline

Soy un scheduled task. Son las 7:00 AM Uruguay y tengo que generar el dashboard del día.

## Paso 1: Leer config

Leé `/Users/rodrigoramosaguirre/DAILY-IA-NEWS/config/sources.yaml`. Tenés ~20 fuentes con: name, url, rss, category (tech|business|health), weight (1-3), language.

## Paso 2: Fetch candidatos

Para cada fuente:
- Si tiene `rss` no-null: usá `WebFetch` sobre la URL del RSS y parseá los items recientes (últimas 24h).
- Si `rss` es null: usá `WebFetch` sobre la URL del site + `WebSearch` con query `"site:DOMINIO últimas 24 horas inteligencia artificial"`.
- Si una fuente falla, loguealo ("Fuente X no disponible") y continuá.

Objetivo: juntar 40-60 candidatos con title, url, source, category, published_date, excerpt.

## Paso 3: Filtrar

Descartá candidatos que:
- No sean de las últimas 24h.
- No mencionen IA, modelos, LLM, machine learning, AI, agente, redes neuronales, etc. (para fuentes generalistas como Ars Technica o HBR que cubren muchos temas).
- Ya aparecieron en días anteriores (chequeá `/Users/rodrigoramosaguirre/DAILY-IA-NEWS/index-data.json` — campo `recent_titles`, últimos 7 días).

## Paso 4: Rankear y elegir 5-7

Para cada candidato calculá un score:

```
score = magnitud * 2 + relevancia_tematica * 1.5 + weight_fuente + diversidad_bonus
```

- **magnitud (1-5):** lanzamiento de modelo frontier o anuncio corporate grande = 5; release de tool chico o rumor = 1.
- **relevancia_tematica (1-5):** fit con tech/business/health, y dentro, con intereses de PM/salud/mutualismo.
- **weight_fuente:** el `weight` del YAML (1-3).
- **diversidad_bonus (0 o 2):** +2 si ninguna noticia del top tiene ese dominio; 0 si ya hay 1; −10 si ya hay 2 (efectivamente descarta).

Ordená por score descendente. Elegí las 5-7 top **respetando la regla de diversidad**: máximo 2 noticias del mismo dominio. Si al elegir top 5-7 te queda una categoría sin representación, forzá al menos 1 de cada categoría (tech/business/health), reemplazando la noticia de peor score de la categoría sobrerepresentada.

**Caso especial:** si después de filtrar hay menos de 5 candidatos válidos, usá lo que haya y agregá en el footer: "Día tranquilo en IA, X noticias hoy".

## Paso 5: Generar resúmenes en español rioplatense

Para cada noticia elegida, generá:
- **title_es:** título en español rioplatense, directo, sin clickbait. Máx 12 palabras.
- **summary:** 1 línea (máx 20 palabras) que resume qué pasó.
- **what_happened:** 2-3 bullets con los hechos clave.
- **why_matters:** 1-2 líneas sobre por qué esta noticia importa.
- **for_whom:** etiqueta descriptiva de audiencia (ej. "para PMs evaluando adopción de IA"). NO opinión ni recomendación.
- **source_url:** URL original.
- **source_domain:** dominio de la fuente (ej. "techcrunch.com").
- **category:** tech | business | health (del YAML).

Tono: vos/te, conciso, sin jerga innecesaria, sin emojis en el resumen (los emojis son de Marcello, no nuestros).

## Paso 6: Generar el HTML del día

1. Leé `/Users/rodrigoramosaguirre/DAILY-IA-NEWS/templates/base.html`.
2. Sustituí los placeholders:
   - `{{DATE}}` → fecha en español, ej. "jueves 17 de abril de 2026".
   - `{{DATE_ISO}}` → "2026-04-17".
   - `{{TOTAL_COUNT}}` → número de noticias (5-7).
   - `{{NEWS_ITEMS}}` → HTML generado para cada noticia (ver template abajo).
   - `{{ARCHIVE_DATA}}` → JSON con todas las fechas disponibles (leé `index-data.json` y agregá la de hoy).

Template por noticia:
```html
<div class="news-item" data-category="{category}">
  <div class="news-header">
    <div class="news-number">{n}</div>
    <div class="news-title-wrap">
      <div class="news-title">{title_es} <span class="news-tag {category}">{Tech|Negocio|Salud}</span></div>
      <div class="news-summary">{summary}</div>
    </div>
  </div>
  <div class="news-detail">
    <h4>Qué pasó</h4>
    <ul>{bullets}</ul>
    <h4>Por qué importa</h4>
    <p>{why_matters}</p>
    <h4>Para quién</h4>
    <p>{for_whom}</p>
    <h4>Fuente</h4>
    <a class="source-link" href="{source_url}" target="_blank">{source_domain}</a>
  </div>
</div>
```

3. Escribí el resultado en `/Users/rodrigoramosaguirre/DAILY-IA-NEWS/archive/YYYY-MM-DD.html` (fecha de hoy).

## Paso 7: Actualizar `index.html` e `index-data.json`

1. Copiá el contenido que acabás de generar también a `/Users/rodrigoramosaguirre/DAILY-IA-NEWS/index.html` (así la home siempre muestra el último día).
2. Actualizá `index-data.json`:
   - Agregá la fecha de hoy al array `dates`.
   - Agregá los titulares de hoy al campo `recent_titles` (mantené sólo los últimos 7 días para el chequeo de novedad del paso 3).
   - Agregá una entrada a `days` con metadata: fecha, # noticias, fuentes usadas.

Si `index-data.json` no existe, creá uno con estructura:
```json
{
  "dates": ["2026-04-17"],
  "recent_titles": ["Título 1", "Título 2", ...],
  "days": {
    "2026-04-17": {
      "count": 6,
      "sources": ["techcrunch.com", "statnews.com", ...]
    }
  }
}
```

## Paso 8: Loguear resultado

Imprimí un resumen:
```
✅ Dashboard generado: archive/2026-04-17.html
📰 6 noticias: 3 tech, 2 business, 1 health
🌐 Fuentes usadas: techcrunch.com, arstechnica.com, stratechery.com, statnews.com, anthropic.com
⚠️  Fuentes sin respuesta: [lista]
```

Fin.
````

- [ ] **Step 2: Escribir `prompts/manual-run.md` (para debugging)**

Contenido de `/Users/rodrigoramosaguirre/DAILY-IA-NEWS/prompts/manual-run.md`:

```markdown
# Daily IA News - Corrida Manual

Vas a correr el pipeline de Daily IA News a mano. Seguí exactamente las instrucciones de `/Users/rodrigoramosaguirre/DAILY-IA-NEWS/prompts/daily-pipeline.md`.

La fecha de hoy es: [ESCRIBÍ LA FECHA DE HOY EN FORMATO YYYY-MM-DD ACÁ, ej. 2026-04-17].

Al final, en lugar de solo loguear, mostrame:
1. La lista de candidatos que juntaste (source, title, score).
2. La selección final con sus scores.
3. El contenido de los 5-7 resúmenes en español.
4. Confirmación de que archivos se escribieron.

Esto es para debug: quiero ver tu trabajo antes de confiar en el cron automático.
```

- [ ] **Step 3: Verificar que los dos archivos existen y tienen el contenido correcto**

```bash
ls -la /Users/rodrigoramosaguirre/DAILY-IA-NEWS/prompts/
wc -l /Users/rodrigoramosaguirre/DAILY-IA-NEWS/prompts/*.md
```
Expected: ver `daily-pipeline.md` y `manual-run.md`, con línea-count razonable (50-150 líneas el principal, 10-15 el manual).

---

## Task 5: Primera corrida manual del pipeline

**Files:**
- Create: `archive/YYYY-MM-DD.html` (del día de hoy)
- Create: `index.html`
- Create: `index-data.json`

Esta es la prueba de fuego: correr el pipeline entero a mano, ver qué sale, ajustar.

- [ ] **Step 1: Preparar la fecha**

Ejecutar en Bash:
```bash
date +"%Y-%m-%d"
```
Expected: fecha de hoy en formato YYYY-MM-DD. Guardala mentalmente (o anotala) para usar en los prompts.

- [ ] **Step 2: Disparar el pipeline a mano con el prompt de `manual-run.md`**

En la sesión actual de Claude Code, pegá el contenido de `prompts/manual-run.md` con la fecha real sustituida. Claude debería:
1. Leer `config/sources.yaml`.
2. Fetchear las fuentes.
3. Mostrar candidatos.
4. Mostrar selección.
5. Mostrar resúmenes en español.
6. Escribir archivos.

- [ ] **Step 3: Verificar que los archivos se crearon**

```bash
ls -la /Users/rodrigoramosaguirre/DAILY-IA-NEWS/archive/
cat /Users/rodrigoramosaguirre/DAILY-IA-NEWS/index-data.json
```
Expected: ver un `archive/YYYY-MM-DD.html`, un `index.html` y un `index-data.json` con estructura válida.

- [ ] **Step 4: Abrir el dashboard en el navegador**

```bash
open /Users/rodrigoramosaguirre/DAILY-IA-NEWS/index.html
```
Expected: se ve el dashboard renderizado con noticias reales, filtros funcionales, sidebar con el día de hoy marcado.

- [ ] **Step 5: Anotar problemas observados**

Abrí un archivo `/Users/rodrigoramosaguirre/DAILY-IA-NEWS/docs/notes-primera-corrida.md` y anotá:
- ¿Las 5-7 noticias se ven razonables? ¿Hay sesgo de fuente?
- ¿Los resúmenes suenan en rioplatense o parecen traducción automática?
- ¿Algún link está roto o apunta a paywall que dispara mal?
- ¿La categoría de cada noticia está bien asignada?
- ¿Falta diversidad de categorías (ej. todo tech, nada de salud)?

- [ ] **Step 6: Ajustar el prompt según lo observado**

Con las notas, editá `prompts/daily-pipeline.md` si hace falta. Ejemplos de ajustes típicos:
- Si los resúmenes suenan a traducción, reforzar instrucciones de tono rioplatense.
- Si el ranking elige mal, ajustar los pesos o la fórmula.
- Si falta diversidad, reforzar la regla de "al menos 1 de cada categoría".

---

## Task 6: Iteración (3-5 corridas manuales en días seguidos)

**Files:**
- Modify: `prompts/daily-pipeline.md` (si hay ajustes)
- Create: nuevos archivos diarios en `archive/`

- [ ] **Step 1: Correr el pipeline manualmente durante 3-5 días hábiles**

Cada mañana:
1. Abrí Claude Code.
2. Pegá `prompts/manual-run.md` con la fecha actualizada.
3. Revisá el output.
4. Anotá observaciones en `docs/notes-primera-corrida.md`.

- [ ] **Step 2: Acumular issues recurrentes y resolverlos**

Después de 3-5 corridas, leé las notas y agrupá:
- Problemas de ranking (¿siempre elige las mismas fuentes?).
- Problemas de resumen (¿siempre le falta el "por qué importa"?).
- Problemas de diversidad (¿nunca hay salud?).
- Problemas de tono (¿se le escapa el neutro peninsular en algunos resúmenes?).

Editá el prompt para corregirlos.

- [ ] **Step 3: Cuando 2 corridas consecutivas salen "bien", pasar al Task 7**

Criterio de "bien": las 5-7 noticias son relevantes, diversificadas, en rioplatense fluido, con categorías balanceadas. Vos decidís si cumple.

---

## Task 7: Navegación del histórico (sidebar calendario funcional con múltiples días)

En este punto ya tenés 3-5 días de `archive/`. Verificar que la navegación funcione.

- [ ] **Step 1: Abrir el dashboard de hoy**

```bash
open /Users/rodrigoramosaguirre/DAILY-IA-NEWS/index.html
```

- [ ] **Step 2: Probar la sidebar calendario**

- Click en el día de ayer → debería cargar `archive/YYYY-MM-DD.html` del ayer.
- Click en hoy → vuelve a hoy.
- Click en mes anterior → muestra días del mes anterior (sin noticias, grises).

- [ ] **Step 3: Verificar `index-data.json`**

```bash
cat /Users/rodrigoramosaguirre/DAILY-IA-NEWS/index-data.json | python3 -m json.tool
```
Expected: ver todas las fechas del histórico en `dates`, titulares recientes en `recent_titles`.

- [ ] **Step 4: Si hay bugs de nav, ajustar**

Si el click en días anteriores no funciona bien:
- Chequear que las URLs en la sidebar apunten a `archive/` (ruta relativa correcta).
- Chequear que cada `archive/YYYY-MM-DD.html` tenga el `ARCHIVE_DATA` completo para que su propia sidebar también funcione.

Posible fix: en el pipeline (Paso 6), asegurarse que cuando se genera un nuevo día, el `index.html` y ese `archive/YYYY-MM-DD.html` ambos tengan el `ARCHIVE_DATA` con TODAS las fechas (incluyendo la nueva).

---

## Task 8: Configurar el scheduled task

**Files:**
- External: configuración del trigger (no archivo local)

- [ ] **Step 1: Invocar el skill `schedule` de Claude Code**

En Claude Code, escribí:
```
/schedule
```
Esto debería activar el skill. Si no, leé la documentación interna del skill con:
```
Skill tool → schedule
```

- [ ] **Step 2: Crear el trigger con cron 0 7 * * * en TZ America/Montevideo**

Parámetros del scheduled task:
- **Cron expression:** `0 7 * * *` (todos los días a las 07:00)
- **Timezone:** `America/Montevideo`
- **Prompt:** copiar el contenido completo de `/Users/rodrigoramosaguirre/DAILY-IA-NEWS/prompts/daily-pipeline.md`
- **Descripción:** "Daily IA News — pipeline diario de noticias"
- **Working directory:** `/Users/rodrigoramosaguirre/DAILY-IA-NEWS`

- [ ] **Step 3: Verificar que el task quedó creado**

Listar scheduled tasks:
```
CronList (o lo que el skill schedule use)
```
Expected: ver el trigger con su próximo disparo a las 7:00 AM del día siguiente.

- [ ] **Step 4: Hacer una corrida de prueba inmediata**

Si el skill lo permite, disparar el task a demanda (sin esperar al cron). Verificar que corre igual que las corridas manuales.

- [ ] **Step 5: Anotar en README cómo pausar/modificar el cron**

Editar `/Users/rodrigoramosaguirre/DAILY-IA-NEWS/README.md` agregando al final:

```markdown
## Gestión del scheduled task

- Listar: `/CronList` o equivalente del skill schedule.
- Pausar: `/CronDelete <id>`.
- Modificar: re-crear con nuevos parámetros (cron, prompt, etc.).
```

---

## Task 9: Período de observación (2 semanas de uso real)

Este task no es "implementación" — es uso + ajuste fino.

- [ ] **Step 1: Usar el dashboard todos los días durante 2 semanas**

Cada mañana: abrir `index.html`, leer las noticias, anotar en `docs/observaciones-2-semanas.md`:
- ¿Las noticias son relevantes?
- ¿Hay sesgo de fuente persistente? ¿Cuál es el % del dominio más repetido?
- ¿Te perdés alguna noticia grande que sí vio Marcello?
- ¿Encontrás noticias buenas que el grupo de WhatsApp no te daba?

- [ ] **Step 2: Medir los criterios de éxito del spec**

Al final de las 2 semanas:
1. ¿Abriste el dashboard ≥ 5 de 7 días? (sí/no)
2. ¿% del dominio más repetido < 40%? (calcular: agrupar `sources` de `index-data.json.days`, contar, dividir por total).
3. ¿Encontraste noticias de salud que no te daba el WhatsApp? (sí/no, listarlas).
4. ¿El pipeline corrió sin falla ≥ 90% de los días? (calcular: días con archivo `archive/YYYY-MM-DD.html` / 14).

- [ ] **Step 3: Decidir siguiente iteración**

Según los resultados:
- Si todo ok: dejalo corriendo. Terminamos.
- Si hay problemas de relevancia: refactor del prompt de ranking.
- Si falta profundidad: considerar v2 con el bloque "Implicancia para ASESP".
- Si querés distribuir (compartir): considerar v2 con export a email o LinkedIn.

---

## Commit Strategy

Si decidís inicializar git (opcional, recomendado para trazabilidad):

```bash
cd /Users/rodrigoramosaguirre/DAILY-IA-NEWS
git init
git add -A
git commit -m "feat: daily-ia-news initial scaffolding"
```

Después, commit frecuente al final de cada Task:

- Task 1: `chore: project scaffolding (folders + readme)`
- Task 2: `feat: sources.yaml with 22 diversified AI news sources`
- Task 3: `feat: base HTML template with sidebar calendar and filters`
- Task 4: `feat: daily pipeline prompt + manual run variant`
- Task 5: `chore: first manual run verified, initial archive`
- Task 6: `refactor: prompt adjustments after N manual runs`
- Task 7: `fix: historical navigation across archive/ files`
- Task 8: `feat: scheduled task configured for 07:00 UY`
- Task 9: `docs: 2-week observation notes`

---

## Self-Review (para el ejecutor)

Antes de dar el plan por cerrado, chequear:

1. **¿Cada noticia elegida tiene link funcional?** Si apunta a paywall 100% (ej. The Information) y no hay preview, mejor saltearla.
2. **¿La diversidad de fuentes se mantiene después de 2 semanas?** Si TechCrunch sigue dominando, ajustar el `diversidad_bonus` (que sea más penalizante).
3. **¿El tono es rioplatense de verdad?** Revisar que usa "vos", "te", "acá" y no "tú", "te", "aquí".
4. **¿El scheduled task dispara correctamente?** Verificar que el archivo del día aparece a las 7:05 AM.
5. **¿Los links del histórico funcionan?** Abrir 3 archivos random de `archive/` y verificar que su sidebar navega bien.
