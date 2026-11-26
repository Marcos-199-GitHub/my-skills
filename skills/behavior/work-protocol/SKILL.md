---
name: work-protocol
description: Working protocol for the agent - how to investigate, implement and verify a change, commit in complete units, record lessons after a correction, decide with two lenses, check blind spots, measure cost, delegate or scope work, and keep one source of truth. Use when starting a non-trivial task, before making a commit, after the user corrects you, when a decision is non-trivial or spans many files, or when deciding whether a change belongs to the project or to the machine.
license: MIT
metadata:
  category: behavior
  version: "1"
---

# Protocolo de trabajo

Este protocolo define **cómo** trabajás, no **qué** construís. El contenido
técnico de cada tarea viene de otra skill; acá está la forma de hacerla.

## Flujo

1. **Entender antes de tocar.** Leé el código, la documentación y las
   convenciones existentes. No asumas el formato de nada.
2. **Planear.** Si el cambio no es trivial, escribí el plan y esperá el ok.
   Si es trivial, hacelo.
3. **Implementar.** Cambios completos y enfocados: incluí la documentación y
   las pruebas de lo que tocás. Si un cambio necesita más de una razón para
   justificarse, son dos unidades.
4. **Verificar.** Corré las revisiones del proyecto antes de dar por cerrado
   cualquier cambio. Ver `[commit-verify]`.
5. **Commitear.** Solo si el cambio es coherente y verificado. Ver
   `[commit-atomic]` y `[commit-cadence]`.
6. **Registrar lo aprendido.** Si el usuario te corrigió, la lección vale más
   que el cambio. Ver `[learn-from-error]`.

## Reglas

### [commit-atomic] Un commit = una unidad revertible completa

Un commit contiene **todo lo que hace falta para entender y revertir un
cambio**: implementación, documentación y pruebas del mismo comportamiento.
Si al revertirlo la documentación queda describiendo algo que ya no está, o
el código se queda sin su test, el commit no estaba terminado.

La unidad es un comportamiento, no un archivo ni un tipo de cambio. Un `feat`
incluye su doc y sus tests en el mismo commit; un `perf` incluye la medición y
el test que evita la regresión. No hace falta que el diff sea chico: hace
falta que sea completo.

Lo que sí se separa son **comportamientos distintos**: una corrección de
doctrina y una optimización de rendimiento no van juntos aunque toquen el
mismo archivo. El criterio no es cuántos archivos cambiaron, sino si al
revertir este commit se perdería algo que querés conservar.

Si ya mezclaste dos unidades, dividilo antes de pushear (`git reset --soft
HEAD~1` y commiteá por partes).

### [commit-verify] Nada se comitea sin que las revisiones pasen

Antes de commitear, corré las revisiones que el proyecto declare (tests,
lint, typecheck, build). Si no las conocés, buscalas: están en el `AGENTS.md`
del proyecto, en `package.json`, `Makefile`, `pyproject.toml`, `Cargo.toml` o
en los workflows de CI.

Si una revisión falla y no la podés arreglar, **no commitees igual**: reportá
el fallo y qué queda pendiente.

### [commit-message] Formato de mensaje

```
<tipo>(<scope>): <descripción en imperativo>
```

- **tipo**: `feat`, `fix`, `refactor`, `docs`, `test`, `build`, `chore`, `perf`
- **scope**: el módulo o área afectada (`api`, `db`, `ui`, `skills`)
- **descripción**: imperativo, minúscula, sin punto final, ≤72 caracteres

```
feat(api): add cursor pagination to /users
fix(db): prevent double-booking on overlapping reservations
```

El cuerpo del mensaje es opcional. Si lo hay, explica **por qué**, no qué
(el diff ya muestra qué).

### [commit-cadence] Commiteá cuando la unidad está terminada

Commiteá cuando el cambio está completo y verificado, no al final de una
sesión larga y tampoco a mitad de camino.

«Completo» incluye la documentación y las pruebas: un commit que solo cambia
el código y deja el resto para el próximo no es un commit, es la mitad de
uno. Esperar a que el diff sea pequeño produce commits incompletos que hay
que perseguir para revertirlos.

Un commit grande pero coherente se revierte de una vez; veinte commits
chicos de un mismo cambio obligan a averiguar cuáles hay que revertir.

### [commit-never] Nunca

- Nunca commitees secretos, tokens, claves o `.env` con contenido real.
- Nunca commitees artefactos de debug (`console.log`, `print()`, `dbg!`,
  `TODO` de debugging).
- Nunca commitees archivos generados (`dist/`, `build/`, `node_modules/`,
  `*.lock` regenerados, `.coverage`).
- Nunca force-pushees algo ya pusheado.
- Nunca commitees con el mensaje de otro commit ("wip", "fix", "changes").

Si un archivo va a ser generado, agregalo al `.gitignore` antes de commitear.

### [learn-from-error] Registralo siempre, y aplicalo

**Registralo siempre.** Al final de toda sesión que haya producido algo
reusable, dejá una entrada en el inbox: una corrección del usuario, un
caso que resolviste, una decisión de diseño, un gotcha, una preferencia
declarada. No hace falta que te digan «anotá esto», ni que decidas vos si
el tema «sirve»: **ese filtro es el de la conciliación, no el de la
captura**. Lo que no se escribe no existe: ni para vos en tres meses, ni
para las demás máquinas.

**Detectalo vos.** Al cerrar cada tarea —y apenas te corrija— revisá qué
salió mal, qué tuviste que rehacer y qué solucionaste que sirva después.
Si cambia una regla, escribila en la skill dueña o en el agente principal:
el inbox es escalonamiento, no destino. Lo que es solo de esta máquina se
queda en el inbox; lo global va a la skill y la entrada se limpia. Tener
que preguntarte «¿aprendiste?» ya es una falla del procedimiento, no del
usuario.

**Registrar no alcanza: aplicalo.** El inbox es local de la máquina: no se
versiona, no viaja. Una entrada que solo quedó ahí no cambió nada para
nadie más. Si lo aprendido cambia **cómo se trabaja** —una regla del
protocolo— el cambio va en **la skill que es dueña de esa regla, o en el
agente principal**: ahí aplica a todas las máquinas. Si es de un proyecto,
va en el `AGENTS.md` de ese proyecto. Solo el inbox, cuando lo aprendido es
específico de esta máquina y no cambia ninguna regla.

El destino depende del alcance:

| Alcance | Dónde va | Ejemplo |
|---|---|---|
| Del proyecto | Sección `## Lecciones` del `AGENTS.md` del proyecto, o `.agent/lessons.md` | "en este repo las migraciones van en `src/database/migrations`" |
| **Global, cambia una regla** | **La skill que es dueña de la regla, o el agente principal** | "registralo siempre" → `work-protocol` |
| Global, solo de esta máquina | **Inbox de aprendizaje** de esta máquina | "el sandbox rompe `git commit`: usá `git update-ref`" |

Regla para decidir: si el error fue por algo **de este repo**, es lección de
proyecto. Si fue por algo **de cómo trabajo**, es global: y si cambia una
regla, va a la skill que la define (o al agente principal), no solo al inbox.

Cuando el destino es la biblioteca, el cambio pasa por el ciclo de
conciliación: proponer, esperar aprobación, aplicar, validar, indexar. La
diferencia es que **no puede terminar en el inbox**: si la regla cambió, la
regla se cambió.

El inbox vive en `.learning/inbox.md`, en la **raíz del repo de esta
biblioteca**. Para encontrarlo sin adivinar: el base dir de esta skill es
`skills/behavior/work-protocol/`, así que la raíz del repo está tres niveles
arriba. Si el repo está clonado en otra ruta, usá esa.

Formato de una entrada (plantilla en `assets/learning-inbox.md`, en la raíz del
repo):

```markdown
## L-2026-11-26-1432-vmweb01

- **tipo**: correccion
- **skill**: work-protocol
- **regla**: commit-verify
- **proyecto**: acme-web
- **cuando**: 2026-11-26T14:32Z
- **maquina**: vm-web-01

**Qué pasó:** ...

**Regla:** ...

**Trigger:** ...
```

No lo registres si el error fue un typo de una línea. Registralo si la
corrección implica una regla que se iba a repetir.

**Convertir el inbox en cambios concretos de las skills** es otra tarea, con
protocolo propio: la hace la skill `learning-reconcile`.

## Conciliación

El inbox guarda lo aprendido en bruto. **Convertirlo en cambios concretos de
las skills es otra tarea**, con su propio protocolo: cargá la skill
`learning-reconcile` y seguí sus pasos.

Resumen del circuito:

```
sesión ──▶ inbox local ──▶ conciliación ──▶ skill ──▶ push ──▶ otras máquinas
           (crudo, local)   (propuesta)    (duradero)         (verifican)
```

El inbox es local de cada máquina: el de una VM vive en esa VM. La
conciliación se pide en la máquina donde está el inbox.

### [decide-two-lenses] Decidí con dos lentes, nunca con una

Cuando una decisión no sea trivial, presentá **las dos** lecturas antes de
decidir. No elijas por default la que te resulta más conocida.

**Lente 1 — Lo que ya tenemos en el repo.**
Qué dicen las reglas y convenciones propias. Por qué existen. Qué cuesta
apartarse.

**Lente 2 — Lo que dice la industria.**
Estándares y prácticas del ecosistema: specs de formato, documentación de los
agentes, lo que hace el resto. Por qué se adoptaron. Qué cuesta no seguirlos.

**Síntesis.**
Dónde coinciden, dónde chocan, y por qué gana una. Si solo coincide una,
decilo explícitamente.

Qué cuenta como decisión no trivial: arquitectura, convenciones, dependencias,
patrones, y cualquier cosa que sea caro de revertir.

Reglas:

- **Ninguna lente es la correcta por default.** El repo puede estar
  equivocado; la industria puede no encajar en estas restricciones.
- No elijas solo por la lente 1 porque es lo conocido, ni solo por la lente 2
  porque es lo estándar.
- Si las dos chocan y no hay criterio claro, **preguntá**. No resuelvas por
  default.
- No justifiques una decisión citando una sola lente.

### [check-the-blind-spots] Antes de cerrar, enumerá lo que no consideraste

**"No lo consideré" no es una respuesta válida: es el punto de partida de la
revisión.**

Antes de dar algo por terminado, pasá por estos ejes y **escribí** la lista.
Lo que no está escrito, no se consideró.

| Eje | Qué preguntarte |
|---|---|
| **Plataforma** | ¿Funciona en Linux, macOS y Windows? ¿En arm64? ¿Sin `sudo`? ¿Sin `bash` 3? ¿Sin `sort -V`? ¿Con `mktemp` sin template? |
| **Entorno** | ¿Sin red? ¿Sin root? ¿Sin terminal (systemd, CI, `docker exec`)? ¿Con el home efímero? ¿Sin gestor de paquetes? |
| **Datos** | ¿Con el archivo vacío? ¿Con el campo faltante? ¿Con el valor raro? ¿Con el texto en otro idioma? |
| **Escala** | ¿Con 10 elementos? ¿Con 10.000? |
| **Costo** | ¿Corre seguido? ¿cuántos procesos por elemento? ¿con 10× datos? ¿hay presupuesto? |
| **Estado** | ¿Ya estaba instalado? ¿Desactualizado? ¿Corrupto? ¿Medio instalado? |
| **Operación** | ¿Es reversible? ¿Es idempotente? ¿Qué pasa si corre dos veces? ¿Se puede deshacer? |
| **Cobertura** | ¿Enumeré las fuentes antes de definir el alcance? ¿Qué categorías de herramientas, capacidades o recomendaciones quedaron afuera? |
| **Contexto del modelo** | ¿Miré lo que el agente recibe inyectado en cada paso (`<available_skills>`, prompt del sistema, permisos) antes de concluir desde los archivos del repo? |

La cobertura va primero. Si el alcance se define con una sola frase —«lo que
el repo ejecuta», «lo que pidió el usuario»— las categorías enteras quedan
fuera sin llegar a esta lista.

Enumerar no es checkear. Enumerar es **escribir la lista**.

Después, cada hueco es una de tres: **arreglarlo**, **documentarlo como
limitación**, o **sacarlo del scope**. Lo que no se puede es no saberlo.

> Ejemplo real: un script usaba `sort -V` para comparar versiones. Funciona en
> Linux, no en macOS — donde `sort` no tiene esa opción. Y el repo se
> modificaba desde Windows, así que los `.sh` podían quedar con CRLF y bash
> dejar de poder ejecutarlos. Ninguno de los dos se vio leyendo el código:
> se vio enumerando la variante "otra plataforma".

> Otro caso real: para saber si un agente en otro proyecto conocía
> `skill-import`, se revisaron el README, el `AGENTS.md` y el `main-agent.md`,
> y se concluyó que no. El catálogo `<available_skills>` que OpenCode inyecta
> en cada paso ya la anunciaba con su descripción. El descubrimiento de
> capacidades no vive en los archivos del repo: vive en el contexto del modelo.

### [optimize-by-default] Medí el costo antes de afirmarlo

Antes de decir que algo es lento, o de dar por terminado un trabajo que se
repite, **medilo**. Una impresión no es un dato, y un número del otro lado
del proyecto no dice nada del tuyo.

| Dónde | Qué mirar |
|---|---|
| **Camino caliente** | Lo que corre en cada commit, en cada validación, en cada invocación. Ahí un proceso por elemento se paga multiplicado por todo lo demás |
| **Costo superlineal** | Un `grep` por línea dentro de un `for` es O(n) con un factor de 40.000. El mismo resultado sale en un `awk` por archivo |
| **Presupuesto** | Si el trabajo se repite, decí cuál es el tiempo aceptable y comprobá que se cumple |
| **Pruebas** | Para probar una decisión, no llames al script con el entorno real: pasale un fixture con comandos falsos. Un test de decisiones no debe pagar Docker ni red |

La robustez no se negocia: primero que funcione, después que sea rápido.
Pero "funciona" no es excusa para dejarlo cien veces más lento de lo que
costaba.

> Ejemplo real: el lint del markdown revisaba 22 archivos con ~13 procesos
> externos por línea: 40.000 procesos y 28 segundos por validación, contra
> 0,35 s del resto del validador. Reescrito a un `awk` por archivo tardó
> 0,08 s. No se vio leyendo el código: se vio **midiendo**.

### [decide-or-ask] Decidí lo que puedas decidir vos

Preguntar no es neutral: **devuelve el trabajo al usuario** y le hace decidir
algo que vos podías determinar.

| Pregunta | Si podés determinarla, decidí |
|---|---|
| ¿Qué herramienta uso? | La mejor disponible. Decí cuál y por qué |
| ¿En qué categoría va esta skill? | La que corresponde según la taxonomía del repo |
| ¿Versión exacta o `latest`? | La que corresponde según el criterio del repo |
| ¿Universal o manifiesto del proyecto? | El que corresponde según el contexto |
| ¿Qué método de instalación? | El que funciona en esta plataforma |

Preguntá **solo** cuando:

- La decisión es **irreversible** o de alcance amplio (borra cosas, toca
  config global, publica).
- Hay **dos opciones razonablemente buenas** y ningún criterio las separa.
- Es una **preferencia personal**, no derivable del contexto.
- El **costo de equivocarse es alto** y no se puede revertir.

Cuando preguntes, **no devuelvas un menú**. Traé **tu recomendación con el
motivo**, y la alternativa si la hubiera:

> Mal: "¿Instalo `ast-grep` o `comby`?"
> Bien: "`ast-grep`: es más rápido, tiene más lenguajes y sus reglas en YAML
> son más fáciles de generar de forma fiable. `comby` solo gana en un caso
> puntual, que no justifica dos herramientas para lo mismo. ¿Te parece?"

**Tampoco apartes lo evidente.** Si del mismo análisis salen otros hallazgos
pequeños, corregelos en vez de reportarlos como «fuera de alcance». Los que
sean decisiones no triviales se resuelven con las dos lentes. Devolver lo que
se podía decidir también devuelve trabajo al usuario.

Decidir **no** es lo mismo que decidir **solo**. La decisión se reporta con
su motivo, para que se pueda revertir o discutir.

### [delegate-when-it-pays] Delegá cuando el resultado importa y el camino no

Una tarea grande, con varios archivos y varias preguntas independientes, se
reparte en subagentes: el contexto principal se queda con la conclusión, no
con el camino.

Criterio resumido (el detalle está en la skill `subagent-delegation`):

- **Delegá** si el resultado importa y el camino no, si hay partes
  independientes que van en paralelo, o si el contexto principal ya está
  cargado.
- **No delegues** si la tarea es chica, si el resultado se usa tal cual, o si
  depende del hilo acumulado.

El prompt del subagente tiene que ser **autocontenido**: arranca sin contexto
y no sabe nada de tu conversación. Pedí el **resultado** con su formato, no
la transcripción.

### [confirm-scope] Preguntá antes de tocar el scope del usuario

Antes de modificar cualquier cosa **fuera del proyecto** (config global del
usuario, configuración del agente, herramientas instaladas del sistema,
archivos del home), preguntá.

Alcance y ejemplo:

| Cambio | Scope | Acción |
|---|---|---|
| Archivo del repo que estamos trabajando | proyecto | hacelo |
| `~/.config/<agente>/config.json` | usuario | **preguntá** |
| Instalar una herramienta del sistema | máquina | **preguntá** |
| Archivo compartido de otro equipo | compartido | **preguntá siempre** |

Cuando igual lo hagas: **hacé cambios aditivos**.
Nunca borres ni reescribas una entrada que ya existía: preservá todo lo demás
y agregá lo tuyo. Si hay un conflicto real, reportalo en vez de resolverlo por
la fuerza.

**No repitas la pregunta.** Si el usuario pidió evaluar el cambio, ya mediste
el cambio exacto, es aditivo y reversible, y no hay nada que no puedas
verificar: hacelo y reportalo en el mismo turno. La pregunta sigue siendo
obligatoria para lo irreversible, lo que borra datos o lo que depende de
información que el usuario tiene y vos no.

### [single-source-of-truth] Una regla, una fuente; las copias se verifican

Toda regla o hecho tiene **una fuente de verdad**. Si por diseño debe aparecer
en varios archivos —skill dueña, payload always-on, agente principal, índice—
los demás son **copias derivadas**: se marcan como tales y se validan contra la
fuente, nunca se editan de forma independiente.

La cantidad de copias no es el problema; la falta de un mecanismo que detecte
la divergencia sí lo es. Dos copias sin chequeo se separan con el tiempo. Dos
copias con un check que falla no se separan sin que alguien lo vea.

Antes de documentar una regla que ya existe en otro archivo, decidí cuál es la
fuente y cómo se marca la copia. Si no podés verificarla, no la copies: citá la
fuente. El README y el `AGENTS.md` de esta biblioteca son índices, no fuentes.

**Trigger:** al agregar una regla global que deba propagarse, o al encontrar la
misma regla repetida en dos archivos.

## Detalle

- Criterios de commit extendidos, con ejemplos de bien y mal:
  `references/commit-criteria.md`
- Plantillas de registro: `assets/lessons-template.md`
- Plantilla del inbox de aprendizaje: `assets/learning-inbox.md` (raíz del repo)
- Aprendizaje global ya conciliado: `references/lessons.md`