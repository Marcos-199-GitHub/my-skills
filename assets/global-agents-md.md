<!-- my-skills:begin -->
<!-- source: work-protocol#single-source-of-truth -->
# Protocolo de trabajo

Este archivo define las reglas que aplican **siempre**. Lo procedural (cómo
commitear en detalle, cómo registrar una lección, cómo instalar herramientas)
está en las skills; acá está el núcleo que no se negocia.

## Al empezar

1. Cargá la skill `work-protocol` antes de cualquier tarea no trivial.
2. Sus reglas `[commit-*]`, `[learn-from-error]`, `[decide-or-ask]`,
   `[check-the-blind-spots]`, `[optimize-by-default]`, `[confirm-scope]` y
   `[single-source-of-truth]` son de cumplimiento obligatorio.

## Commits

- Un commit = una unidad completa: código, documentación y pruebas del mismo
  cambio. Revertirlo debe revertir todo eso. No mezcles cambios distintos.
- Nada se comitea sin que las revisiones del proyecto pasen.
- Mensaje: `<tipo>(<scope>): <descripción en imperativo>`, ≤72 caracteres.
- Nunca commitees secretos, artefactos de debug ni archivos generados.
- Nunca force-pushees algo ya pusheado.

## Alcance

- Cambios dentro del proyecto: hacelos.
- Cambios fuera del proyecto (config del usuario, herramientas del sistema):
  **preguntá primero**.
- En alcance usuario, los cambios son **aditivos**: agregá, nunca borres ni
  reescribas lo que ya estaba.

## Docker

- **Preferí Docker cuando se pueda.** Da control sobre lo que se instala y lo
  hace reproducible. Para los toolchains (python, node, java, kotlin, C#, go,
  rust) es siempre: van como **imagen**, no instalados. Un JDK pesa 500MB y
  la imagen no ocupa nada en la máquina.
- Para usar un toolchain sin instalarlo:
  `bash {{REPO_PATH}}/tools/docker-run.sh <imagen> <comando>`
- **Salvedad por proyecto**: algunos proyectos son internos y no se
  dockerizan. El `AGENTS.md` de cada proyecto **manda** sobre esta regla. Si
  el usuario te dice cómo se corre un proyecto, registralo ahí.
<!-- source: environment-setup#container-aware -->
- **`localhost` en un contenedor es el loopback del contenedor**, no la PC: para
  alcanzar servicios del host usá el hostname que declare la config o
  `host.docker.internal`, probalo antes de conectar y reportá la sustitución.
  `[container-aware]`

## Tareas grandes

- Si una tarea abarca muchos archivos, o si hay varias preguntas
  **independientes** que se pueden investigar en paralelo, o si el contexto ya
  está lleno: considerá delegar en un subagente. La skill `subagent-delegation` tiene
  el criterio y cómo delegar bien.
- Delegá cuando **el resultado importa y el camino no**. Si el resultado se usa
  tal cual, o la tarea es chica, hacela inline.

## Decisiones

- Antes de una decisión no trivial (arquitectura, convenciones, dependencias,
  patrones, cualquier cosa caro de revertir), presentá **dos** lecturas:
  **qué tenemos en el repo** y **qué dice la industria**. Después sintetizá y
  decidí. Si las dos chocan y no hay criterio, preguntá.
- **Decidí lo que puedas decidir vos.** Preguntar devuelve el trabajo al
  usuario y le hace decidir algo que vos podías determinar. Preguntá solo si es
  irreversible, si hay dos opciones igual de buenas sin criterio que las
  separe, o si es una preferencia personal.
- Cuando preguntes, **no devuelvas un menú**: traé tu recomendación con el
  motivo, y la alternativa si la hubiera.

## Lecciones

- **Registralo siempre.** Al final de toda sesión que haya producido algo
  reusable, dejá una entrada en el inbox: una corrección, un caso que
  resolviste, una decisión de diseño, un gotcha. No hace falta que te lo
  pidan, ni que decidas vos si «sirve»: ese filtro es el de la
  conciliación, no el de la captura. Lo que no se escribe no existe.
- **Detectalo vos.** Al cerrar cada tarea revisá qué salió mal, qué tuviste
  que rehacer y qué solucionaste: registralo sin esperar a que te lo digan
  ni a que pregunten si aprendiste.
- **Y aplicalo, con aprobación.** El inbox es escalonamiento, no destino: lo
  que es solo de esta máquina se queda ahí; lo global va en la skill dueña
  de la regla o en el agente principal, y la entrada se limpia. Registrar
  sin aplicar deja las cosas como estaban. Si el destino es la biblioteca,
  mostrá el diff exacto y esperá aprobación explícita antes de aplicar. Una
  pregunta («¿aprendiste?») no es aprobación.
- Escribí la entrada directo en `{{REPO_PATH}}/.learning/inbox.md`, con este
  formato. No necesitás cargar ninguna skill para hacerlo:

  ```
  ## L-<fecha>-<hora>-<maquina>

  - **tipo**: <correccion | caso>
  - **skill**: <skill-id a la que aplica>
  - **regla**: <rule-id>
  - **proyecto**: <repo>
  - **cuando**: <ISO-8601>
  - **maquina**: <hostname>

  **Qué pasó:** <qué se hizo mal y por qué>

  **Regla:** <la regla a seguir, imperativa y verificable>

  **Trigger:** <en qué situación aplica>
  ```

- Lección del proyecto → sección `## Lecciones` de su `AGENTS.md`.
- Lección **global** (aplica a cualquier proyecto) → el inbox de aprendizaje,
  **y además** a la skill que es dueña de la regla o al agente principal.
- No borres ni modifiques entradas que ya están.
- El inbox es local de esta máquina y no se versiona. Cuando pidas
  «conciliar lo aprendido», cargá la skill `learning-reconcile`: es la que
  sabe cómo convertir esas entradas en cambios concretos en las skills.

## Antes de dar algo por terminado

- Corré las revisiones del proyecto y mostrá el resultado.
- Si algo falla, reportalo. No lo arregles de paso.
- **Enumerá qué variantes no consideraste** —plataforma, entorno, datos,
  escala, costo, estado, contexto del modelo— y decí qué pasa con cada una.
  "No lo consideré" no es una respuesta válida: es el punto de partida de la
  revisión.
- Medí el costo de lo que corre seguido: un número antes y otro después.
  La regla `[optimize-by-default]` dice cuándo aplica y cuándo no.
- Si modificaste el `AGENTS.md` del proyecto, mantenelo reflejando la realidad
  verificada, no lo que suponés.
<!-- my-skills:end -->
