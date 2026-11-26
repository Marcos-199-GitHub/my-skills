---
name: environment-setup
description: Prepare and maintain a workspace - detect the project stack and its real build, test and lint commands, install or update the required tooling, run the verification suite, and keep the project AGENTS.md accurate, asking before touching anything outside the project. Use when setting up a new repository or machine, when the environment looks stale, after changing dependencies, or when the AGENTS.md no longer matches the project.
license: MIT
compatibility: Requires bash and the project's own toolchain. Uses docker for toolchains and for dockerized projects.
metadata:
  category: environment
  requires: "dev-tooling,work-protocol"
  overrides: "work-protocol#confirm-scope"
  version: "1"
---

# Preparar y mantener el entorno

Deja el workspace en condiciones de trabajar: herramientas presentes,
dependencias instaladas, revisiones pasando y documentación del proyecto al día.

## Prerequisites

Cargá estas dos skills antes de aplicar esta:

- **`dev-tooling`** — trae el manifiesto de herramientas y los scripts
  `install-tools.sh` y `check-tools.sh`, en **su** directorio
  (`assets/tools.conf`, `scripts/install-tools.sh`, `scripts/check-tools.sh`).
  Toda instalación de herramientas se delega ahí.
- **`work-protocol`** — trae el flujo de trabajo, los criterios de commit y la
  regla `[confirm-scope]`. Esta skill **endurece** esa regla; ver
  `## Overrides`.

No repitas aquí el contenido de ellas: esta skill define el procedimiento,
no las reglas.

## Overrides

- `[confirm-scope]` (de `work-protocol`): en este contexto la regla es más
  estricta. Todo cambio fuera del proyecto —configuración del usuario,
  herramientas del sistema, archivos del home— requiere confirmación
  **explícita** antes de aplicarse, y solo de forma aditiva. Si el alcance del
  cambio es ambiguo, es de alcance usuario: preguntá.

## Procedimiento

### 1. Detectar el proyecto

Identificá, sin asumir:

| Qué | Dónde se busca |
|---|---|
| Raíz del repo | `git rev-parse --show-toplevel` |
| Lenguaje / stack | `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `pom.xml`, `*.csproj`, `Gemfile` |
| Package manager | lockfile presente: `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `uv.lock`, `poetry.lock` |
| Comandos reales | scripts de `package.json`, `Makefile`, `justfile`, `Taskfile.yml`, `pyproject.toml` |
| Revisiones en CI | `.github/workflows/`, `.gitea/workflows/`, `.gitlab-ci.yml` |
| **¿Está dockerizado?** | `docker-compose.yml`, `compose.yaml`, `Dockerfile`, `devcontainer.json`, `.devcontainer/` |

**Preferí siempre los comandos que el proyecto ya declara.** Si el CI corre
`bun test`, el comando de test es `bun test`, no `npm test`.

### 1b. Decidir si el proyecto va dockerizado o nativo

No todos los proyectos se dockerizan. Hay dos casos y el agente tiene que
distinguirlos:

| Caso | Señal | Qué hacer |
|---|---|---|
| **Dockerizado** | `compose.yaml`, `Dockerfile`, `.devcontainer/` | Correr todo dentro del contenedor del proyecto: `docker compose run --rm <servicio> <comando>`. El toolchain lo define la imagen del proyecto, no hace falta instalar nada |
| **Nativo / interno** | No hay nada de lo anterior | El toolchain se toma como imagen Docker puntual (ver paso 4) y las dependencias se instalan con el package manager del proyecto |

Esto **no se deduce del repo solamente**: algunos proyectos internos no se
dockerizan aunque tengan dependencias. La fuente de verdad es lo que el
usuario dijo, y queda registrado en el `AGENTS.md` del proyecto.

Si el `AGENTS.md` del proyecto ya dice cómo correr las cosas, **eso manda**
sobre lo que detectaste. Si no dice nada, deducilo y **registralo** (paso 8),
así la próxima vez no se re-detecta.

### 2. Detectar si el entorno está containerizado

Antes de instalar nada, determiná si corrés en un contenedor:

```bash
[ -f /.dockerenv ] || grep -qa 'docker\|lxc\|containerd' /proc/1/cgroup 2>/dev/null || [ -f /.containerenv ]
```

Si estás en un contenedor, ajustá la estrategia:

| Aspecto | En un contenedor |
|---|---|
| Servicios | No hay systemd. `systemctl` no existe. No intentes arrancar servicios |
| Privilegios | Suele ser root. Los comandos de instalación no necesitan `sudo` |
| Persistencia | `$HOME` puede ser efímero. Lo instalado ahí se pierde al recrear el contenedor |
| Montajes | El proyecto suele ser un bind mount: los cambios de archivos sí persisten, los de sistema no |

Si `$HOME` es efímero y hay herramientas que deben persistir, decilo en el
reporte final en vez de asumir que quedaron.

### 3. Leer el AGENTS.md existente

Si el proyecto ya tiene un `AGENTS.md`, **leelo y preservalo**. Este paso
falla si el archivo existe y no lo leíste.

Fusionás: agregás lo que falta, no reescribís lo que está.

### 4. Decidir las herramientas del proyecto

El manifiesto universal (`assets/tools.conf` de la skill `dev-tooling`) cubre
lo que un agente necesita **siempre**. Lo que necesita **este** proyecto va
en `<proyecto>/.agent-tools.conf`.

**Esta decisión es tuya, no del usuario.** Es lo que podés determinar leyendo
el repo. Leé las señales del proyecto y consultá la tabla de señales de
`dev-tooling` —es la fuente— para elegir el toolchain del manifiesto. No la
repliques acá: esta skill la recibe por la dependencia `requires`, y una copia
duplicada es lo que dejó los disparadores desincronizados.

**Los toolchains van como imagen Docker**, no instalados: pesan cientos de MB
y contaminan la máquina. La imagen no se instala en ningún lado y la versión la
define el tag. Para usarla:

```bash
bash <ruta-a-la-biblioteca>/tools/docker-run.sh python:3.13-slim python script.py
```

Reglas para decidir:

- **El criterio es la versión, no el origen.** Si el proyecto pide una versión
  concreta (un JDK 21, un Node 22), usá la imagen con ese tag: lo que se
  quiere es *esa* versión, no la que casualmente esté en la máquina. Los
  toolchains del manifiesto se declaran con tag, por eso van siempre en
  contenedor.
- **La regla `auto` de `dev-tooling` aplica a analizadores, no a toolchains.**
  Un toolchain va en imagen con tag aunque el runtime esté instalado: lo que
  se busca es esa versión, no la que haya en la máquina. No bajes la imagen
  de un analizador que ya tenés; tampoco reemplaces un toolchain de tag por
  el binario suelto del sistema.
- **El `AGENTS.md` del proyecto manda.** Si dice cómo se corre el toolchain,
  se hace eso aunque la regla general diga otra cosa.
- **No agregues lo que ya está implícito** en el runtime. Si el proyecto es
  Python y ya declarás `uv`, no agregues `pip`.
- **Revisá el catálogo de la skill `dev-tooling` antes de agregar.** Si la
  herramienta ya está descartada por solaparse con otra, no la propongas de
  nuevo. El catálogo dice qué hay, para qué y cuál va con cuál.
- El manifiesto del proyecto es un archivo commiteado. Se actualiza cuando
  el proyecto cambia: nuevo lockfile, nuevo framework, nuevo Dockerfile.
- Es un cambio **de alcance proyecto**, así que no necesita confirmación.
  Reportalo igual.
- Si no hay señales de un stack, no agregues nada: el manifiesto universal
  alcanza.

### 5. Verificar e instalar las herramientas

```bash
bash <directorio-de-la-skill-dev-tooling>/scripts/check-tools.sh \
  --manifest <directorio-de-la-skill-dev-tooling>/assets/tools.conf \
  --manifest <proyecto>/.agent-tools.conf
```

Eso te dice qué falta. Antes de instalar aplicá `[confirm-scope]`: el
manifiesto universal instala en scope `user` (`~/.local/bin`), así que pedí
confirmación explícita. Si el usuario no quiere instalar nada en el home, no
corras el instalador: reportá qué falta y esperá instrucciones.

Después instalá:

```bash
bash <directorio-de-la-skill-dev-tooling>/scripts/install-tools.sh --dry-run \
  --manifest <directorio-de-la-skill-dev-tooling>/assets/tools.conf \
  --manifest <proyecto>/.agent-tools.conf

bash <directorio-de-la-skill-dev-tooling>/scripts/install-tools.sh \
  --manifest <directorio-de-la-skill-dev-tooling>/assets/tools.conf \
  --manifest <proyecto>/.agent-tools.conf
```

Si `.agent-tools.conf` no existe, corré solo con el universal.

### 6. Instalar las dependencias del proyecto

**Si el proyecto está dockerizado**, las dependencias se instalan dentro del
contenedor del proyecto, no en la máquina:

```bash
docker compose run --rm <servicio> <package-manager> install
```

**Si el proyecto es nativo**, usá el package manager que el proyecto usa
(lockfile). Respetá el lockfile: `npm ci`, `bun install --frozen-lockfile`,
`uv sync --frozen`. Si el lockfile está desactualizado respecto al manifest,
eso es un problema del proyecto, no del entorno: reportalo.

**Si el toolchain es una imagen Docker** (paso 4), las dependencias van
dentro de la imagen y **no persisten**: se pierden al terminar el contenedor.
Para eso está el contenedor del proyecto, si lo hay.

### 7. Ejecutar las revisiones

Corré los comandos que el proyecto declara, en orden de costo:

1. Typecheck (rápido, detecta errores temprano)
2. Lint
3. Tests
4. Build (si aplica)

Si algo falla, **no lo arregles de paso**: reportá el fallo. Arreglar el
proyecto es otra tarea.

### 8. Actualizar el AGENTS.md

Actualizá el `AGENTS.md` del proyecto con lo que **verificaste** en los pasos
anteriores:

- Comandos reales de instalar / testear / lint / typecheck / build
- Estructura de carpetas relevante
- Convenciones que se deducen del código
- Comandos que fallan y por qué (si es información estable)

Usá la plantilla de `assets/agents-md-template.md` como estructura de
referencia, pero **adaptada al proyecto**, no copiada a ciegas.

## Reglas

Alcance y cambios aditivos — detalle del override de más arriba, no reglas
nuevas:

| Cambio | Alcance | Acción |
|---|---|---|
| Archivo del repo en el que trabajamos | proyecto | hacelo |
| Config del usuario (home) | usuario | **preguntá** |
| Herramienta del sistema | máquina | **preguntá** |
| Archivo compartido con otro equipo | compartido | **preguntá siempre** |

Si el alcance no es claramente del repo, tratálo como usuario y preguntá:
el override manda. Cuando igual lo hagas, **hacé cambios aditivos**.

- **Agregá**, nunca borres ni reescribas.
- Preservá todas las claves y secciones existentes.
- Si hay un conflicto, **reportá** en vez de resolverlo por la fuerza.
- Si ya existe una entrada equivalente, no la dupliques.

Un cambio aditivo se puede revertir fácilmente. Uno destructivo, no.

### [portable-output] El AGENTS.md que escribís es portable

El `AGENTS.md` del proyecto describe **el proyecto**, no las herramientas que
usaste para editarlo.

- **No** menciones nombres de agentes concretos (OpenCode, Claude Code, Codex).
- **No** menciones esta biblioteca de skills ni ninguna skill por nombre.
- **No** menciones comandos de agentes, flags de agentes, ni rutas de config
  de agentes.
- **Sí** mencioná comandos del proyecto, estructura, convenciones y gotchas.

El test: si alguien abre ese proyecto en otra máquina, con otra herramienta, y
no conoce esta biblioteca, el `AGENTS.md` le sigue sirviendo. Si tiene que
entender quién lo escribió, no es portable.

### [container-aware] Detectá el entorno antes de asumir

Si estás en un contenedor, decilo en el reporte final: qué se instaló donde y
qué no persiste. No asumas que el estado del sistema sobrevive.

## Detalle

- Plantilla de referencia para el `AGENTS.md` del proyecto:
  `assets/agents-md-template.md`
