# Plantillas de registro de aprendizaje

Dos formatos según dónde va el registro.

---

# 1. Entrada del inbox (cruda, local de la máquina)

Va en `~/my-skills/.learning/inbox.md`, que está en `.gitignore`. Es el único
registro de lo que se aprendió en esa máquina hasta que se concilie.

Plantilla completa en `assets/learning-inbox.md`.

```markdown
## L-<fecha>-<hora>-<maquina>

- **tipo**: `<correccion | caso>`
- **skill**: `<skill-id>` (a la que aplica, o `nueva`)
- **regla**: `<rule-id>` (la que debería cambiar, o `nueva`)
- **proyecto**: `<repo>` (dónde se aprendió)
- **cuando**: `<ISO-8601>`
- **maquina**: `<hostname>`

**Qué pasó:**

**Regla:**

**Trigger:**
```

**Reglas de una buena entrada:**

- El ID `L-<fecha>-<hora>-<maquina>` la hace ordenable y referenciable.
- **`tipo` decide el destino**: una `correccion` endurece una regla que
  ya existe; un `caso` es conocimiento nuevo.
- **`skill` y `regla` son la parte importante**: son lo que permite conciliar
  sin releer todo. Si no sabés a qué aplica, probablemente no sea reutilizable.
- **Qué pasó** en una frase concreta, no genérica.
- **Regla** imperativa y verificable. "Usá siempre X" sí; "sé más cuidadoso"
  no.
- **Trigger** en qué situación aplica. Sin trigger, la lección no se aplica
  nunca.

---

# 2. Lección conciliada (dentro del repo, versionada)

Va dentro del `SKILL.md` de la skill a la que aplica, como una regla con ID:

```markdown
### [rule-id] Título imperativo

<Regla concreta, con el detalle suficiente para aplicarla.>
```

Si el aprendizaje es global pero no pertenece a ninguna skill concreta, va en
`references/lessons.md` de esta skill.

```markdown
## <fecha> — <título>

**Qué pasó:** <qué se hizo mal y por qué>

**Regla:** <regla a seguir>

**Trigger:** <cuándo aplica>
```

---

# Checklist para agregar una lección

- [ ] ¿Es un error que se iba a repetir? Si fue un typo de una línea, no va.
- [ ] ¿La regla es verificable?
- [ ] ¿Tiene trigger?
- [ ] ¿Es del proyecto o global? → `AGENTS.md` del proyecto, o inbox.
- [ ] ¿Ya estaba cubierta? Si sí, no hace falta una entrada nueva.
