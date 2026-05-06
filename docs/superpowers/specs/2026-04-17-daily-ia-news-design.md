---
title: Daily IA News — Design Spec
author: Rodrigo Ramos Aguirre
date: 2026-04-17
status: approved-design, pending-implementation-plan
---

# Daily IA News — Diseño

## 1. Objetivo

Construir un **dashboard HTML local y autocontenido** que se actualiza automáticamente cada día a las 7:00 AM (hora Uruguay) con 5-7 noticias curadas sobre inteligencia artificial, seleccionadas desde un pool diversificado de ~20 fuentes, cubriendo tres ejes temáticos: IA general/tech (40%), IA aplicada al negocio (30%), e IA en salud (30%).

El sistema debe permitir a Rodrigo **dejar de depender de curadores externos** (ej. grupo de WhatsApp "Mundo IA" de Marcello, que concentra el 93% de sus fuentes en TechCrunch y The Verge) y consumir un feed personalizado, con diversidad real de fuentes y recorte editorial alineado a sus intereses profesionales.

## 2. Contexto y motivación

Rodrigo pertenece hoy a un grupo de WhatsApp donde un curador (Marcello) publica 1-5 noticias diarias de IA. Análisis del export del grupo (8.007 líneas, ~710 enlaces) confirma:

- **428 enlaces a TechCrunch + 233 a The Verge = 93% del total.**
- El resto: apariciones sueltas (VentureBeat, Gizmodo, blogs oficiales, medios en español).

El problema no es la calidad individual de Marcello, sino la **concentración de fuentes** y la **ausencia de recorte editorial propio**. Rodrigo quiere dejar de ser consumidor pasivo y pasar a ser su propio editor.

## 3. Scope

### Incluido
- Pipeline diario automático (scheduled task) que fetchea, filtra, rankea y resume noticias.
- Dashboard HTML estático local, con histórico permanente navegable.
- Pool de ~20 fuentes diversificadas en 3 ejes.
- Formato de noticia "híbrido con capas" (título + resumen corto + expandible con detalle).
- Regla de diversidad: máximo 2 noticias del mismo dominio por día.
- Modo oscuro/claro automático.
- Filtro por categoría (Tech / Negocio / Salud / Todos).
- Sidebar calendario para navegar histórico.

### No incluido (YAGNI)
- Distribución a terceros (email, Telegram, LinkedIn, RSS propio). Es para uso personal exclusivo.
- Cuenta, autenticación, multi-usuario.
- Análisis/opinión propia sobre cada noticia (ej. un bloque tipo "Implicancia para ASESP o mutualismo"). Se evaluó y descartó para v1; puede agregarse en v2. Nota: el campo "Para quién" de la capa expandida (ver §6) NO es análisis propio opinativo, sino una etiqueta descriptiva de audiencia (ej. "para PMs que evalúan adopción"), sin juicio ni recomendación.
- API key externa a Anthropic o a los medios. Todo corre dentro de Claude Code vía scheduled tasks.
- Métricas, analytics, tracking de lectura.
- Bookmark / favoritos / notas personales sobre cada noticia.
- Búsqueda full-text sobre el histórico (v2, si el corpus crece).

## 4. Arquitectura

### 4.1 Componentes

| Componente | Tipo | Descripción |
|---|---|---|
| `sources.yaml` | Archivo de configuración | Lista de ~20 fuentes con URL del feed/site, categoría, peso de prioridad. |
| `scheduled-task` | Trigger cron | Creado con el skill `schedule`. Cron expression: `0 7 * * *` en TZ `America/Montevideo`. Dispara a Claude con un prompt fijo. |
| `daily-pipeline-prompt` | Prompt/instrucción | Lo que el scheduled task le pasa a Claude: "leé sources.yaml, fetcheá, rankeá, elegí 5-7, generá el HTML del día". |
| `template.html` | Plantilla base | Estructura del dashboard: feed minimalista, dark/light auto, sidebar calendario, filtros. Sin JS pesado, sin imágenes. |
| `archive/YYYY-MM-DD.html` | Artefacto diario | Un archivo HTML por día. Histórico permanente. |
| `index.html` | Home del dashboard | Apunta siempre al último día generado. Es el archivo que Rodrigo abre. |
| `index-data.json` | Metadata del histórico | Lista de fechas con archivo generado. Lo lee la sidebar para armar el calendario. |

### 4.2 Pool de fuentes (~20)

**Tech / IA general (~40% del output, 2-3 noticias/día):**
- TechCrunch (AI section)
- The Verge (AI)
- Ars Technica
- MIT Technology Review
- VentureBeat AI
- Blogs oficiales: Anthropic, OpenAI, Google DeepMind, Hugging Face
- Newsletters: Import AI (Jack Clark), TLDR AI

**Negocio / IA aplicada (~30%, 2 noticias/día):**
- Harvard Business Review (AI topics)
- MIT Sloan Management Review
- a16z blog (Andreessen Horowitz)
- Stratechery (Ben Thompson)
- McKinsey Insights (AI)
- The Information (con caveat: paywall fuerte; se usa lo accesible públicamente — titular, preview, newsletter gratuito)

**IA en salud (~30%, 2 noticias/día):**
- STAT News (Health Tech)
- Fierce Healthcare
- NEJM AI
- Healthcare IT News
- MobiHealthNews

**Nota:** las fuentes pueden estar en inglés; Claude traduce/resume al español rioplatense. Si una misma noticia está cubierta en español con calidad (ej. Xataka), se privilegia esa versión.

### 4.3 Criterios de ranking y diversidad

Al rankear los 40-60 candidatos diarios para elegir 5-7:

1. **Magnitud** — ¿qué tan grande es el anuncio? (ej. lanzamiento de un modelo frontier > blog post de un tool chico).
2. **Relevancia temática** — fit con los 3 ejes (Tech / Negocio / Salud).
3. **Diversidad de fuente** — máximo 2 noticias del mismo dominio por día. Preferencia a fuentes subrepresentadas.
4. **Novedad** — no repetir una noticia ya publicada en días anteriores (se checkea contra `index-data.json`).

Si hay menos de 5 candidatos válidos, el dashboard del día se genera igual con lo que haya + nota "Día tranquilo en IA, X noticias hoy".

## 5. Flujo de datos (día típico)

```
07:00 AM (America/Montevideo) → scheduled task dispara
  ↓
Claude lee sources.yaml (20 fuentes)
  ↓
WebFetch sobre cada URL (RSS o home del medio)
  + WebSearch como fallback (ej. "site:stat-news.com AI últimas 24h")
  → junta 40-60 candidatos
  ↓
Filtra por ventana temporal (últimas 24h) y por keywords de IA
  ↓
Aplica ranking + regla de diversidad
  → selecciona 5-7 noticias
  ↓
Por cada noticia genera: título + 1 línea de resumen + bloque expandible
  (Qué pasó / Por qué importa / Para quién / Link a fuente original)
  ↓
Escribe archive/2026-04-17.html
Actualiza index.html (redirect o contenido idéntico al último)
Actualiza index-data.json (agrega fecha 2026-04-17)
  ↓
FIN
```

## 6. Formato por noticia ("híbrido con capas")

Cada noticia en el feed tiene dos capas de profundidad:

**Capa superficial** (siempre visible):
- Número de orden en el día (1, 2, 3...)
- Título en tipografía serif grande
- Tag de categoría (Tech / Negocio / Salud) en color tenue a la derecha
- Una línea de resumen (máx. 20 palabras) debajo del título

**Capa expandida** (al hacer click en la noticia):
- **Qué pasó** — 2-3 bullets descriptivos.
- **Por qué importa** — 1-2 líneas analíticas. Por qué vale prestar atención.
- **Para quién** — breve nota sobre para qué perfil profesional es más relevante (ej. "para PMs que evalúan adopción", "para responsables comerciales de salud").
- **Fuente** — link al artículo original con el dominio a la vista.

El tono en todos los textos generados es **rioplatense** (vos/te), conciso, sin jerga innecesaria.

## 7. Diseño visual

**Estilo general:** feed minimalista tipo Hacker News + Stratechery. Lista vertical sobria, tipografía grande, cero decoraciones.

**Header (pegado arriba):**
- `Daily IA News — [fecha en español, ej. "jueves 17 de abril de 2026"]`
- Filtros de categoría: `[Tech] [Negocio] [Salud] [Todos]` (chips clicables)
- Toggle dark/light (por defecto: auto según hora del sistema)
- Ícono calendario que abre/cierra la sidebar

**Sidebar izquierda (colapsable):**
- Calendario mensual simple.
- Días con noticias: clickeables, con un punto debajo.
- Días sin noticias: grises.
- Navegación mes anterior/siguiente.

**Feed central:**
- Cada noticia es una fila con padding generoso.
- Separador sutil entre noticias (línea de 1px color muy tenue).
- Click en título → expande la capa detalle in-place con animación breve.

**Tipografía:**
- Títulos: serif editorial (IBM Plex Serif, Source Serif Pro, o fallback a Georgia).
- Body y UI: sans-serif (Inter, o fallback a system-ui).
- Tamaño base: 18px (lectura cómoda).

**Paleta:**
- Modo claro: fondo blanco/crema, texto gris oscuro, acento azul suave.
- Modo oscuro: fondo casi negro, texto gris claro, acento azul tenue.

**Performance:**
- HTML + CSS inline + JS mínimo (< 5 KB).
- Sin imágenes, sin fuentes externas (usa locales o system fonts con fallback).
- Carga en < 1 segundo, 100% offline después de abierto.

## 8. Manejo de errores y edge cases

| Escenario | Comportamiento |
|---|---|
| Una fuente cae o no responde | Se loguea en consola de Claude y se saltea. No bloquea el resto del pipeline. |
| Menos de 5 candidatos válidos | Se genera el HTML con lo que haya + nota "Día tranquilo en IA, X noticias hoy". |
| Falla total del scheduled task | El último `archive/YYYY-MM-DD.html` válido queda como home hasta el siguiente éxito. `index.html` nunca queda en blanco. |
| Noticia ya publicada días atrás | Se filtra en el paso de novedad. No se repite aunque trending. |
| Paywall en una fuente (ej. The Information) | Se usa lo accesible (titular + preview + newsletter gratis). Si no alcanza para resumir con calidad, se saltea. |
| Error al escribir archivo | Se reintenta 2 veces con backoff. Si falla, se loguea y el día queda sin entrada (el día anterior sigue siendo la home). |

## 9. Testing inicial

Antes de activar el cron definitivo:

1. **Corrida manual × 3-5 días** con un comando tipo `/daily-ia-news run` para verificar que:
   - Las fuentes se fetchean correctamente.
   - El ranking elige noticias razonables.
   - La regla de diversidad funciona.
   - El HTML renderiza bien en el navegador.
   - La sidebar-calendario se actualiza.
2. **Ajuste del prompt de ranking** según lo que devuelva. Esto es iterativo: probablemente las primeras corridas elijan noticias poco relevantes o concentradas en pocas fuentes, y haya que tunear.
3. **Activación del cron** solo cuando haya 3-4 corridas manuales exitosas consecutivas.

No se contempla test suite automatizada formal — es una herramienta personal, no un producto. El "test" es el uso diario de Rodrigo.

## 10. Criterios de éxito

El sistema se considera exitoso si, después de 2 semanas de uso real:

1. Rodrigo abre el dashboard al menos 5 de 7 días a la semana.
2. El índice de diversidad de fuentes (% del dominio más repetido) es menor al 40% (comparado con el 60% del chat de Marcello).
3. Rodrigo encuentra noticias relevantes que el grupo de WhatsApp no le estaba dando (ej. cobertura de salud específicamente).
4. El pipeline corre sin intervención manual ≥ 90% de los días.

## 11. Fuera de alcance (v2+)

Funcionalidades que *podrían* sumarse en el futuro si el uso lo justifica:
- Análisis "Implicancia para ASESP" generado por Claude en noticias de salud.
- Exportación semanal a PDF/DOCX para compartir con Natalia o Alfredo.
- Newsletter por email (requiere SMTP o servicio externo).
- Búsqueda full-text sobre el histórico.
- Bookmarks / notas personales sobre noticias.
- Panel de métricas (qué fuentes dominaron el mes, qué temas más cubiertos).

Estas ideas quedan registradas como posibles extensiones, no como compromisos.
