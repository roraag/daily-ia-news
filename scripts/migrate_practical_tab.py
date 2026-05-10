#!/usr/bin/env python3
"""One-shot migration: add the new Practical tab markup + CSS to existing
index.html and archive/*.html files.

This keeps the original Daily IA News content intact, just wrapped in a tab
panel, and adds an empty Practical panel with a placeholder message.

Safe to run multiple times (idempotent-ish): skips files that already contain
'IA Práctica' tabs.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

TAB_MARKER = 'data-tab="practical"'

CSS_SNIPPET = r"""

  /* Tabs (Daily IA News / IA Práctica) */
  .view-tabs {
    display: flex;
    gap: 0.5rem;
    flex-wrap: wrap;
    margin-top: 0.5rem;
  }
  .view-tab {
    padding: 0.45rem 0.9rem;
    border: 1px solid var(--border);
    border-radius: 999px;
    background: none;
    color: var(--fg);
    cursor: pointer;
    font-size: 0.9rem;
  }
  .view-tab[aria-selected="true"] {
    background: var(--accent);
    color: white;
    border-color: var(--accent);
  }
  .tab-panel { display: block; }
  body.tabs-enabled .tab-panel { display: none; }
  body.tabs-enabled .tab-panel.active { display: block; }
  body.tab-practical .controls { display: none; }

  .practical-shell {
    padding: 1.25rem 1.5rem;
    border: 1px solid var(--border);
    border-radius: 8px;
    background: rgba(0,0,0,0.02);
  }
  @media (prefers-color-scheme: dark) {
    .practical-shell { background: rgba(255,255,255,0.03); }
  }
  .practical-shell h2 {
    font-family: "IBM Plex Serif", Georgia, serif;
    font-size: 1.35rem;
    font-weight: 600;
    margin-bottom: 0.75rem;
  }
  .practical-shell h3 {
    font-size: 0.85rem;
    text-transform: uppercase;
    color: var(--muted);
    letter-spacing: 0.06em;
    margin-top: 1.25rem;
    margin-bottom: 0.5rem;
  }
  .practical-shell ul { padding-left: 1.2rem; }
  .practical-shell li { margin-bottom: 0.35rem; }
  .practical-shell a { color: var(--accent); text-decoration: none; }
  .practical-shell a:hover { text-decoration: underline; }
"""

NAV_SNIPPET = (
    '    <nav class="view-tabs" aria-label="Vista">\n'
    '      <button class="view-tab" type="button" data-tab="daily" aria-selected="true">Daily IA News</button>\n'
    '      <button class="view-tab" type="button" data-tab="practical" aria-selected="false">IA Práctica</button>\n'
    '    </nav>\n'
)

PRACTICAL_PLACEHOLDER = (
    '    <div class="practical-shell">\n'
    '      <h2>IA Práctica</h2>\n'
    '      <p>Esta solapa se empieza a generar automáticamente a partir de ahora. En días anteriores puede aparecer vacía.</p>\n'
    '      <p>Si querés, puedo regenerar días viejos más adelante, pero primero estabilicemos el formato.</p>\n'
    '    </div>\n'
)


def add_css(html: str) -> str:
    if '.view-tabs' in html and '.practical-shell' in html:
        return html
    return re.sub(r"\n</style>", CSS_SNIPPET + "\n</style>", html, count=1)


def migrate_main(html: str) -> str:
    if TAB_MARKER in html:
        return html

    # Insert nav tabs inside <header> (before </header>)
    html = re.sub(r"\n\s*</header>", "\n" + NAV_SNIPPET + "  </header>", html, count=1)

    # Wrap main content after </header> into tab panels.
    m = re.search(r"<main>([\s\S]*?)</main>", html)
    if not m:
        return html

    main_inner = m.group(1)
    # Split at first </header>
    split = re.split(r"</header>", main_inner, maxsplit=1)
    if len(split) != 2:
        return html

    header_part = split[0] + "</header>\n"
    rest_part = split[1]

    new_rest = (
        '  <section class="tab-panel active" id="tab-daily" data-tab-panel="daily">\n'
        + rest_part.strip("\n")
        + "\n  </section>\n\n"
        + '  <section class="tab-panel" id="tab-practical" data-tab-panel="practical">\n'
        + PRACTICAL_PLACEHOLDER
        + "  </section>\n"
    )

    new_main_inner = header_part + new_rest
    return html[: m.start(1)] + new_main_inner + html[m.end(1) :]


def main() -> int:
    project_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent
    targets = [project_dir / "index.html"] + sorted((project_dir / "archive").glob("*.html"))

    changed = 0
    for path in targets:
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8")
        if TAB_MARKER in text:
            continue
        new_text = migrate_main(add_css(text))
        if new_text != text:
            path.write_text(new_text, encoding="utf-8")
            changed += 1

    print(f"Migrados {changed} archivo(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
