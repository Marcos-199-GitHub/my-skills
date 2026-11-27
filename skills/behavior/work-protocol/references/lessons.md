# Aprendizaje conciliado

Índice de todo lo que la biblioteca aprendió y **dónde quedó aplicado**.

El contenido de cada aprendizaje vive en la skill a la que aplica: si viviera
acá, no tendría trigger y nunca se activaría sola. Esta tabla es el índice y
el registro histórico.

| Fecha | Origen | Aprendizaje | Destino |
| --- | --- | --- | --- |
| 2026-11-26 | opencode-my-skills | Los payloads con marcadores se reponen completos (marcadores incluidos), o el de cierre queda duplicado | `AGENTS.md` del repo → regla de payloads |
| 2026-11-26 | opencode-my-skills | Registrar la lección es siempre, y no alcanza con el inbox: si el aprendizaje cambia cómo se trabaja, la regla cambia en la skill que la define o en el agente principal | `work-protocol` → `[learn-from-error]` + payload always-on + `agents/main-agent.md` |
| 2026-11-26 | opencode-my-skills | Cada check nuevo del validador tiene un caso negativo que se prueba: un agujero del validador viaja a todas las máquinas | `AGENTS.md` del repo → regla de los checks + `tools/smoke-test.sh` |
| 2026-11-26 | opencode-my-skills | `install` vacío = el entrypoint de la imagen ya es la herramienta; y el manifiesto y el catálogo se revisan juntos | `dev-tooling` → "Imágenes con entrypoint" + `tool-catalog.md` |
| 2026-11-26 | opencode-my-skills | El camino caliente se mide: un proceso por línea son 40.000 procesos y 28 s por validación | `work-protocol` → `[optimize-by-default]` + `tools/lint-md.sh` |
| 2026-11-26 | opencode-my-skills | Una regla tiene una fuente canónica; las copias se marcan como derivadas y se validan, o divergen con el tiempo | `work-protocol` → `[single-source-of-truth]` + payload + `agents/main-agent.md` + `tools/validate.sh` |
| 2026-11-26 | opencode-my-skills | Un "0 errores" sin casos negativos mide cobertura, no corrección: el validador colgaba en ciclos desconectados y las copias derivadas divergían sin ser vistas | `work-protocol` → `[single-source-of-truth]` + `tools/validate.sh` + `tools/smoke-test.sh` + `agents/main-agent.md` |
| 2026-11-27 | opencode-my-skills | La conciliación no termina hasta borrar del inbox las entradas aplicadas y descartadas: dejarlas las repropone, puede divergir y gasta contexto | `learning-reconcile` → `[clean-the-inbox]` + `scripts/check-inbox.sh` + `references/protocol.md` |
| 2026-11-27 | opencode-my-skills | El descubrimiento de capacidades de un agente no se infiere de los archivos del repo: OpenCode inyecta el catálogo de skills en cada paso, y la descripción es el anuncio | `work-protocol` → `[check-the-blind-spots]` + payload always-on |
| 2026-11-27 | opencode-my-skills | Una pregunta sobre si se aprendió algo no autoriza a aplicar el cambio: proponer el diff y esperar aprobación antes de tocar la biblioteca | `learning-reconcile` → `[propose-then-apply]` + `agents/main-agent.md` + payload always-on |
| 2026-11-27 | opencode-my-skills | La detección del error y de la solución reutilizable es automática; el inbox es escalonamiento y la skill es el destino de lo global | `work-protocol` → `[learn-from-error]` + `agents/main-agent.md` + payload always-on |
| 2026-11-27 | opencode-my-skills | En un contenedor `localhost` es el loopback propio: los servicios del host se alcanzan por el host que declare la config o `host.docker.internal`, verificados con una prueba mínima antes de conectar | `environment-setup` → `[container-aware]` + payload + `agents/main-agent.md` |

## Cómo se agrega una entrada

1. La corrección se detectó en una sesión y quedó en el **inbox** de esa
   máquina (`~/my-skills/.learning/inbox.md`).
2. En la conciliación se clasifica y se aplica **en la skill destino**: la
   regla nueva o modificada va en el `SKILL.md` correspondiente, con su ID.
3. Acá se agrega **una fila** al índice: fecha, de qué máquina vino, qué se
   aprendió, y en qué skill quedó.
4. La entrada se borra del inbox.

Las dos últimas columnas son lo que hace que esto funcione: sin el **destino**
no se puede verificar que el aprendizaje realmente quedó aplicado; sin el
**origen** no se puede rastrear de dónde salió.

## Conocimiento que no pertenece a ninguna skill

Cuando lo aprendido no encaja en ninguna skill existente, va acá, en
contenido completo.

```markdown
## <fecha> — <título>

**Qué pasó:** <qué se hizo mal y por qué>

**Regla:** <regla a seguir>

**Trigger:** <cuándo aplica>
```
