# Importación con varios agentes

El cuerpo de `skill-import` es el mismo en todos lados: es una skill con
formato estándar. Lo que cambia de un agente a otro es cómo se invoca, cómo
encuentra la ruta de la biblioteca y cómo se llama el mecanismo de aprobación.

Este archivo separa las tres cosas para que el flujo no dependa de OpenCode.

## Prompt neutral

Copiar este bloque en el agente que corresponda, sin adaptarlo:

```text
Usá la skill `skill-import` con el mecanismo de tu agente y seguí sus reglas
(especialmente [propose-then-import] y [no-clobber]).

Objetivo: traer a la biblioteca de skills las skills reutilizables de este
proyecto. La biblioteca está en la ruta que indica tu archivo de instrucciones;
si no está, buscala en ~/my-skills. Todavía NO escribas nada en la biblioteca,
no hagas commit ni publiques nada.

Fase 1 — Inventario:
- Recorré todas las fuentes: .opencode/skills, .agents/skills y .claude/skills
  del proyecto, más las globales que correspondan a tu agente.
- Listá cada candidata con nombre, ruta de origen y de dónde viene.
- Si una misma skill aparece en varios lados, decime cuál usás y por qué.

Fase 2 — Clasificación y colisiones:
- Por cada una: ¿reutilizable, se queda en el proyecto, o interna? Justificá
  en una línea.
- Detectá colisiones con los IDs de la biblioteca, con skills de internet y
  entre las propias candidatas.
- Aplicá los defaults de la skill (renombrar la importada, no pisar nada).
  Preguntame solo lo que no se pueda decidir con esas reglas.

Fase 3 — Normalización:
- Por cada skill que entre, decime qué vas a cambiar: name, description
  (inglés, una línea), body, category, metadata, requires/overrides, reglas
  con ID, referencias a archivos, y cómo dividís si pasa de 500 líneas.

Fase 4 — Propuesta y pare:
- Presentá la propuesta con el formato de
  skills/maintenance/skill-import/assets/import-proposal-template.md:
  tabla completa por skill, colisiones y diff.
- Si algo no está claro (qué proyecto, qué skills entran, categoría, nombre
  final), preguntamelo ANTES de proponer. No lo asumas.
- PARÁ acá. Esperá mi "aprobado" o mi corrección. No escribas archivos,
  no commitees ni publiques nada hasta que te lo diga explícitamente.
```

El último bloque es la regla de conducta, no un permiso: en los agentes que
tienen permisos configurables, la aprobación del cliente puede reforzarla,
pero nunca la reemplaza.

## Cómo invocar la skill

| Agente | Mecanismo |
| --- | --- |
| OpenCode | El catálogo se anuncia en cada paso; `@skill-id` o la herramienta `skill` |
| Claude Code | `/skill-name`, o invocación automática por la `description` |
| Codex CLI | `$skill-name` o el selector `/skills` |
| Cursor | Mencionarla por nombre en el pedido; los agentes en la nube pueden no ver skills locales sin sincronizar |
| Gemini CLI | Mencionarla por nombre o usar el selector de skills |

Si el agente no anuncia la skill, no se la puede cargar: revisar primero la
tabla de fuentes de `skill-import` y el directorio de instalación.

## Dónde viven las instrucciones permanentes

| Agente | Instrucciones siempre activas |
| --- | --- |
| OpenCode | `~/.config/opencode/AGENTS.md`, más la del proyecto |
| Claude Code | `~/.claude/CLAUDE.md` y la del proyecto; también lee `AGENTS.md` si no hay `CLAUDE.md` (v2.1.277 o posterior) |
| Codex CLI | `~/.codex/AGENTS.override.md` o `~/.codex/AGENTS.md`, más los `AGENTS.md` del proyecto |
| Cursor | `.cursor/rules/*.mdc` |
| Gemini CLI | `GEMINI.md` |

En Claude Code, un `CLAUDE.md` con `@AGENTS.md` importa el archivo compartido
sin duplicar las reglas. Si ese agente trae instrucciones propias de git que
sugieren publicar, desactivarlas con `includeGitInstructions: false` en la
configuración del usuario.

## Verificación por agente

- **OpenCode:** los cambios de configuración se recargan solos; `/reload`
  fuerza la recarga si una skill no aparece. Si hay IDs repetidos, gana la
  fuente registrada más tarde.
- **Claude Code:** `/context all` lista los archivos de instrucciones cargados.
  La lectura directa de `AGENTS.md` necesita v2.1.277 o posterior.
- **Codex CLI:** si una skill instalada no aparece, reiniciar el agente. Con
  IDs repetidos no mergea: pueden aparecer las dos en el selector.
- **Cursor:** Agent Skills está en beta; verificar que el agente vea la skill
  antes de depender del flujo.
- **Gemini CLI:** las skills de usuario van en `~/.gemini/skills` o en
  `~/.agents/skills`; las de extensión se cargan con la extensión.

## Adaptadores delgados

Estos archivos no contienen reglas: solo apuntan a la fuente compartida. Ir
después del archivo de instrucciones ya existente de cada agente, sin borrar
nada.

OpenCode, Codex, Cursor y Gemini pueden apuntar a `AGENTS.md` o a
`~/.agents/skills` según el agente. Claude Code necesita un archivo propio:

```markdown
@AGENTS.md

- La biblioteca de skills está en ~/my-skills.
- Para traer skills de un proyecto, usar `skill-import`.
```

La ruta exacta se resuelve desde el archivo de instrucciones del agente, no
se escribe a mano en el cuerpo de ninguna skill.
