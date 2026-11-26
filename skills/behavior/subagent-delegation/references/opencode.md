# Delegación en OpenCode

Mecánica concreta. Los **criterios** de la skill son portables; esto es
específico de OpenCode.

## Built-in

| Subagente | Para qué | Alcance |
|---|---|---|
| `general` | Investigación y trabajo de varios pasos | Acceso amplio a herramientas. **No** puede lanzar más subagentes |
| `explore` | Buscar y leer código o fuentes web | No edita archivos |

Ambos corren en segundo plano: el padre recibe un informe cuando el hijo
queda idle, y otra vez en cada ronda posterior.

## Lanzar uno

Con la herramienta `subagent`:

```
subagent(agent: "explore", description: "qué busca", prompt: "instrucción autocontenida")
```

- `agent` → el nombre del subagente (`general`, `explore`, o uno propio)
- `description` → una línea de qué busca; aparece en el informe
- `prompt` → la instrucción **autocontenida**. Acá va el 80% del trabajo

## Definir uno propio

Markdown en `~/.config/opencode/agents/<nombre>.md` (global) o
`.opencode/agents/<nombre>.md` (proyecto):

```markdown
---
description: Busca X en el repo y devuelve Y
mode: subagent
model: anthropic/claude-sonnet-5-5
---

Buscá X. Devolvé una lista de archivo:línea con una línea cada uno.
No edites nada.
```

El `description` importa: **es lo que lee el modelo para decidir a quién
lanzar**. Si es vago, el modelo no lo elige nunca.

Los campos disponibles son los mismos que en la config: `description`,
`mode`, `model`, `system`, `permissions`, `steps`, `hidden`, `color`,
`disabled`, `request`.

## Permisos

El padre decide a qué subagentes puede lanzar:

```jsonc
{
  "permissions": [
    { "action": "subagent", "resource": "*", "effect": "deny" },
    { "action": "subagent", "resource": "explore", "effect": "allow" }
  ]
}
```

Cada subagente usa **sus propios** permisos, no los del padre. Un subagente
sin `permissions` declaradas hereda lo global.

Para que un subagente no edite nada:

```jsonc
{
  "action": "edit", "resource": "*", "effect": "deny"
}
```

## Profundidad

`experimental.subagent_depth` define cuántos niveles de subagentes se
permiten. Por default es **1**: los subagentes no lanzan subagentes.

Subirlo no es la solución para una tarea grande: es un problema de
**partición**. Repartí la tarea vos.

## Modo `all`

`mode: all` permite que un agente sea primary **y** subagente. Útil para un
agente que querés como default y también como herramienta de delegación.

## Cosas que sorprenden

- El subagente **no ve** el historial de la conversación. Todo lo que
  necesite, va en el prompt.
- El subagente **no ve** lo que otro subagente encontró.
- El informe es un resumen. Verificá los hallazgos que tocan código.
- Un subagente mal definido (description vaga) simplemente no se elige.
- Los subagentes corren en background: el padre sigue trabajando mientras
  esperan. Aprovechalo para paralelizar de verdad, no para esperarlos.
