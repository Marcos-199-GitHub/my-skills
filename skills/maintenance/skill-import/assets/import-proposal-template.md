# Propuesta de importación

Formato de lo que se presenta al usuario antes de importar nada.

Objetivo: que la aprobación sea sobre un cambio concreto, con la procedencia
visible y las normalizaciones declaradas.

---

## Resumen

| Skill | Origen | Categoría | Nombre final | Acción |
|---|---|---|---|---|
| `acme-deploy` | `<proyecto>/.agents/skills/acme-deploy/` | `project/` | `acme-deploy` | importar |
| `code-review` | `<repo>/skills/code-review/` | `general/` | `acme-code-review` | importar renombrada |
| `acme-oncall` | `<proyecto>/.opencode/skills/acme-oncall/` | — | — | se queda en el proyecto |

<N> candidatas · <N> a importar · <N> a renombrar · <N> a dejar en el proyecto

---

## Colisiones con la biblioteca

| ID | Ya existe en | Resolución propuesta |
|---|---|---|
| `code-review` | `general/code-review` (de esta biblioteca) | renombrar la importada a `acme-code-review` |

<Ninguna> / listar cada una.

---

## Importación 1 — `<nombre-final>` → `<categoría>/<nombre-final>`

**Origen:** `<ruta o repo>`
**Motivo de la categoría:** <por qué va acá y no en otra>

**Normalizaciones:**

- `name`: `<antes>` → `<después>`
- `description`: <qué se reescribió y por qué>
- `metadata.category`: <antes> → <después>
- Reglas con ID agregadas: `<rule-id>`
- Referencias a archivos: <qué se trajo o qué se sacó>

**Procedencia** (se agrega al body):

> Origen: `<repo o ruta>`, importada el `<fecha>`.

```diff
--- /dev/null
+++ b/skills/<categoria>/<nombre-final>/SKILL.md
@@ ...
```

---

## Se queda en el proyecto

- `<nombre>` — <por qué no es reusable: depende de X / es de un repo ajeno>
