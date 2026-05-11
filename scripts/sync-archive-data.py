#!/usr/bin/env python3
"""
Sincroniza el bloque <script> de todos los HTML (index.html + archive/*.html)
con los datos actuales de index-data.json.

Mantiene intacto el HTML; solo reescribe el contenido de <script>...</script>.
El bloque JS es el canónico del template: navegación por calendario con
auto-detección de ruta (IN_ARCHIVE) y hrefForDate().

Uso:
  python3 scripts/sync-archive-data.py [PROJECT_DIR]

Si no se pasa PROJECT_DIR, usa el dir del repo (padre de scripts/).
"""
import json
import re
import sys
from pathlib import Path


CANONICAL_SCRIPT = """
  // ARCHIVE_DATA_START
  const ARCHIVE_DATA = __ARCHIVE_DATA__;
  // ARCHIVE_DATA_END
  const CURRENT_DATE_ISO = "__CURRENT_DATE_ISO__";
  const IN_ARCHIVE = window.location.pathname.includes('/archive/');

  document.querySelectorAll('.news-item').forEach(item => {
    item.addEventListener('click', (e) => {
      if (e.target.closest('.copy-prompt-btn') || e.target.closest('a')) return;
      item.classList.toggle('expanded');
    });
  });

  async function copyPromptToClipboard(text) {
    try {
      if (navigator.clipboard && window.isSecureContext) {
        await navigator.clipboard.writeText(text);
        return true;
      }
    } catch (e) { /* fallback */ }
    try {
      const ta = document.createElement('textarea');
      ta.value = text;
      ta.setAttribute('readonly', '');
      ta.style.position = 'fixed';
      ta.style.top = '0';
      ta.style.left = '0';
      ta.style.opacity = '0';
      document.body.appendChild(ta);
      ta.focus();
      ta.select();
      ta.setSelectionRange(0, text.length);
      const ok = document.execCommand('copy');
      document.body.removeChild(ta);
      return ok;
    } catch (e) {
      return false;
    }
  }

  document.querySelectorAll('.copy-prompt-btn').forEach(btn => {
    btn.addEventListener('click', async (e) => {
      e.stopPropagation();
      const prompt = btn.dataset.prompt || '';
      const original = btn.textContent;
      const ok = await copyPromptToClipboard(prompt);
      btn.textContent = ok ? '✓ Copiado — pegá en Claude' : 'No se pudo copiar';
      btn.classList.add('copied');
      setTimeout(() => { btn.textContent = original; btn.classList.remove('copied'); }, 2400);
    });
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

  const MONTHS_ES = ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];
  let currentMonth = new Date(CURRENT_DATE_ISO + 'T12:00:00');

  function hrefForDate(iso) {
    const latest = ARCHIVE_DATA.dates[ARCHIVE_DATA.dates.length - 1];
    if (iso === latest) {
      return IN_ARCHIVE ? '../index.html' : 'index.html';
    }
    return IN_ARCHIVE ? `${iso}.html` : `archive/${iso}.html`;
  }

  function renderCalendar(date) {
    const year = date.getFullYear();
    const month = date.getMonth();
    document.getElementById('calendar-title').textContent = `${MONTHS_ES[month]} ${year}`;
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
        el.addEventListener('click', () => { window.location.href = hrefForDate(iso); });
      }
      if (iso === CURRENT_DATE_ISO) el.classList.add('today');
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

  // Tabs: Daily vs Práctica (fallback: sin JS se ven ambas)
  (function initTabs() {
    const tabs = Array.from(document.querySelectorAll('.view-tab'));
    const panels = Array.from(document.querySelectorAll('[data-tab-panel]'));
    if (!tabs.length || panels.length < 2) return;

    document.body.classList.add('tabs-enabled');

    function setActive(tabName) {
      tabs.forEach(t => t.setAttribute('aria-selected', t.dataset.tab === tabName ? 'true' : 'false'));
      panels.forEach(p => p.classList.toggle('active', p.dataset.tabPanel === tabName));
      document.body.classList.toggle('tab-practical', tabName === 'practical');
    }

    tabs.forEach(t => {
      t.addEventListener('click', () => setActive(t.dataset.tab));
    });

    setActive('daily');
  })();

  // IA Práctica: convertir el bloque “Casos prácticos” en cards visuales
  // sin exigir al generador un HTML complejo.
  (function practicalCards() {
    const panel = document.getElementById('tab-practical');
    if (!panel) return;
    const shell = panel.querySelector('.practical-shell');
    if (!shell) return;

    // Encontrar el <h3> “Casos prácticos” (match flexible)
    const h3s = Array.from(shell.querySelectorAll('h3'));
    const casosH3 = h3s.find(h => (h.textContent || '').trim().toLowerCase().startsWith('casos pr'));
    if (!casosH3) return;

    // Recolectar nodos desde el primer <p><strong>... hasta antes del próximo <h3>
    let cursor = casosH3.nextElementSibling;
    const chunks = [];
    let current = [];

    function flush() {
      if (current.length) chunks.push(current), current = [];
    }

    while (cursor) {
      if (cursor.tagName === 'H3') break;

      const isCaseP = cursor.tagName === 'P' && cursor.querySelector('strong');
      if (isCaseP) {
        flush();
        current.push(cursor);
      } else if (current.length) {
        // Agregar listas y párrafos que pertenezcan al caso
        if (cursor.tagName === 'UL' || cursor.tagName === 'P') current.push(cursor);
      }
      cursor = cursor.nextElementSibling;
    }
    flush();
    if (!chunks.length) return;

    // Construir cards y reemplazar el bloque original
    const cardsWrap = document.createElement('div');
    cardsWrap.className = 'practical-cards';

    chunks.forEach(nodes => {
      const p = nodes[0];
      const strong = p.querySelector('strong');
      const title = strong ? strong.textContent.trim() : 'Caso práctico';

      // Extraer “Por qué importa” del propio <p> si existe
      let meta = '';
      // Heurística: buscar “Por qué importa:” dentro del texto del párrafo
      const t = (p.textContent || '').replace(/\s+/g, ' ').trim();
      const idx = t.toLowerCase().indexOf('por qué importa');
      if (idx !== -1) {
        meta = t.slice(idx).replace(/^por qué importa:\s*/i, '').trim();
      }

      const card = document.createElement('div');
      card.className = 'practical-card';

      const h = document.createElement('div');
      h.className = 'practical-card-title';
      h.textContent = title;
      card.appendChild(h);

      if (meta) {
        const m = document.createElement('div');
        m.className = 'meta';
        m.innerHTML = `<em>Por qué importa:</em> ${meta}`;
        card.appendChild(m);
      }

      // Agregar el resto de nodos (clonados) excepto el <strong> del primer párrafo
      nodes.forEach((n, i) => {
        if (i === 0) return; // ya usamos el título/meta
        card.appendChild(n.cloneNode(true));
      });

      cardsWrap.appendChild(card);
    });

    // Insertar cards inmediatamente después del h3 y remover los nodos originales
    shell.insertBefore(cardsWrap, casosH3.nextElementSibling);
    chunks.flat().forEach(n => n.remove());
  })();
"""


SCRIPT_RE = re.compile(r"<script>(.*?)</script>", re.DOTALL)
DATE_RE = re.compile(r"(\d{4}-\d{2}-\d{2})")


def infer_current_date(html_path: Path) -> str:
    """Extrae la fecha ISO del archivo: si es archive/YYYY-MM-DD.html, del nombre;
    si es index.html, del último día en index-data.json (lo recibe por param)."""
    m = DATE_RE.search(html_path.stem)
    return m.group(1) if m else ""


def rewrite(html_path: Path, archive_data: dict, current_date: str) -> bool:
    text = html_path.read_text(encoding="utf-8")
    if "<script>" not in text or "</script>" not in text:
        return False

    new_script = (
        CANONICAL_SCRIPT
        .replace("__ARCHIVE_DATA__", json.dumps(archive_data, ensure_ascii=False))
        .replace("__CURRENT_DATE_ISO__", current_date)
    )
    # IMPORTANT: use a function replacement so backslashes inside new_script
    # (e.g. JS regexes like /\s+/) are not interpreted as re.sub escape sequences.
    new_text, n = SCRIPT_RE.subn(lambda _m: f"<script>{new_script}</script>", text, count=1)
    if n == 0:
        return False
    html_path.write_text(new_text, encoding="utf-8")
    return True


def main():
    project_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent
    data_path = project_dir / "index-data.json"
    if not data_path.exists():
        print(f"ERROR: no existe {data_path}", file=sys.stderr)
        sys.exit(1)

    archive_data = json.loads(data_path.read_text(encoding="utf-8"))
    dates = archive_data.get("dates", [])
    if not dates:
        print("ERROR: index-data.json sin dates", file=sys.stderr)
        sys.exit(1)

    latest = sorted(dates)[-1]
    archive_data["dates"] = sorted(dates)

    updated = []

    # index.html → CURRENT_DATE = último día
    index_html = project_dir / "index.html"
    if index_html.exists() and rewrite(index_html, archive_data, latest):
        updated.append(str(index_html.relative_to(project_dir)))

    # archive/*.html → CURRENT_DATE = fecha del archivo
    archive_dir = project_dir / "archive"
    if archive_dir.exists():
        for html in sorted(archive_dir.glob("*.html")):
            current = infer_current_date(html)
            if not current:
                continue
            if rewrite(html, archive_data, current):
                updated.append(str(html.relative_to(project_dir)))

    print(f"Sincronizados {len(updated)} archivo(s):")
    for p in updated:
        print(f"  - {p}")


if __name__ == "__main__":
    main()
