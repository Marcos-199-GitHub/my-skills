---
name: dev-tooling
description: Install, update and verify the development tools an agent needs - searching and reading code, parsing formats, formatting, structural refactoring, linting, containers, git clients and language runtimes. Use when setting up a new machine or container, when a tool is missing, when a project's tooling needs to change, or when auditing which tools are installed.
license: MIT
compatibility: Requires bash and a package manager (apt, dnf, apk, pacman, brew, choco or scoop). The container-based tools need docker.
metadata:
  category: environment
  version: "1"
---

# Tooling de desarrollo

Las herramientas que el agente tiene para **entender, crear, leer, editar,
refactorizar y verificar** código. El manifiesto es la fuente de verdad.

## Manifiesto

```
name|version|scope|method|pkg|version-cmd|install
```

| Campo | Qué es |
|---|---|
| `name` | Identificador. Se usa para reportes y `--only` |
| `version` | **La intención**, no el número: `latest`, `lts`, o un pin exacto |
| `scope` | `user` (instalación del usuario) o `project` (local al repo, en `./.tools`) |
| `method` | Cómo se instala: `apt` `dnf` `apk` `pacman` `brew` `choco` `scoop` `winget` `npm` `pipx` `pip` `cargo` `go` `script` `docker` `auto` `none` |
| `pkg` | El paquete a instalar (según método). Para `docker`/`auto`: la imagen |
| `version-cmd` | Comando que imprime la versión instalada. Admite alternativas separadas por `;` (se prueba la primera que imprima una versión): sirve cuando el binario tiene nombres distintos según la plataforma (`fdfind` en Debian, `fd` en brew) |
| `install` | Para `method=script`: el comando a correr, con variantes por plataforma separadas por `;;` (`linux=<cmd> ;; darwin=<cmd> ;; windows=<cmd>`). Para los demás métodos: la **alternativa** cuando el método no existe en la máquina (`apt` no existe en macOS) — si hay variante para el SO actual se usa esa, si no la herramienta se omite. Para `docker`/`auto`: el comando **dentro** de la imagen. **Vacío = el entrypoint de la imagen ya es la herramienta**, y el wrapper no le pasa comando |

`method` + `pkg` son **portables**: el instalador deriva el comando correcto
para la plataforma donde corre. `install` es el escape hatch para lo que no
se puede expresar así.

### `docker` vs `auto`

| Método | Qué hace | Para qué |
|---|---|---|
| `docker` | **Siempre** contenedor: crea un wrapper que corre la imagen | Toolchains. La reproducibilidad es el punto: la versión la define el tag |
| `auto` | Si la herramienta **ya está instalada**, se usa esa y **no se crea contenedor**. Si no, cae al contenedor | Analizadores. Un contenedor para algo que ya tenés es gasto |

**`auto` es la regla general: preferí lo que ya está.** Si la máquina tiene
`node`, no tires de una imagen con node para correr prettier. Si ya tiene
`prettier`, no crees un wrapper: usá el que está.

La única excepción: los **toolchains**, que van siempre en contenedor aunque
el runtime esté instalado, porque lo que se quiere es la versión exacta del
tag, no la que haya en la máquina.

### El wrapper y el PATH

El wrapper se crea en `~/.local/bin` (scope `user`) o en `./.tools/bin`
(scope `project`). Para poder llamar la herramienta, ese directorio tiene
que estar en el `PATH`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

El instalador avisa cuando deja un wrapper en un directorio que no está en
el `PATH` de la corrida. El `check` lo tiene en cuenta por eso: sin eso,
una herramienta instalada daría "FALTA".

### Imágenes con entrypoint

Algunas imágenes ya traen la herramienta como entrypoint (`yamllint`,
`actionlint`, `gitleaks`, `uv`). Para esas, el campo `install` va
**vacío**: el wrapper no le pasa comando. Pasarle el nombre de la
herramienta igual la rompe, porque recibe su propio nombre como argumento
(`unknown command "gitleaks"`).

## Plataformas

Todo el tooling corre en **Linux, macOS y Git Bash de Windows**. Eso exige
ciertas cosas que no son evidentes:

| Cosa | Por qué |
|---|---|
| **`.gitattributes` con `eol=lf`** | El repo se modifica desde Windows. Sin esto, git convierte los `.sh` a CRLF y bash deja de poder ejecutarlos: `bad interpreter: /bin/sh^M` |
| **`sudo` condicional** | No existe en Windows, ni en contenedores donde ya sos root. El script lo usa solo si hace falta y está disponible |
| **Sin `sort -V`** | No existe en BSD/macOS. La comparación de versiones es numérica, propia |
| **`mktemp` con template** | En macOS, `mktemp` sin argumentos pide un template |
| **Placeholders de plataforma** | `{{OS}}` `{{ARCH}}` `{{GOARCH}}` `{{EXT}}` `{{BINDIR}}` — las releases binarias no nombran igual las plataformas ni las arquitecturas |
| **Variantes por plataforma** | El campo `install` admite `linux=<cmd> ;; darwin=<cmd> ;; windows=<cmd>`. Sin variante para el SO actual se busca una genérica; si no hay, se reporta |
| **Alternativa por plataforma** | El campo `install` es también la alternativa para cuando el método no existe en la máquina: `apt` no existe en macOS ni en Windows, así que esas herramientas declaran `darwin=brew install … ;; windows=scoop install …`. Sin eso, en una Mac se omitían en silencio |
| **`version-cmd` aparte del nombre** | En Debian el paquete es `fd-find` y el binario `fdfind`; en otras distros es `fd` |

Si el `method` no existe en la máquina, la herramienta se **omite** y se sigue
con las demás: no se aborta la corrida.

## Versiones: por qué casi no hay pins

| Intención | Qué hace el instalador |
|---|---|
| `latest` | Corre el comando de instalación **siempre**. El gestor decide si actualiza |
| `lts` | Igual, pero el canal es el LTS (sin majors). Para runtimes |
| `X.Y.Z` | **Pin**: solo actualiza si la instalada es menor |

**Por qué `latest` es el default:** un pin viejo obliga a actualizar el
manifiesto cada X meses, y un pin viejo es peor que no tener pin — te da una
sensación de reproducibilidad que no existe, mientras la herramienta real se
queda atrás.

**Cuándo sí pinear:** cuando una major rompe de verdad y querés congelar el
estado. Solo ahí.

Con `latest`, el `check` **no puede** decir si algo está desactualizado: eso
requiere preguntarle al gestor. Por eso informa la versión instalada y marca
`al día*` (*= canal flotante, se actualiza cuando corrés el instalador).

## Manifiesto por proyecto

El manifiesto de esta skill es el **universal**: lo que un agente necesita
independientemente del proyecto. Las herramientas que solo un proyecto
necesita van en el manifiesto **del proyecto**: `<proyecto>/.agent-tools.conf`,
mismo formato.

```bash
bash scripts/install-tools.sh \
  --manifest assets/tools.conf \
  --manifest /ruta/al/proyecto/.agent-tools.conf
```

**Quién decide qué va en el manifiesto del proyecto: el agente, con base en el
contexto del proyecto.** No es una decisión del usuario: es lo que el agente
puede determinar leyendo el repo.

Cómo se decide:

Las herramientas de esta tabla se declaran en el manifiesto del proyecto y se
interpretan con el catálogo. Los servidores de lenguaje son la excepción: no
se instalan como binarios, se habilitan en la configuración del agente, y el
diagnóstico sigue viniendo de los comandos que el proyecto declara.

| Señal en el proyecto | Toolchain (como imagen Docker) |
|---|---|
| `Cargo.toml` | `rust:1-slim` |
| `go.mod` | `golang:1-alpine` |
| `pom.xml`, `build.gradle` | `eclipse-temurin:21-jdk` |
| `*.kt`, `build.gradle.kts` | `gradle:8-jdk21` |
| `*.csproj`, `*.sln` | `mcr.microsoft.com/dotnet/sdk:8` |
| `composer.json` | `php:8-cli` |
| `Gemfile` | `ruby:3-slim` |
| `package-lock.json` | `node:lts-alpine` (npm incluido) |
| `pnpm-lock.yaml` | `node:lts-alpine` (activar `corepack pnpm`) |
| `yarn.lock` | `node:lts-alpine` (activar `corepack yarn`) |
| `bun.lockb`, `bun.lock` | `oven/bun:1-alpine` |
| `pyproject.toml` | `python:3.13-slim` |
| `Dockerfile` | `hadolint` (ya viene en el universal) |
| `*.tf` | `terraform`, `tflint` |
| `Chart.yaml` | `helm` |
| `.github/workflows/`, `.gitea/workflows/`, `.gitlab-ci.yml` | `actionlint` |
| Dependencias de terceros con CVEs | `trivy` |

**Los toolchains van como imagen Docker, no instalados.** Un JDK pesa 500MB y
contamina la máquina; la imagen no se instala en ningún lado y la versión la
define el tag. Para usarla:

```bash
bash tools/docker-run.sh python:3.13-slim python script.py
```

Y en el manifiesto del proyecto, con `method=docker`:

```
python|lts|project|docker|python:3.13-slim|python --version|
```

El instalador crea un wrapper en `.tools/bin/python` que corre la imagen. Para
cualquier otro comando de la imagen (pip, npm, gradle), usá `docker-run.sh`.

> ⚠️ **Lo que se instala dentro del contenedor no persiste.** `pip install`
> dentro de la imagen se pierde al terminar. Para las dependencias del
> proyecto, usá el contenedor del proyecto (ver `environment-setup`).

Reglas para decidir:

- **No agregues lo que ya está implícito** en el runtime. Si el proyecto es
  Python y ya declarás `uv`, no agregues `pip`.
- **Revisá el catálogo antes de agregar.** Si la herramienta ya está
  descartada por solaparse con otra, no la propongas de nuevo.
- El manifiesto del proyecto es un archivo commiteado. Se actualiza cuando
  el proyecto cambia: nuevo lockfile, nuevo framework, nuevo Dockerfile.
- Es un cambio **de alcance proyecto**, así que no necesita confirmación.
  Reportalo igual.
- Si no hay señales de un stack, no agregues nada: el manifiesto universal
  alcanza.

Cuando el proyecto cambia (nuevo lockfile, nuevo framework), el manifiesto se
actualiza. Eso lo hace `environment-setup`.

## Uso

```bash
# Ver qué falta
bash scripts/check-tools.sh

# Ver qué haría, sin hacerlo
bash scripts/install-tools.sh --dry-run

# Instalar/actualizar todo
bash scripts/install-tools.sh

# Solo una herramienta
bash scripts/install-tools.sh --only ast-grep

# Universal + el del proyecto
bash scripts/install-tools.sh --manifest assets/tools.conf --manifest ../proyecto/.agent-tools.conf
```

## Garantías del instalador

1. **Idempotente.** Con `latest` el comando corre siempre, pero el gestor no
   reinstala lo que ya está al día.
2. **Nunca desinstala ni degrada.** Solo agrega o actualiza.
3. **`--dry-run`** muestra el plan sin ejecutar.
4. **Re-verifica** después de instalar y falla con un mensaje claro si la
   herramienta no quedó detectable.
5. **No pide sudo por su cuenta.** Si el método lo necesita, el manifiesto lo
   dice explícitamente.
6. **Si el método no existe en la plataforma**, lo reporta y sigue con las
   demás herramientas en vez de abortar todo.

## Qué hay y para qué

El catálogo completo está en `references/tool-catalog.md`: por grupo, qué
herramienta hay, **para qué** sirve, **cuándo no usarla**, y por qué se
descartaron las alternativas.

| Grupo | Le da al agente |
|---|---|
| **entender** | Recorrer y buscar código: `ripgrep` (contenido), `fd-find` (nombres), `git` |
| **leer** | Parsear lo que no es código: `jq` (JSON), `yq` (YAML) |
| **editar** | Formatear: `prettier` (JS/TS/JSON/YAML/MD), `shfmt` (bash) |
| **refactorizar** | Cambios **estructurales**, no por texto: `ast-grep` |
| **verificar** | Lint por formato: `shellcheck`, `yamllint`, `markdownlint`, `actionlint` |
| **seguridad** | Que no se filtren secretos: `gitleaks` |
| **containers** | `docker`, `hadolint` |
| **vcs** | `gh` (GitHub), `tea` (Gitea) |
| **red** | `curl`: lo usan las recetas de `tea` y `docker` en el instalador |
| **runtimes** | `uv` (gestor de Python: instala runtimes, herramientas y resuelve dependencias). `node` y `python3` no los instala el universal: son toolchains y van como imagen en el manifiesto del proyecto |

`npx skills` no lo instala este manifiesto: es un requisito previo del bootstrap
(`README.md`, paso 3.1). Si no hay Node 22.20+, el paso 3.4 usa el modo dev.
El catálogo explica por qué queda fuera.

`ast-grep` es la que más cambia el trabajo de un agente: busca por **árbol de
sintaxis**, no por texto. Un `sed` que renombra una función se come llamadas
en strings y comentarios; `ast-grep` no.

## Reglas de curación

### [one-tool-per-job] Una herramienta por trabajo

Antes de agregar una herramienta, preguntá: **¿ya existe otra que haga
esto?** Si sí, no entra. Dos herramientas que se solapan son ruido: el agente
no sabe cuál usar y el contexto se llena de opciones.

Si se complementan (formatos distintos, plataformas distintas), conviven —
siempre que quede escrito cuál va con cuál, en el catálogo.

### [keep-the-best] Cuando dos hacen lo mismo, gana la mejor

Criterios, en orden: la que está más mantenida, la que más gente usa, la que
se integra mejor con el resto del ecosistema.

La que pierde queda **descartada en el catálogo, con el motivo**. Así no se
vuelve a proponer.

### [catalog-is-the-why] El catálogo es el porqué

El manifiesto dice **qué** hay. El catálogo dice **para qué** y **cuándo no**.

Cuando agregás o sacás una herramienta, actualizá los dos. Un manifiesto sin
catálogo es una lista que el agente no puede interpretar.

Contrastá además los dos contra el código que los ejecuta: el bootstrap, los
scripts del instalador y el CI. Lo que el arranque necesita se declara como
requisito previo aunque no se instale desde el manifiesto —`npx skills` es el
ejemplo—; un binario que una receta invoca se declara —`curl`—; y un
disparador que aparece en dos skills se escribe en una sola y se cita en la
otra, según `[single-source-of-truth]` de `work-protocol`.

Lo mismo vale para lo que el sistema recomienda pero no ejecuta: si una tabla
de señales nombra una herramienta, el catálogo tiene que explicarla. Y si una
capacidad queda fuera por decisión —como los servidores de lenguaje— la
decisión se escribe en vez de darse por sentada.


## Agregar una herramienta

1. Agregá la línea al manifiesto que corresponda (universal o del proyecto).
2. Elegí el `method` que funcione en la plataforma destino. Si no hay uno,
   `script` con el comando explícito.
3. `version-cmd` tiene que imprimir la versión en stdout. El script extrae el
   primer número con decimales, así que `v22.20.0`, `jq-1.7.1` y
   `ripgrep 14.1.0` funcionan todos.
4. Verificá con `bash scripts/check-tools.sh`.
5. Instalá con `bash scripts/install-tools.sh --only <name>`.

## Detalle

- Catálogo de herramientas: qué hay, para qué, cuándo no usarla y por qué se
  descartaron las alternativas: `references/tool-catalog.md`

- Los comandos que necesitan `nvm` u otras funciones de shell se ejecutan en
  un shell de login (`bash -lc`), así que el perfil está cargado.
- **Un `sudo` que pida password cuelga el script** si no hay terminal (systemd,
  ansible, un `docker exec`). Para máquinas automatizadas usá `sudo -n` (falla
  de inmediato en vez de esperar) o un método sin privilegios.
- `fd` en Debian/Ubuntu se llama `fd-find` y el binario es `fdfind`. Por eso
  el manifiesto separa `name` de `version-cmd`.
- `yq` en apt es el wrapper de Python sobre `jq`, no el de Go. Cumplen la
  misma función para YAML → JSON.
- En un contenedor, `apt-get install` suele necesitar ser root, y no hay
  systemd: no esperes que los servicios de `docker install` queden
  arrancados.
