# Diseño — Bitcoin Watch + lente de intereses de Rodrigo

Fecha: 2026-06-14
Estado: aprobado (diseño OK por Rodrigo el 2026-06-14)

## Problema / objetivo

El diario hoy es 100% IA (categorías tech/business/health, todo dentro de IA).
Rodrigo quiere sumar intereses propios:

1. **Bitcoin** — sus únicas inversiones están en BTC; está en fase bajista haciendo
   DCA (retomando compras) y quiere leer el ciclo para entender hacia dónde va y
   anticipar el alt season. Es el único tema **fuera de la IA**.
2. **Cuatro ángulos de IA** que hoy el diario no prioriza: salud/mutualistas/IAMC,
   management/carrera comercial, Uruguay/LATAM, productividad/agentes.

## Decisiones tomadas (con Rodrigo)

- **Arquitectura A**: los 4 ángulos IA entran como **lente de prioridad** dentro de
  las secciones que ya existen (no son bloques nuevos). Bitcoin es la **única
  sección nueva**.
- **Jerarquía de los ángulos IA**: salud/mutualistas y management/carrera pesan
  **alto** (día a día + meta de Rodrigo); Uruguay/LATAM y productividad/agentes
  entran **cuando hay algo realmente bueno**.
- **Nombre de la sección**: "Bitcoin Watch".
- **Título visible del diario**: queda "Daily IA News". Bitcoin se presenta como
  sección declarada aparte ("lo único acá que no es IA").
- **Nombre del repo y URL**: NO se tocan (`daily-ia-news`, GitHub Pages intactos).
- **Encuadre Bitcoin**: señales con fuente, **nunca profecías**. No se da fecha de
  alt season. Se trackean indicadores objetivos con la fuente y la hora del dato.

## Alcance: qué se toca y qué no

**Se toca (3 archivos, todo editorial):**
- `config/sources.yaml`
- `prompts/daily-pipeline.md`
- `templates/base.html`

**Queda intacto explícitamente:**
- Nombre/URL del repo, cron del VPS, `run-daily-vps.sh`, `sync-archive-data.py`,
  el schema de `index-data.json`, el motor JS del template, el bloque
  `ARCHIVE_DATA` y el botón "Llevame a Claude", y todos los HTML históricos
  (no se retro-generan; la sección nueva aparece solo en los días nuevos).

Es un **agregado quirúrgico**, no un rediseño.

## Componente 1 — Sección "Bitcoin Watch"

### Ubicación y orden del diario
Tesis → Lo que importa hoy → Anthropic Watch → El Bolsillo → El resto →
**Bitcoin Watch** → footer.
(Al final, claramente separada como "lo único fuera de IA".)

### Contenido (tres partes)
1. **Pulso de mercado**: precio BTC (USD), variación 24h y 7d, dominancia BTC,
   Fear & Greed Index (valor + etiqueta), y fase del ciclo post-halving
   (último halving: 2024-04-20, bloque 840.000 — dato fijo computado por fecha).
2. **Señales de alt season**: dominancia BTC (tendencia), ratio ETH/BTC, y
   Altcoin Season Index si se consigue. Encuadre fijo: "esto muestran los datos
   hoy", **sin fecha ni predicción**.
3. **Noticia de fondo**: una línea, solo si hay algo que mueva la aguja (ETF,
   regulación, macro). Si no hay, se omite (no se rellena).

### Origen de los datos (clave para confiabilidad)
El nuevo paso del pipeline trae los números con `curl` (Bash está permitido), no
los estima. Cada dato se publica con su fuente y la hora.

- **Precio + variaciones 24h/7d + market cap**:
  `curl -s "https://api.coingecko.com/api/v3/coins/bitcoin?localization=false&tickers=false&market_data=true&community_data=false&developer_data=false"`
  (campos: `market_data.current_price.usd`,
  `market_data.price_change_percentage_24h`,
  `market_data.price_change_percentage_7d`).
- **Dominancia BTC y ETH**:
  `curl -s "https://api.coingecko.com/api/v3/global"`
  (campos: `data.market_cap_percentage.btc` y `.eth`).
- **Fear & Greed Index**:
  `curl -s "https://api.alternative.me/fng/?limit=1"`
  (campos: `data[0].value`, `data[0].value_classification`).
- **ETH/BTC ratio**: se deriva de los precios (CoinGecko) o vía
  `.../simple/price?ids=ethereum&vs_currencies=btc`.
- **Altcoin Season Index**: sin API limpia. Si Claude lo consigue por WebSearch
  (blockchaincenter.net), lo incluye; si no, usa dominancia BTC + ETH/BTC como
  proxy. No se fuerza.

**Reglas de robustez (van en el prompt):**
- Si una API falla, se omite ese dato puntual y se sigue (nunca se inventa).
- Cada número lleva fuente + hora UYT.
- Prohibido dar fecha de alt season o decir "se viene". Solo "los datos muestran X".

### HTML (nuevo placeholder + bloque)
Nuevo placeholder `{{BITCOIN_WATCH}}` (pasan a ser 10 placeholders).
Bloque de referencia (mismo patrón visual que las otras secciones):

```html
<div class="seccion-bitcoin">
  <div class="seccion-label">Bitcoin Watch · lo único acá que no es IA</div>
  <h3>{tagline}</h3>
  <div class="btc-metrics">
    <div class="btc-metric"><span class="btc-k">BTC</span><span class="btc-v">{precio}</span></div>
    <div class="btc-metric"><span class="btc-k">24h</span><span class="btc-v">{var24}</span></div>
    <div class="btc-metric"><span class="btc-k">7d</span><span class="btc-v">{var7d}</span></div>
    <div class="btc-metric"><span class="btc-k">Dominancia</span><span class="btc-v">{dom}</span></div>
    <div class="btc-metric"><span class="btc-k">Fear &amp; Greed</span><span class="btc-v">{fng}</span></div>
  </div>
  <p class="btc-senales"><strong>Señales:</strong> {senales}</p>
  <p class="btc-fondo">{noticia_fondo_opcional}</p>
  <p class="btc-fuente"><em>Datos: CoinGecko + alternative.me · {hora} UYT</em></p>
</div>
```

CSS nuevo: variables `--bitcoin-bg` / `--bitcoin-border` (light y dark) con la
paleta naranja Bitcoin (`#f7931a`), y reglas `.seccion-bitcoin` + `.btc-*`
siguiendo el patrón de `.seccion-bolsillo`. Sin emojis. Responsive: las métricas
se apilan/flexean en mobile (igual criterio que el resto del CSS `@media`).

## Componente 2 — Lente de intereses (4 ángulos IA)

Cambios en `prompts/daily-pipeline.md`, Paso 5 (ranking) y Paso 7 ("Para vos"):

- **`obsesion_rodrigo_bonus`** se reescribe con jerarquía:
  - +3 si el cluster toca **salud/mutualistas/IAMC** o **management/carrera
    comercial / liderazgo / ventas**.
  - +2 si toca **Uruguay/LATAM** o **productividad/agentes/uso aplicado de IA**.
  - (Se mantiene el +2 existente para Anthropic, monetización, deals con dinero.)
- **"Para vos"**: instrucción reforzada para aterrizar a ASESP (PM en mutualista,
  comercial Hogar, analista de datos) y a la meta de Gerente Comercial cuando
  aplique. Ej: "esto que hizo tal hospital con IA es replicable en una mutualista".

No se crean bloques nuevos para estos 4 ángulos.

## Componente 3 — Fuentes y voces nuevas

En `config/sources.yaml`:

- **Bloque nuevo `crypto`** (separado de `sources`/`voices`, NO entra al ranking IA):
  - Medios: CoinDesk, Cointelegraph, Bitcoin Magazine, Decrypt (los 4 con RSS).
  - Endpoints de datos: los 3 `curl` de arriba.
- **Management/carrera** (al bloque `sources`, category business):
  Lenny's Newsletter (weight 3, RSS) + a16z (weight 2, RSS).
- **Uruguay/LATAM** (al bloque `sources`, category tech, language es):
  Xataka (weight 2, RSS) + instrucción de WebSearch regional "IA Uruguay/LATAM".
- **Salud/mutualistas**: sin fuentes nuevas (ya hay STAT, NEJM AI, Fierce,
  Healthcare IT News). Solo cambia el ángulo/prioridad.
- **Productividad/agentes**: sin fuentes nuevas (panel ya fuerte: Mollick,
  Willison, Shipper, Lambert). Solo cambia la prioridad.

El Paso 1 y Paso 2 del prompt se actualizan para describir el bloque `crypto`
nuevo y aclarar que NO se rankea con las noticias de IA.

## Riesgos y validación (dry-run obligatorio)

Integración nueva y frágil (APIs externas) → validar antes de confiar en el cron:

1. **Dry-run de 1 API primero**: probar los 3 `curl` desde el VPS y confirmar que
   responden el JSON esperado (rate limits de CoinGecko: ~10-30 req/min, sobra
   para 1 corrida/día). Si CoinGecko bloquea, fallback a otra API de precio.
2. **Corrida de prueba completa**: regenerar un día a un archivo de prueba y
   verificar que (a) el bloque Bitcoin Watch renderiza, (b) los datos salen con
   fuente y hora, (c) no se coló ninguna nota cripto en "Lo que importa hoy".
3. **`/dashboard-check`** sobre el HTML generado antes de dar por cerrado.

Si el dry-run de las APIs falla, pivotar (otra fuente de datos) antes de seguir.

## Fuera de alcance (YAGNI)

- No se renombra el diario ni el repo.
- No se crean bloques separados para los 4 ángulos IA.
- No se retro-generan los HTML históricos.
- No se reactiva el envío por Telegram/WhatsApp.
- No se agregan voces de influencers cripto (ruido alto); Bitcoin Watch se nutre
  de medios + datos objetivos.
