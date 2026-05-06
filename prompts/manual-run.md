# Daily IA News - Corrida Manual

Vas a correr el pipeline de Daily IA News a mano. Seguí exactamente las instrucciones de `/Users/rodrigoramosaguirre/DAILY-IA-NEWS/prompts/daily-pipeline.md`.

**Fecha de hoy:** [ESCRIBIR LA FECHA EN FORMATO YYYY-MM-DD ACÁ ANTES DE PEGAR, ej. 2026-04-18]

**Fecha en español:** [ESCRIBIR LA FECHA LEGIBLE, ej. viernes 18 de abril de 2026]

---

Esto es para DEBUG. Además de generar los archivos, mostrame explícitamente en tu respuesta:

1. **Candidatos juntados** (lista): source, title, score (aunque sea numérico aproximado), category.
2. **Selección final** (5-7): número, title_es, source_domain, score, category.
3. **Chequeo de diversidad**: dominios usados y cuántas veces cada uno. Verificar que ninguno aparece > 2 veces.
4. **Chequeo de categorías**: cuántas de cada (tech/business/health). Verificar que hay ≥ 1 de cada.
5. **Resúmenes en español**: los 5-7 textos finales, para que Rodrigo pueda chequear tono rioplatense.
6. **Confirmación de archivos escritos**: que se creó `archive/YYYY-MM-DD.html`, se actualizó `index.html`, y se actualizó `index-data.json`.
7. **Fuentes sin respuesta**: cuáles fallaron al hacer fetch.

Después del output, esperá: Rodrigo puede pedirte ajustes al prompt o a alguna noticia específica.
