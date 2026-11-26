# Inbox de aprendizaje

<!--
  PLANTILLA. La copia viva de cada maquina esta en
  {{REPO_PATH}}/.learning/inbox.md, que esta en .gitignore.

  REPO_PATH se sustituye por la ruta real del repo cuando el bootstrap
  instala este bloque. En la raiz del repo, la ruta es `.learning/inbox.md`.

  La copia viva es LOCAL de la maquina: no viaja, no se commitea. Es el unico
  registro de lo que se aprendio en ESA maquina hasta que se concilie.

  Flujo:
    1. El agente detecta una correccion reutilizable y agrega una entrada
       abajo.
    2. Cuando pidas "conciliar lo aprendido", el agente lee ESTE archivo en la
       maquina donde esta, agrupa las entradas por destino y propone cambios
       concretos a las skills.
    3. Con tu aprobacion, aplica los cambios, valida, y pushea.
    4. Las entradas conciliadas o descartadas se borran de la copia viva.
    5. La limpieza se verifica con
       skills/maintenance/learning-reconcile/scripts/check-inbox.sh antes de
       cerrar: las pendientes se quedan y se reportan.

  No borres entradas sin conciliarlas: son el unico registro de lo que se
  aprendio en esta maquina.
-->

## Formato de una entrada

Copiá este bloque por cada entrada nueva y agregalo al final del archivo. El
ID `L-<fecha>-<hora>-<maquina>` ordena las entradas y permite referenciarlas
sin ambiguedad. Los campos con guiones son parseables: cuando haya
comunicacion entre agentes, se pueden extraer y exportar sin perder estructura.

```markdown
## L-<fecha>-<hora>-<maquina>

- **tipo**: `<correccion | caso>`
- **skill**: `<skill-id>` (a la que aplica, o `nueva`)
- **regla**: `<rule-id>` (la que deberia cambiar, o `nueva`)
- **proyecto**: `<repo>` (donde se aprendio)
- **cuando**: `<ISO-8601>`
- **maquina**: `<hostname>`

**Que paso:**

**Regla:**

**Trigger:**
```

<!--
  tipo = correccion  → el agente hizo algo mal. Suele endurecer una regla.
  tipo = caso        → se resolvió algo reutilizable (una decisión de diseño,
                       un conflicto desempatado, un gotcha). Suele ser
                       conocimiento nuevo, no una corrección.

  Los dos van al mismo inbox: es el mismo mecanismo de captura, con dos
  intenciones distintas.
-->
