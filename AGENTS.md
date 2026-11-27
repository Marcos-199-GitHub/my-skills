# Reglas de este repo

Este repo es una **biblioteca de skills** (formato Agent Skills,
[agentskills.io](https://agentskills.io)). Todo lo que hay adentro es
reutilizable, portable y versionado.

Lee `README.md` para el panorama. Acá está lo operativo.

## Comandos

```bash
bash tools/validate.sh           # validar todo
bash tools/validate.sh --write   # regenerar el índice del README
bash tools/validate.sh --check   # falla si el índice quedó viejo (lo que corre CI)
bash tools/validate.sh --graph   # ver el grafo de dependencias
bash tools/smoke-test.sh         # prueba las decisiones de los scripts
```

Stack: bash + markdown + YAML. Sin package manager, sin dependencias externas.

## Layout

```
skills/<categoria>/<nombre>/SKILL.md
```

- El **ID** de una skill es el nombre de la carpeta hoja. `name` del
  frontmatter, ID y carpeta **coinciden siempre**. El validador lo exige.
- Mover una skill de categoría no cambia su ID.
- `references/` para documentación, `assets/` para plantillas y archivos
  estáticos, `scripts/` para código ejecutable.

## Cómo se escribe una SKILL.md

```yaml
---
name: kebab-case-en-minusculas
description: One sentence, in English: what it does AND when to use it.
license: MIT
compatibility: Requires <requisitos de entorno>.   # opcional
metadata:
  category: general
  version: "1"
---
```

- **`description` en inglés.** Es lo único que el modelo ve para decidir si
  carga la skill. Si no dice *cuándo* usarla, nunca se carga. Incluí las
  palabras que el usuario realmente escribiría.
- **Body en español.**
- **`metadata` con valores string.** La spec solo admite `string -> string`.
  Para listas, usá CSV: `tags: "a,b,c"`.
- **`metadata.category` tiene que coincidir con la carpeta.** El validador lo
  comprueba.
- **`compatibility` es opcional**, y solo si la skill tiene requisitos de
  entorno reales: una sola línea, de ≤500 caracteres.

## Reglas con ID

Toda regla que otra skill pueda sobrescribir lleva un ID estable:

```markdown
### [confirm-scope] Preguntar antes de tocar el scope del usuario
```

El ID va en el encabezado. El validador comprueba que un `overrides` apunte a
una regla que exista de verdad.

## Composición

```yaml
metadata:
  requires: "otra-skill,otra-mas"
  overrides: "otra-skill#rule-id"
```

- `requires` → skills base. **Cada una tiene que aparecer nombrada en la
  sección `## Prerequisites` del body.** El agente nunca ve el frontmatter de
  otras skills: si no está en el body, no se carga.
- `overrides` → `base#rule-id`. La base tiene que existir y la regla tiene que
  existir en ella.
- **Cada capa es un delta**, nunca una reformulación de la base. Si la skill
  hija repite el texto de la base, no hay herencia: hay duplicación.
- **Máximo dos niveles de cadena.** Tres skills cargadas por tarea es
  contexto que no vuelve.

## Pautas de creación

1. **Partí de una sesión real.** Una skill escrita de la nada, sin evidencia,
   es texto genérico que el modelo ya sabe. Extraela de algo que sí funcionó:
   qué pasos funcionaron, qué te corregiste, qué formatos usaste.
2. **Una skill = una unidad coherente de trabajo.** Si necesita dos skills
   para una sola tarea, está demasiado dividida.
3. **Progressive disclosure.** `SKILL.md` es lo que se carga siempre: menos de
   500 líneas. El detalle va a `references/`, y el agente lo lee cuando el
   body le dice que lo haga.
4. **Agregá lo que el modelo no sabría.** No expliques cómo funciona HTTP ni
   qué es un índice. Escribí lo específico: las convenciones del proyecto, los
   procedures, los casos límite.
5. **Fijate el default.** Si hay dos formas válidas de hacer algo, elegí una y
   mencioná la alternativa como escape hatch. No presentes un menú de
   opciones iguales.
6. **Un script, no una instrucción.** Si el agente va a reimplementar la misma
   lógica en cada corrida, empaquetala en `scripts/`.
7. **Probala en un agente real.** Escrita no es probada.

## Criterios de aceptación de una skill

- [ ] `bash tools/validate.sh` pasa sin errores
- [ ] La `description` dispara con 2 o 3 prompts reales (no solo con el ideal)
- [ ] El body no repite lo que el modelo ya sabe
- [ ] Las reglas con ID son las que realmente se pueden sobrescribir
- [ ] Cada `requires` está nombrado en `## Prerequisites`
- [ ] Cada `overrides` apunta a una regla `[id]` que existe
- [ ] Los paths citados existen
- [ ] Probada en un agente real, no solo escrita
- [ ] `bash tools/validate.sh --write` deja el índice del README al día

## Aprendizaje

El detalle está en `README.md` (sección `## Aprendizaje`), en la skill
`learning-reconcile` y en `work-protocol` (`[learn-from-error]`). Acá solo lo
operativo:

- El inbox es `~/my-skills/.learning/inbox.md`: local, gitignored, no se
  commitea. El formato de entrada está en `assets/learning-inbox.md`.
- La conciliación se pide, se propone, **se espera aprobación**, se aplica,
  se valida, se limpia con `skills/maintenance/learning-reconcile/scripts/check-inbox.sh`
  y recién entonces se cierra con el push. La regla es
  `learning-reconcile#clean-the-inbox`.
- El contenido vive en la skill; el índice es
  `skills/behavior/work-protocol/references/lessons.md`, no una fuente.

## Importar skills

Las skills que se hicieron en un proyecto, o las de internet que querés
customizar, se traen con la skill `maintenance/skill-import`. No es un copy:
la skill normaliza al formato de esta biblioteca, decide la categoría, resuelve
colisiones de ID **sin pisar nada**, deja la procedencia y valida.

Criterio de decisión, en una línea: **lo reusable viene, lo específico del
proyecto se queda**. Una skill que depende de las rutas de un repo, sin ese
repo, es texto genérico.

## Decisiones

Las decisiones no triviales se resuelven con las dos lentes de `work-protocol`
(`[decide-two-lenses]`): qué dice el repo y qué dice la industria, con síntesis
explícita. Se decide propio salvo que haya dos opciones igual de buenas sin
criterio que las separe, o sea preferencia personal (`[decide-or-ask]`).

## Herramientas

El manifiesto universal es `skills/environment/dev-tooling/assets/tools.conf`;
el catálogo (`skills/environment/dev-tooling/references/tool-catalog.md`) dice
para qué sirve cada herramienta y cuál se descartó. El detalle está en la skill
`dev-tooling` y en `README.md`. Acá solo lo que cambia lo que hacés:

- **Docker siempre que se pueda**, sobre todo para toolchains (python, node,
  java, kotlin, C#, go, rust): van como imagen, no instalados.
  `bash tools/docker-run.sh <imagen> <comando>`.
- Los binarios chicos del manifiesto van nativos: el camino caliente no puede
  pagar un contenedor por llamada.
- **Sin pins** salvo que una major rompa de verdad.
- Las herramientas del proyecto van en `<proyecto>/.agent-tools.conf` y las
  decide el agente leyendo el repo.

## Rendimiento

La regla es `[optimize-by-default]` de `work-protocol`; el detalle y las
mediciones están en `README.md`. Presupuesto de `validate.sh`: menos de 1 s
(medido ~0,46 s). Si se pasa, medir qué creció antes de optimizar. Los checks
nuevos llevan su caso negativo en `tools/smoke-test.sh`.

## Markdown

El texto de la biblioteca es la parte que más se rompe: se cuelan caracteres
de otro alfabeto, palabras en inglés y markdown mal formado.

- `tools/lint-md.sh` lo detecta: alfabetos ajenos, palabras en inglés
  filtradas, guion bajo dentro de una palabra, heading sin línea en blanco
  después, code fences desbalanceados y espacios al final.
- Corre dentro de `validate.sh` y en el CI. Un `.md` con un error **no entra**.
- Al escribir prosa: español, salvo nombres de comandos, archivos, APIs y
  variables de entorno. Si una palabra en inglés es inevitable, va en
  backticks.
- **`.gitattributes` fuerza LF en los `.sh`.** El repo se edita en Windows: sin
  eso, git convierte los scripts a CRLF y bash deja de poder ejecutarlos
  (`bad interpreter: /bin/sh^M`). No lo quites.

## Reglas de este repo

- **No edites el índice de skills del README a mano.** Se genera con
  `tools/validate.sh --write`.
- **Los payloads con marcadores se reponen completos.** Si el archivo del
  payload ya trae sus propios marcadores (`<!-- my-skills:begin/end -->`),
  reemplazá el bloque entero, marcadores incluidos. Reemplazar solo el
  contenido *entre* los marcadores reimprime el de cierre y lo duplica.
- **Una regla, una fuente.** Si una regla vive en la skill, en el payload y en
  el agente, las dos últimas son copias derivadas marcadas con
  `<!-- source: skill#rule-id -->` y el validador comprueba que el ID exista.
  No edites una copia sin cambiar la fuente. Ver `[single-source-of-truth]`.
- **No agregues archivos en la raíz** sin justificarlo. La raíz está reservada
  a `README.md`, `AGENTS.md`, `LICENSE`, `.gitignore` y `.gitattributes`; todo
  lo demás va en su carpeta.
- **No rompas la portabilidad.** Las skills son para cualquier agente. No
  metás config de un agente concreto dentro de una skill: eso va en
  `agents/` (definiciones de agente) o en `assets/` (payloads).
- **El `AGENTS.md` que escriben las skills de entorno tiene que ser
  portable**: describe el proyecto, nunca menciona nombres de herramientas de
  edición ni esta biblioteca.
- **Commiteá según el protocolo**: un commit incluye código, documentación y
  pruebas del mismo cambio, con las revisiones pasando. Ver `work-protocol`.
- **Cada check nuevo tiene su caso negativo.** El validador es la red de
  seguridad de todas las máquinas: un agujero suyo deja pasar el error a
  otro lado sin que nadie lo vea acá. Cuando agregues un check, escribí el
  caso que hoy no se cubre y probá que el validador falla con él.
- **La config de distribución va en `opencode.json` del repo**, no en
  `agents/main-agent.md`: ese agente es el default de todos los proyectos.
  El archivo está en la raíz a propósito —es lo que OpenCode descubre— y
  lleva las excepciones bajo `agents.main-agent.permissions`.
- **Los remotes**: `origin` es GitHub (repo privado principal, lo que usa
  GitHub Desktop), `gitea` es Gitea (distribución). El push normal a `gitea`
  es automático **en este repo** (`opencode.json`); en otros proyectos rige
  el gate general del agente. Los force-push y el push a `origin`/GitHub sí
  piden confirmación.

## Flujo

```bash
bash tools/validate.sh           # validar
bash tools/validate.sh --write   # regenerar el índice del README
bash tools/validate.sh --graph   # ver el grafo de dependencias
git add -A && git commit -m "..."
```

Ciclo completo de una conciliación:

```bash
cat ~/my-skills/.learning/inbox.md        # 1. leer lo aprendido
# 2. proponer cambios y esperar aprobación
bash tools/validate.sh --write           # 3. validar
git commit -m "..." && git push gitea main   # 4. distribuir
# 5. en las otras máquinas:
git -C ~/my-skills pull --ff-only gitea main && bash ~/my-skills/tools/validate.sh --check
```
