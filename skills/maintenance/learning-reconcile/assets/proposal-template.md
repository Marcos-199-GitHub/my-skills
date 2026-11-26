# Propuesta de conciliación

Formato de lo que se presenta al usuario antes de aplicar nada.

Objetivo: que la aprobación sea sobre un **cambio concreto**, no sobre una
idea. Si el diff no está, no hay nada que aprobar.

---

## Resumen

| # | Entrada | Destino | Acción |
|---|---|---|---|
| `L-...` | <qué se aprendió> | `<skill>` → `[<regla>]` | endurece / nueva / skill nueva / proyecto / descartar |

<N> entradas · <N> a aplicar · <N> a descartar · <N> pendientes

---

## Grupo 1 — `<skill>` → `[<regla>]`

<Una línea: qué cambia y por qué.>

**Debilita una regla existente:** sí / no. Si es sí, explicá cuál y por qué.

```diff
--- a/skills/<cat>/<skill>/SKILL.md
+++ b/skills/<cat>/<skill>/SKILL.md
@@ ...
```

---

## Grupo 2 — `<skill>` → regla nueva `[<regla-id>]`

<Una línea: qué se agrega y por qué.>

```diff
--- a/skills/<cat>/<skill>/SKILL.md
+++ b/skills/<cat>/<skill>/SKILL.md
@@ ...
```

---

## Grupo 3 — skill nueva

<Una línea: qué procedimiento nuevo entra y por qué.>

```diff
--- /dev/null
+++ b/skills/<cat>/<skill-nueva>/SKILL.md
@@ ...
```

---

## Grupo 4 — `AGENTS.md` de un proyecto

<Una línea: qué se agrega al proyecto y por qué no va a la biblioteca.>

```diff
--- a/<proyecto>/AGENTS.md
+++ b/<proyecto>/AGENTS.md
@@ ...
```

---

## Entradas que se descartan

- `L-...` — <motivo>

## Entradas que quedan pendientes

- `L-...` — <motivo: no aprobado, o de otro proyecto>
