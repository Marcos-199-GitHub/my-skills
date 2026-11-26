# Catálogo de herramientas

Qué tiene el agente, **para qué** sirve cada una y **cuándo no** usarla.

Un agente que no sabe la diferencia entre dos herramientas similares usa la
equivocada. Este catálogo existe para que no tenga que adivinar.

## Cómo se decide qué entra

Tres criterios, en este orden:

1. **¿Ya existe una herramienta que haga esto?** Si sí, no entra otra. Una
   herramienta que se solapa con otra es ruido: el agente no sabe cuál usar y
   el contexto se llena de opciones.
2. **¿Es la mejor para el trabajo?** La que más gente usa, la que está más
   mantenida, la que se integra mejor con el resto.
3. **¿Se complementa?** Dos herramientas que cubren casos distintos sí conviven,
   siempre que quede escrito cuál va con cuál.

Cuando una herramienta se descarta por solaparse, queda anotado por qué, para
que no se vuelva a proponer.

## Entender: recorrer y buscar código

| Herramienta | Para qué | Cuándo NO usarla |
|---|---|---|
| `ripgrep` | Buscar **por contenido** | Para buscar por nombre de archivo |
| `fd-find` | Listar y filtrar **por nombre** | Para buscar por contenido |
| `git` | Historia, blame, ramas, diffs | — |

`fd-find` y `ripgrep` se complementan: uno encuentra el archivo, el otro
encuentra el código adentro. `fd` es mucho más rápido para listar.

**Descarte: `ugrep`.** Solapa con `ripgrep` sin aportarle nada.

## Leer: parsear lo que no es código

| Herramienta | Para qué | Cuándo NO usarla |
|---|---|---|
| `jq` | JSON: consultarlo, transformarlo, editarlo en el sitio | Para YAML |
| `yq` | YAML: lo mismo que `jq` pero sobre YAML | Para JSON |

Se complementan por formato. `jq` es insuperable para JSON y `yq` cubre YAML
con la misma interfaz.

**Descarte: `fx`, `dasel`.** Solapan con `jq` y son menos estándar.

## Editar: transformar y formatear

| Herramienta | Para qué | Cuándo NO usarla |
|---|---|---|
| `prettier` | Formatear JS/TS/JSON/YAML/Markdown | Para bash o Python |
| `shfmt` | Formatear bash | Para cualquier otro lenguaje |

**`prettier` cubre Markdown y YAML**, así que para docs no hace falta otra
cosa que formatee.

**Descarte: `ruff` y `black`.** Los formateadores de Python van en el
manifiesto del proyecto, que es donde vive el toolchain de Python: en el
universal no hay Python que formatear. Y entre los dos, uno solo.

## Refactorizar: cambios estructurales

| Herramienta | Para qué | Cuándo NO usarla |
|---|---|---|
| `ast-grep` | Buscar y reescribir por **árbol de sintaxis** | Para texto que no es código (JSON, YAML) |

`ast-grep` es la herramienta clave para refactorizar. Un `sed` que renombra
una función se come llamadas dentro de strings y de comentarios; `ast-grep`
no, porque parsea.

**Descarte: `comby`.** Solapa con `ast-grep` y lo hace peor: `ast-grep` es
más rápido, tiene más lenguajes, y sus reglas en YAML son más fáciles de
generar de forma fiable. `comby` solo gana en un caso muy puntual (encontrar
"huecos" en el código con un patrón simple), que no justifica mantener dos
herramientas para lo mismo.

**Descarte: `sed`.** No es una alternativa a `ast-grep`: es una herramienta
complementaria para texto plano. Se usa, pero no es lo mismo.

## Verificar: lint y análisis

| Herramienta | Para qué | Cuándo NO usarla |
|---|---|---|
| `shellcheck` | Errores reales en scripts bash | Para otros lenguajes |
| `yamllint` | Errores de estilo y estructura en YAML | Para Markdown |
| `markdownlint` | Errores de estilo y estructura en Markdown | Para YAML |
| `actionlint` | Errores en workflows de CI (GitHub, Gitea y GitLab) | Para código de aplicación |

Cada una cubre un formato distinto. No se solapan.

### Servidores de lenguaje (LSP)

Los servidores de lenguaje no son binarios del manifiesto universal: son por
lenguaje y dependen del toolchain del proyecto. Se habilitan en la
configuración del agente, no se instalan con `install-tools.sh`.

| Herramienta | Para qué | Cuándo NO usarla |
|---|---|---|
| Servidores LSP (`gopls`, `rust-analyzer`, `pyright`, `typescript-language-server`) | Referencias semánticas y diagnósticos después de cada edición | Cuando los comandos declarados ya devuelven los errores; en repos chicos; o si el servidor consume memoria, se desincroniza o cambia con la versión |

`ripgrep` y `ast-grep` siguen siendo la herramienta por defecto para buscar:
el LSP responde qué símbolo es, no dónde aparece una palabra. Se complementan:
hay referencias que el LSP no ve —`strings`, configuración, contratos entre
servicios— y que `ripgrep` sí encuentra. Para los diagnósticos, la primera
línea siguen siendo los comandos que el proyecto declara —`typecheck`, `lint` y
`tests`— y que `environment-setup` documenta en el `AGENTS.md` del proyecto.
Habilitar LSP es una decisión por proyecto: ayuda en bases grandes y cuando
compilar es caro, y estorba cuando el servidor va detrás de los comandos.

## Seguridad

| Herramienta | Para qué | Cuándo NO usarla |
|---|---|---|
| `gitleaks` | Detectar **secretos** antes de que lleguen al repo | Para vulnerabilidades de dependencias |

`gitleaks` aplica la regla "nunca commitees secretos" de forma mecánica, no
como una instrucción.

**Descarte: `trivy` del manifiesto universal.** Es un escáner de CVEs para CI,
no una herramienta de trabajo diario del agente, y pesa. Sí se declara en el
manifiesto del proyecto cuando hay dependencias de terceros que revisar.

## Containers

| Herramienta | Para qué | Cuándo NO usarla |
|---|---|---|
| `docker` | Construir, correr, inspeccionar contenedores | — |
| `hadolint` | Errores en el `Dockerfile` | Para otras cosas |

`hadolint` es el linter de Dockerfiles: detecta `apt-get` sin `--no-install-recommends`, tags no fijados, `USER root`, etc.

## vcs

| Herramienta | Para qué | Cuándo NO usarla |
|---|---|---|
| `gh` | API de GitHub: PRs, issues, releases | Para Gitea |
| `tea` | API de Gitea: PRs, issues, releases | Para GitHub |

Se complementan por plataforma.

## Instalar skills: `npx skills`

| Herramienta | Para qué | Cuándo NO usarla |
|---|---|---|
| `npx skills` | Instalar, verificar y actualizar las skills de la biblioteca | Sin Node 22.20+ o sin red: usar el modo dev del bootstrap |

No la instala el manifiesto: es un requisito previo del procedimiento de
arranque (`README.md`, paso 3.1), no una herramienta de trabajo diario. Trae
su propio `lockfile` y resuelve la versión de cada skill, por eso no compite
con `git`: `git` clona el repo, `npx skills` instala las skills en el agente.

**Por qué no está en `tools.conf`:** el manifiesto instala binarios chicos;
Node es un toolchain y va como imagen en el manifiesto del proyecto. Pero el
bootstrap corre *antes* de que exista ese manifiesto, así que Node tiene que
estar en la máquina de entrada. Si no está, el paso 3.4 del `README.md`
habilita el modo dev apuntando directo a `skills/`, y no se instala nada.

## Red

| Herramienta | Para qué | Cuándo NO usarla |
|---|---|---|
| `curl` | Descargar archivos y consultar HTTP | Para la API de GitHub o Gitea: `gh` o `tea` |
| `ssh` | Clonar y pushear por SSH, la alternativa que ofrece el bootstrap | Si usás HTTPS con el `credential store` de `git` |

`curl` es una dependencia silenciosa del instalador: las recetas de `tea` y
`docker` lo usan en Linux. Declararlo en el manifiesto hace que
`check-tools.sh` lo reporte si falta, en vez de fallar lejos de la causa.
`ssh`, en cambio, no se instala: viene con el sistema en las tres plataformas
y el bootstrap solo lo ofrece como alternativa. Dependencia u opción: la
diferencia decide si una herramienta entra al manifiesto.

## Infraestructura

Estas herramientas se declaran en el manifiesto **del proyecto**, nunca en el
universal: solo hacen falta si el repo las usa.

| Herramienta | Para qué | Cuándo NO usarla |
|---|---|---|
| `terraform` | Validar y planificar infraestructura declarada | Si el repo no tiene `*.tf` |
| `tflint` | Errores y convenciones en `*.tf` | Para código de aplicación |
| `helm` | Plantillas y despliegues de Kubernetes (`Chart.yaml`) | Si el repo no tiene `Chart.yaml` |

## Runtimes

| Herramienta | Para qué |
|---|---|
| `uv` | Gestor de Python: instala runtimes, herramientas y resuelve dependencias |

**Descarte: `pipx`.** `uv` hace lo mismo y más rápido. Dos gestores de
Python es exactamente el tipo de solapamiento que este catálogo evita.

**Lo que el manifiesto universal NO instala: `node`, `python3` y `bun`.** Son
runtimes, no binarios chicos: van como **imagen** en el manifiesto del
proyecto (`node:lts-alpine`, `python:3.13-slim`, `oven/bun:1-alpine`), que es
donde el agente decide si hacen falta. Los runtimes pesados (go, rust, java,
dotnet, php, ruby) siguen la misma regla.
