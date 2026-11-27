---
name: skill-import
description: Brings skills made elsewhere into this library - finds skills in a project's own folders, in folders installed from the internet, or in a folder the user points at, judges which ones are reusable, normalizes them to this library's format and proposes the import. Use when the user asks to move skills into the library, import a skill made in another project, vendor or fork a third-party skill, or consolidate skills spread across several projects.
license: MIT
metadata:
  category: maintenance
  requires: "work-protocol"
  version: "1"
---

# Importar skills a la biblioteca

Trae skills que se hicieron en otro lugar a esta biblioteca, con el formato
normalizado y sin romper nada de lo que ya está.

El **contenido** viene de afuera. El **cómo** entra, lo decide esta skill.

## Prerequisites

Cargá la skill **`work-protocol`** antes de esta. Trae los criterios de commit
y la regla `[confirm-scope]`, que aplica: importar a la biblioteca es un
cambio de alcance biblioteca, no de proyecto.

## Fuentes de skills

Las skills pueden estar en varios lados. Revisá **todas** antes de concluir
que algo no existe:

| Dónde | Qué suele haber |
|---|---|
| `<proyecto>/.opencode/skills/` | Skills del proyecto, formato nativo |
| `<proyecto>/.agents/skills/` | Instaladas por `npx skills add` (de internet o de otro repo) |
| `<proyecto>/.claude/skills/` | Compatibilidad con Claude Code |
| `~/.config/opencode/skills/` | Instaladas globalmente |
| `~/.agents/skills/`, `~/.claude/skills/` | Instaladas globalmente, otros agentes |
| La carpeta que te indique el usuario | Lo que sea |

Una misma skill puede estar en más de un lugar. Eso **no** es un conflicto
todavía: el agente elige una por ID, según precedencia.

## Reglas

### [scan-every-source] Revisá todas las fuentes

No concluyas que una skill no existe porque no la viste en la carpeta obvia.
Recorré las de la tabla de arriba, más la ruta que te indique el usuario.

Para cada skill encontrada, anotá: **nombre, origen (ruta), y de dónde vino**
(un repo, un paquete, o hecha a mano).

### [no-clobber] Nunca pises una skill existente

Si el ID que la skill traería ya existe en la biblioteca, **no lo sobrescribas**.

**Decidí por default**: renombrar **la importada**, con un sufijo que la
distinga (`acme-code-review`). Es la opción menos invasiva: no toca nada que
ya está instalado ni published.

Renombrar **la de la biblioteca** solo si la importada es estrictamente
mejor y la de la biblioteca no tiene consumidores. Renombrar la de la
biblioteca rompe las instalaciones que ya la tienen.

**Preguntá solo si** ninguna de las dos opciones es aceptable, o si el
renombre propuesto rompe algo que no podés ver (un lock file de otra máquina,
por ejemplo).

Cuando renombres, cambiale **las dos cosas**: la carpeta y el `name` del
frontmatter. El validador lo exige.

### [classify-reusable] ¿Es reusable o es del proyecto?

| Destino | Cuándo |
|---|---|
| **A la biblioteca** | Sirve en cualquier proyecto: un procedimiento, una convención, un conocimiento |
| **Se queda en el proyecto** | Solo tiene sentido en ese repo: sus rutas, su dominio, su deploy |
| **A la biblioteca, marcada como interna** | Es conocimiento general pero no querés que se anuncie como skill pública |

Una skill de proyecto que se trae a la biblioteca **pierde su contexto**: sin
las rutas y convenciones del repo, es texto genérico. Si además es de un
proyecto ajeno, no la traigas.

### [normalize-frontmatter] Normalizá al formato de esta biblioteca

Cada skill importada tiene que cumplir, sí o sí:

- `name` == nombre de la carpeta, kebab-case, ≤64 caracteres, minúsculas
- `description` **en inglés**: qué hace + cuándo usarla, con las palabras que
  el usuario realmente escribiría. En **una sola línea** (≤1024 caracteres): el
  parser solo lee la primera
- Body **en español**
- `license` presente
- `metadata.category` == la carpeta donde va
- `metadata` con valores **string**
- Si declara `metadata.requires`: cada skill requerida nombrada en la
  sección `## Prerequisites` del body. El agente nunca ve el frontmatter de
  otras skills
- Si declara `metadata.overrides`: el `rule-id` tiene que existir como
  `### [rule-id]` en la skill base
- Reglas con ID (`### [rule-id]`) si van a ser sobrescribibles
- `SKILL.md` < 500 líneas

Si la skill traída no cumple, **normalizala** y decí qué cambiaste. No la
importes cruda: el validador la va a rechazar.

### [preserve-provenance] Dejá constancia del origen

Cada skill importada lleva en el cuerpo una nota de procedencia:

```markdown
> Origen: `<repo o ruta>`, importada el `<fecha>`.
```

Sin eso, en seis meses nadie sabe por qué existe ni si todavía aplica.

### [third-party-is-not-yours] Una skill de internet no se edita donde está

Si la skill viene de un repo ajeno, **no la modifiques en el sitio**: copiala
a la biblioteca y hacé los cambios ahí. Editar el original se pierde en la
próxima actualización, y puede romper el repo de otro.

Dejá en la copia qué cambiaste respecto del original.

### [propose-then-import] Proponé, esperá, después importá

Presentá la propuesta con el formato de `assets/import-proposal-template.md`:
qué se importa, de dónde, a qué categoría, con qué nombre final, y qué
cambios de normalización hiciste.

**Esperá aprobación explícita.** Estás modificando la biblioteca que usan
otras máquinas.

### [validate-against-the-library] El validador decide

```bash
bash tools/validate.sh --write
```

Si falla, **no apliques**. Un ID duplicado o un `requires` roto rompe la
skill en todas las máquinas.

## Reporte

- Qué se importó, de dónde, a qué categoría y con qué nombre final.
- Qué se quedó en el proyecto y por qué.
- Qué no se importó y por qué.
- Qué normalizaciones se hicieron.
- Resultado del validador.

## Detalle

- Protocolo paso a paso: `references/protocol.md`
- Formato de la propuesta: `assets/import-proposal-template.md`
- Prompt neutral y adaptadores por agente: `references/agent-neutral-prompt.md`
