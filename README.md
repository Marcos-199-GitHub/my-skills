# my-skills

Biblioteca personal de skills de agente. Formato **Agent Skills**
([agentskills.io](https://agentskills.io)), compatible con `npx skills add`,
Claude Code, Codex, Gemini CLI y cualquier cliente que lea `SKILL.md`.

Repo **privado**. La fuente de verdad vive acá; la distribución sale de Gitea.

---

## Skills

<!-- skills:start -->
<!-- Generado por tools/validate.sh --write. No editar a mano. -->

| Skill | Categoria | Cuando se activa |
| --- | --- | --- |
| `subagent-delegation` | behavior | Use when a task spans many files, when several independent questions can be investigated at once, when the context window is filling up, ... |
| `work-protocol` | behavior | Use when starting a non-trivial task, before making a commit, after the user corrects you, when a decision is non-trivial or spans many f... |
| `dev-tooling` | environment | Use when setting up a new machine or container, when a tool is missing, when a project's tooling needs to change, or when auditing which ... |
| `environment-setup` | environment | Use when setting up a new repository or machine, when the environment looks stale, after changing dependencies, or when the AGENTS.md no ... |
| `learning-reconcile` | maintenance | Use when the user asks to reconcile learned lessons, apply pending learning, improve the skills based on what the agents learned, or proc... |
| `skill-import` | maintenance | Use when the user asks to move skills into the library, import a skill made in another project, vendor or fork a third-party skill, or co... |
<!-- skills:end -->

---

## Bootstrap

**Este es el único modo de instalación.** Copiá el bloque, cambiá la URL del
repo y pegalo en el agente de la máquina destino. El agente hace todo.

El prompt es idempotente: sirve para instalar de cero y para actualizar una
instalación existente. Solo cambia lo que tiene que cambiar.

**La única variable es la URL del repo.** Todo lo demás —qué skills hay, cómo
configurar el agente, qué herramientas instalar, qué reglas always-on— se
deriva del repo clonado.

```markdown
# Sincronizá my-skills en esta máquina

Repositorio: GITEA_URL

Este procedimiento es idempotente: sirve para instalar de cero y para
actualizar una instalación existente. Nunca borres ni sobreescribas
configuración del usuario. Aplicá únicamente lo que deba cambiar.

## 0. Detectá el estado actual y pedime lo que te falte
Antes de tocar nada:
  a) ¿Existe el repo? Buscá en `~/my-skills` y en el directorio actual (o donde
     te diga el usuario). → `git rev-parse --show-toplevel` y
     `git remote -v` sobre el que encuentres
  b) ¿Está el agente configurado? → `~/.config/opencode/opencode.json`
     y `~/.config/opencode/agents/main-agent.md`
  c) ¿Está el bloque always-on? → `~/.config/opencode/AGENTS.md`
  d) ¿Está el inbox de aprendizaje? → `~/my-skills/.learning/inbox.md`
  e) ¿Qué skills hay instaladas y de qué source? → el lock file del agente
  f) ¿Qué herramientas hay y en qué versión? →
     `bash <ruta-del-repo>/skills/environment/dev-tooling/scripts/check-tools.sh`
  g) ¿Qué skills ya están disponibles para el agente y de qué fuente?
     · del proyecto: `.opencode/skills/`, `.agents/skills/`, `.claude/skills/`
     · globales: `~/.config/opencode/skills/`, `~/.agents/skills/`,
       `~/.claude/skills/`
     · del array `skills` de `opencode.json`
     · los IDs de esta biblioteca: `bash <ruta-del-repo>/tools/validate.sh --graph`
     Reportá **cuáles IDs chocan** entre la biblioteca y lo que ya está
     instalado, y de qué fuente viene cada uno.
Reportá el estado detectado antes de continuar.

**Preguntame ahora, de una sola vez, todo lo que te pueda faltar**, para no
interrumpirte a mitad de camino:
  · Credenciales de Gitea (usuario y token de acceso), si el repo es privado
    y git no está ya configurado para clonar.
  · Para qué agente instalar las skills, si no es obvio por dónde entramos.
  · Si las herramientas van en scope de usuario o de proyecto (por defecto:
    usuario).
  · Cualquier decisión de configuración que no quieras que tome por default.
  · Si hay algo de esta máquina que deba NO tocar.

Lo que no te falte, seguí con los defaults que están en el repo.

## 1. Sincronizá el repo
  - Si `~/my-skills` no existe: `git clone GITEA_URL ~/my-skills`
  - En la máquina que mantenga la biblioteca, aplicá la convención de la
    sección Remotes: `git remote rename origin gitea` y
    `git remote add origin GITHUB_URL`.
  - Si existe: `git -C ~/my-skills pull --ff-only`
    · Si tiene cambios locales, NO los toques: reportá y seguí.
    · Si ningún remote apunta a GITEA_URL: `git remote add gitea GITEA_URL`
      (si ya existe con otro nombre, usá `set-url` sobre ese) y reportá
      el cambio.
    · En la máquina que mantiene la biblioteca, el upstream de `main` es
      GitHub: sincronizá desde Gitea con
      `git -C ~/my-skills pull --ff-only gitea main`.
  · Si el clone pide credenciales, pedímelas. Para Gitea el usuario es `gitea`
    y la contraseña es un token de acceso (PAT).
  · **Las credenciales van en el credential store de git, nunca en la URL**:
    `skills-lock.json` persiste la URL de origen y el token terminaría en un
    archivo del proyecto consumidor. Configuralo una vez para todas:
    `git config --global credential.helper store` (guarda el PAT en texto
    plano en `~/.git-credentials`; si preferís no dejarlo en disco, usá un
    helper de shell que lo lea de una variable de entorno). El paso 3.1
    necesita las mismas credenciales: el CLI usa las de git.
  · **Anotá la ruta real del repo** (la del paso 1) y usala en todos los pasos
    siguientes en lugar de `~/my-skills`. El repo puede estar en cualquier
    parte: no asumas.

## 2. Calculá el diff
Leé `~/my-skills/README.md` y `~/my-skills/AGENTS.md` (fuente de verdad).
Compará contra el estado del paso 0 y decidí qué cambia y qué no.
No apliques nada todavía.

## 3. Aplicá solo los cambios

### 3.1 Skills
  - Si no hay skills instaladas: `npx skills add GITEA_URL -g -a <tu-agente> -y`
  - Si hay: `npx skills check -g`
    · Si reporta updates: `npx skills update -g -y`
    · Si el lock registra un source DISTINTO a GITEA_URL (por ejemplo GitHub):
      remové esas skills (`npx skills remove -g <nombre>`) y reinstalá desde
      GITEA_URL. Reportá el cambio de source.
  - `npx skills` es un requisito previo del bootstrap, no lo instala el
    manifiesto de herramientas. Si no hay Node 22.20+: no instales nada;
    el paso 3.4 lo resuelve por config.

  **Colisiones.** Si del paso 0g hay IDs que chocan:
  - NO sobrescribas ninguna skill existente.
  - Por default, renombrá **la de la biblioteca**: es la que no rompe
    instalaciones que ya la tienen. `--rename` solo funciona con **una**
    skill, así que hay que nombrarla:
    `npx skills add GITEA_URL -g -a <tu-agente> --skill <id> --rename <id-nuevo> -y`
  - Preguntame solo si renombrar la de la biblioteca no sirve. Ahí las
    opciones son: renombrar la que ya estaba (solo si no tenés que perder
    contenido) o dejar la que ya estaba y no instalar la de la biblioteca.
  - Reportá cada choque y su resolución.

### 3.2 Agente principal
  - `~/.config/opencode/agents/` → creá si no existe.
  - Destino `main-agent.md`:
    · no existe → creá el enlace a `<ruta-del-repo>/agents/main-agent.md`
    · ya es un enlace a este repo → no toques nada
    · es otro archivo → renombralo a `main-agent.md.bak` y creá el enlace.
      Reportá el rename.
  - `~/.config/opencode/opencode.json`: agregá `"default_agent": "main-agent"`
    solo si falta o tiene otro valor. Preservá TODAS las claves existentes y
    el formato. **Si el archivo tiene comentarios (JSONC), no lo reescribas
    con `jq`**: `jq` los destruye. Editalo como texto, o con una herramienta
    que respete JSONC.

### 3.3 Protocolo always-on
  - Reemplazá el bloque COMPLETO de `~/.config/opencode/AGENTS.md` (del
    `<!-- my-skills:begin -->` al `<!-- my-skills:end -->`) por el contenido de
    `<ruta-del-repo>/assets/global-agents-md.md`, **sustituyendo
    `{{REPO_PATH}}` por la ruta real del repo**.
    · El payload ya trae sus propios marcadores: no reimprimas el de cierre
      de la entrada, o queda duplicado.
    · Si los marcadores no están: agregá el bloque al final.
    · Si el archivo no existe: creálo con el bloque.
    · NO toques nada fuera de los marcadores: lo de alrededor es del usuario.

### 3.4 Modo dev (solo si no se instalaron skills en 3.1)
  - En `~/.config/opencode/opencode.json`, agregá
    `"skills": ["<ruta-del-repo>/skills"]` preservando lo que haya.

### 3.5 Herramientas
  - `bash <ruta-del-repo>/skills/environment/dev-tooling/scripts/install-tools.sh`
  Es idempotente: solo actualiza lo que no cumple la versión del manifiesto.

### 3.6 Inbox de aprendizaje
  - Si `<ruta-del-repo>/.learning/inbox.md` no existe, creálo copiando
    `<ruta-del-repo>/assets/learning-inbox.md`, con `{{REPO_PATH}}` sustituido
    por la ruta real del repo. El directorio `.learning/` está en
    .gitignore: es local de esta máquina y no se commitea.
  - Si ya existe, **no lo toques**: es el registro de lo aprendido en esta
    máquina. Solo reemplazalo si no tiene ninguna entrada (o sea, si es
    una copia sin usar de la plantilla).

## 4. Verificá
  - `bash <ruta-del-repo>/tools/validate.sh`
  - Confirmá que las skills quedaron disponibles en el directorio del agente.

## 5. Reportá el diff
  - Estado anterior → estado nuevo.
  - Archivos de config modificados: ruta, clave, valor anterior → nuevo.
  - Conflictos que NO tocaste, y por qué.
  - Qué le recomendarías a esta máquina.
```

### Lo que el prompt hace por vos

| | |
|---|---|
| Clona o actualiza el repo | Detecta si ya existe y hace `pull` |
| Instala las skills | `npx skills add` / `skills update`, según el estado |
| Configura el agente | Enlaza `agents/main-agent.md` y setea `default_agent` |
| Activa el protocolo always-on | Reemplaza **solo** la región marcada del `AGENTS.md` global |
| Instala las herramientas | Script idempotente contra el manifiesto |
| Prepara el inbox de aprendizaje | Lo crea si falta |
| **Detecta choques** | Inventaria las skills ya instaladas y pregunta qué hacer con cada ID repetido, sin pisar nada |
| **Pregunta antes de empezar** | Junta en un solo mensaje todo lo que le falta: credenciales, decisiones, qué no tocar |

Tu config nunca se sobreescribe: los cambios son aditivos y lo que está fuera
de los marcadores se deja intacto.

### Advertencias

> ⚠️ **Nunca pongas el token en la URL.** `skills-lock.json` persiste la URL de
> origen: el token terminaría en un archivo del proyecto consumidor, que
> quizás sea público. Usá el credential store o SSH.

> ⚠️ **HTTP manda el token en claro** (base64 no es cifrado). Para una red en
> la que no confíes, usá SSH (`ssh://git@<host>:<puerto-ssh>/gitea/skills.git`)
> o HTTPS.

> ⚠️ **Telemetría.** `npx skills add` envía telemetría anónima. Para sources
> que no son GitHub no puede verificar la visibilidad, así que puede enviar
> el repo y los nombres de las skills igual. Como este repo es privado y se
> distribuye por Gitea, usá `DO_NOT_TRACK=1 npx skills add ...` (o
> `DISABLE_TELEMETRY=1`). Los *security-audit requests* sí están limitados a
> repos públicos de GitHub: no hay pedidos de auditoría hacia tu Gitea.

### Referencia rápida (lo que hace el prompt, por si lo hacés a mano)

```jsonc
// ~/.config/opencode/opencode.json
{
  "$schema": "https://opencode.ai/config.json",
  "skills": ["~/my-skills/skills"],
  "default_agent": "main-agent"
}
```

```bash
ln -s <ruta-del-repo>/agents/main-agent.md ~/.config/opencode/agents/main-agent.md
# Reemplazá el bloque marcado (paso 3.3); NO lo agregues con >>: duplica marcadores.
```

---

## Aprendizaje

El agente aprende durante las sesiones. Para que ese aprendizaje no se pierda:

```
sesión ──▶ inbox local ──▶ conciliación ──▶ skill ──▶ push ──▶ otras máquinas
           (crudo, local)   (propuesta)    (duradero)         (verifican)
```

| Pieza | Dónde | Qué es |
|---|---|---|
| **Inbox** | `~/my-skills/.learning/inbox.md` | Entradas crudas de esta máquina. Local, gitignored, no viaja |
| **Conciliación** | La pide el usuario | El agente clasifica, agrupa y propone cambios concretos a las skills |
| **Resultado** | Dentro de las skills | Aprendizaje ya digerido, versionado y distribuido |

**El inbox es local de cada máquina.** El de vm1 vive en la vm1. Por eso la
conciliación se pide **en la máquina donde está el inbox**: el agente de vm1
lee su inbox, propone, aplica, valida y pushea a Gitea; después la PC y las
demás VMs bajan el cambio.

Pedirle a la PC que concilie lo aprendido en vm1 **no va a funcionar**: la PC
no ve el inbox de vm1. Para eso hace falta que las máquinas compartan el
inbox — comunicación entre agentes, que es el paso siguiente.

### Cómo se vuelve automático

Que el agente aprenda no depende de que vos se lo digas. Depende de tres
capas, y cada una cubre una:

| Capa | Mecanismo | Qué garantiza |
|---|---|---|
| **El bloque always-on** | `~/.config/opencode/AGENTS.md` | Que el agente sepa que tiene que registrar la corrección, y **con qué formato**, sin cargar nada |
| **El agente principal** | `agents/main-agent.md` → `default_agent` | Que `work-protocol` se cargue al inicio de cada sesión, así que los criterios están siempre en contexto |
| **La skill de conciliación** | `maintenance/learning-reconcile` | Que el paso de convertir lo aprendido en cambios tenga protocolo, no improvisación |

La diferencia entre esto y "decile al agente que anote":

| | Con las tres capas | Pidiéndoselo cada vez |
|---|---|---|
| El agente registra solo | ✅ | ❌ hay que pedirlo |
| El formato es consistente | ✅ siempre el mismo | ❌ varía por sesión |
| Los criterios se aplican | ✅ desde el arranque | ⚠️ si la cargó |
| Lo aprendido llega a las skills | ✅ con protocolo | ❌ queda en el inbox |

**Sin `main-agent` como default, la tercera capa es la que no se cumple**: la
skill `work-protocol` se anuncia pero el agente puede no cargarla. Con
`default_agent: "main-agent"`, se carga siempre.

**El inbox es el único registro de lo que se aprendió en esa máquina** hasta
que se concilie. Por eso está en `.gitignore` pero no se borra: se concilia y
se limpia. La limpieza se verifica con
`skills/maintenance/learning-reconcile/scripts/check-inbox.sh`: una entrada
conciliada que queda se vuelve a proponer, puede divergir de la skill y gasta
contexto en cada sesión.

Cada entrada declara a qué skill y a qué regla aplica, así la conciliación es
mecánica:

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

La conciliación **espera aprobación explícita** antes de tocar nada, valida con
`tools/validate.sh --write`, y recién ahí cierra el ciclo con el push. El
procedimiento completo está en la skill `work-protocol`, sección
`## Conciliación`.

### El índice de lo aprendido

Lo conciliado queda en **dos lugares**, con un propósito cada uno:

| | Dónde | Para qué |
|---|---|---|
| **Contenido** | Dentro de la skill a la que aplica | Que se active sola cuando corresponde. Una regla en un `.md` suelto no tiene trigger |
| **Índice** | `skills/behavior/work-protocol/references/lessons.md` | Ver todo lo aprendido de un vistazo: qué, cuándo, de qué máquina y dónde quedó aplicado |

Por eso **no** hay un `memory.md` con las reglas: no viajaría a las otras
máquinas, no se revisaría, y duplicaría el contenido de las skills. El índice
resuelve "dame todo lo que aprendimos" sin crear una segunda fuente de verdad.

---

## Decisiones

La regla completa es `[decide-two-lenses]` en la skill `work-protocol`: dos
lentes (repo e industria), síntesis explícita, y decisión propia salvo que haya
dos opciones igual de buenas sin criterio que las separe o sea preferencia
personal (`[decide-or-ask]`).

---

## Remotes

| Remote | Apunta a | Rol |
|---|---|---|
| `origin` | `https://github.com/Marcos-199-GitHub/my-skills.git` | GitHub · repo privado principal, lo que usa GitHub Desktop |
| `gitea` | `http://localhost:13000/gitea/skills.git` | Gitea · distribución a las VMs |

```bash
git push gitea main   # distribución a las VMs (Gitea)
git push origin main  # espejo en el repo privado
```

> `origin` apunta a GitHub porque las herramientas gráficas —GitHub Desktop
> entre ellas— identifican el repo y habilitan Push a partir de ese remote y
> del upstream de la rama. Con `origin` en `localhost:13000`, Desktop trata el
> repo como genérico y no ofrece subir.
>
> **Desde un contenedor** (Docker, un VM que corre el agente), `localhost` es
> el loopback del propio contenedor, no tu PC. Gitea se alcanza por
> `host.docker.internal:13000`:
>
> ```bash
> git push http://host.docker.internal:13000/gitea/skills.git main
> ```
>
> El remote `gitea` queda con `localhost:13000` porque es lo que funciona en
> tu PC. El override por URL es solo para pushear desde un contenedor.
>
> Las máquinas que solo consumen las skills clonan desde Gitea y pueden dejar
> `origin` apuntando ahí; en ese caso el remote de distribución es `origin`.
> Si una máquina va a mantener la biblioteca, renombrá `origin` a `gitea` y
> agregá `origin` apuntando a GitHub.

---

## Taxonomía

| Carpeta | Qué entra | Cuándo se activa |
|---|---|---|
| `behavior/` | Cómo se comporta el agente: flujo de trabajo, commits, registro de lecciones | En toda sesión |
| `environment/` | Estado de la máquina y del workspace: herramientas, instalación, verificación | Cuando se prepara o mantiene un entorno |
| `maintenance/` | Mantenimiento de la propia biblioteca: conciliar el aprendizaje, revisarla | Cuando hay que mejorar la biblioteca |

Las categorías son carpetas físicas: `skills/<categoría>/<skill>/`. El **ID** de
una skill es el nombre de la carpeta hoja (`skills/behavior/work-protocol/` →
ID `work-protocol`), así que el `name` del frontmatter, el ID y la carpeta
coinciden siempre.

Si más adelante agregás skills de conocimiento, las categorías serían
`general/` (universal), `stack/` (tecnología concreta), `project/` (un repo
concreto) y `criteria/` (gates de calidad). Mover una skill de categoría **no**
cambia su ID: solo hay que mover la carpeta.

---

## Composición entre skills

Las convenciones (`requires`, `overrides`, deltas y profundidad máxima) están
en `AGENTS.md`, que es la fuente de autoría. La cadena actual de la biblioteca:

```
environment-setup   ──┬──▶ dev-tooling
                      └──▶ work-protocol
learning-reconcile  ─────▶ work-protocol
skill-import        ─────▶ work-protocol
```

La flecha va de quien declara `requires` a quien requiere. Es lo que muestra
`tools/validate.sh --graph`; si esta lista y ese comando divergen, mandan los
frontmatter.

---

## Conflictos entre skills

Tu biblioteca convive con skills propias de cada proyecto y con skills de
internet. El riesgo real no es que "se mezclen": es que **una pise a la otra
en silencio**.

### Cómo resuelve OpenCode los IDs repetidos

El ID de una skill es su nombre de carpeta. Si dos fuentes definen el mismo
ID, gana la de mayor precedencia:

| Nivel | Fuente |
|---|---|
| 1 | built-in |
| 2 | `.claude/skills` (global → proyecto) |
| 3 | `.agents/skills` (global → proyecto) |
| 4 | `~/.config/opencode/skills` ← **instalación global de la biblioteca** |
| 5 | `.opencode/skills` del proyecto |
| 6 | entradas del array `skills` de `opencode.json` ← **modo dev** |

Traducción: en modo dev la biblioteca pisa todo. En instalación global pisa lo
que el proyecto tenga en `.agents/skills` o `.claude/skills`, y pierde contra
el `.opencode/skills` del proyecto.

### Por qué la biblioteca no pisa a nadie

- **IDs específicos**: `work-protocol`, `dev-tooling`, `environment-setup`,
  `learning-reconcile`, `skill-import`. No son nombres genéricos tipo
  `code-review` o `testing`, que es lo que usan las skills públicas.
- **El validador exige unicidad dentro de la biblioteca**, así que dos skills
  de la biblioteca nunca se pisan entre sí.

### Y si igual hay choque

El prompt lo **detecta antes de instalar** (paso 0g) y te pregunta, en vez de
sobrescribir:

1. Renombrar la de la biblioteca (`--rename`).
2. Renombrar la que ya estaba, solo si no se pierde contenido.
3. Dejar la que ya estaba y no instalar la de la biblioteca.

---

## Traer skills a la biblioteca

Las skills que hiciste con el agente en un proyecto, o las de internet que
querés customizar, se pueden traer a la biblioteca. La skill
`maintenance/skill-import` tiene el protocolo:

| Paso | Qué hace |
|---|---|
| **Inventariar** | Recorre todas las fuentes: `.opencode/skills`, `.agents/skills`, `.claude/skills` del proyecto y los globales |
| **Detectar colisiones** | Compara los IDs con los de la biblioteca y entre sí |
| **Clasificar** | ¿Reusable, se queda en el proyecto, o interna? |
| **Normalizar** | `name` == carpeta, kebab-case, `description` en inglés, body en español, `metadata` string, reglas con ID, <500 líneas |
| **Copiar y renombrar** | La carpeta final y el `name` del frontmatter se cambian juntos |
| **Dejar constancia** | Cada skill importada dice de dónde vino y qué se normalizó |
| **Validar** | `tools/validate.sh --write` decide |

Tres decisiones que la skill toma por vos y que conviene conocer:

- **No pisa nada.** Si el ID ya existe, te pregunta entre renombrar la
  importada, renombrar la existente, o dejar la existente.
- **Una skill de internet no se edita donde está.** Se copia a la biblioteca y
  se modifica ahí: editar el original se pierde en la próxima actualización.
- **Lo específico del proyecto se queda en el proyecto.** Una skill que depende
  de las rutas de un repo, sin ese repo, es texto genérico.

---

## Desarrollo

```bash
bash tools/validate.sh           # valida todo (incluye el lint del markdown)
bash tools/validate.sh --write   # regenera el índice de este README
bash tools/validate.sh --check   # falla si el índice quedó viejo (lo que corre CI)
bash tools/validate.sh --graph   # muestra el grafo de dependencias
bash tools/lint-md.sh            # solo el lint del markdown
bash tools/smoke-test.sh         # prueba las decisiones de los scripts
```

El lint del markdown es lo que evita que un texto corrupto (caracteres de otro
alfabeto, palabras en inglés filtradas, markdown roto) llegue a la biblioteca.
Corre también dentro de `validate.sh` y en el CI.

El costo también se cuida: la regla `[optimize-by-default]` pide medir antes de
afirmar y declarar presupuesto en lo que corre seguido. La validación completa
ronda 0,5 s; no hay gate de tiempo en CI porque los runners son ruidosos.

Las reglas de autoría y los criterios de aceptación están en
[`AGENTS.md`](./AGENTS.md).

---

## Layout

```
my-skills/
├── README.md                       este archivo
├── AGENTS.md                       reglas de autoría + criterios de aceptación
├── .gitattributes                  fuerza LF: el repo se edita en Windows
├── .gitignore
├── assets/
│   ├── global-agents-md.md         bloque always-on (payload del bootstrap)
│   └── learning-inbox.md           plantilla del inbox de aprendizaje
├── agents/
│   └── main-agent.md               definición del agente principal (OpenCode)
├── skills/
│   ├── behavior/
│   │   └── work-protocol/
│   ├── environment/
│   │   ├── dev-tooling/
│   │   └── environment-setup/
│   ├── maintenance/
│   │   ├── learning-reconcile/
│   │   └── skill-import/
├── templates/skill/SKILL.md        esqueleto para una skill nueva
├── tools/
│   ├── validate.sh                 validador de la biblioteca
│   ├── lint-md.sh                  lint del markdown
│   ├── smoke-test.sh               prueba las decisiones de los scripts
│   └── docker-run.sh               corre un comando en una imagen, sin instalar
└── .github/workflows/validate.yml
```

`skills/` es el contenedor estándar que el instalador de skills ya reconoce.
`assets/` y `agents/` **no** son contenedores: no viajan con `npx skills add`,
se instalan a mano (ver [Bootstrap](#bootstrap)).

## Delegación

El contexto de una sesión es finito. La skill `subagent-delegation` define **cuándo
repartir el trabajo en subagentes** y cómo hacerlo bien:

- **Contexto**: el subagente carga lo que necesita y devuelve la conclusión.
  El hilo principal no se queda con el camino.
- **Paralelismo**: las preguntas independientes se investigan a la vez.
- **Foco**: el subagente arranca con contexto limpio, sin las suposiciones
  de la conversación principal.

El criterio es uno: **delegá cuando el resultado importa y el camino no**.

Y el detalle que más se olvida: el subagente **arranca sin contexto**. Su
prompt tiene que ser autocontenido y pedir el **resultado** con su formato,
no la transcripción. Un subagente al que se le pide "explorá y contame" te
devuelve un muro de texto, que es justo lo que querías evitar.

La biblioteca no trae subagentes propios: delega en los built-in (`explore`,
`general`). Definir uno nuevo es decisión de la config del agente, no de esta
skill. La mecánica (`mode: subagent`, permisos, `subagent_depth`) está en
`skills/behavior/subagent-delegation/references/opencode.md`.

---

## Herramientas

El agente trabaja con **Docker siempre que se puede**: da control sobre lo que
se instala y lo hace reproducible. Los toolchains (python, node, java, kotlin,
C#, go, rust) van como **imagen**, no instalados — un JDK pesa 500MB y la
imagen no ocupa nada en la máquina.

```bash
bash tools/docker-run.sh python:3.13-slim python script.py
```

El **manifiesto universal** (`skills/environment/dev-tooling/assets/tools.conf`)
es lo que un agente necesita sin importar el proyecto: buscar, parsear,
formatear, refactorizar, verificar, contenedores y vcs. Son binarios chicos:
van nativos.

Las herramientas **de un proyecto** van en `<proyecto>/.agent-tools.conf`, y
**las decide el agente** leyendo el repo (`Cargo.toml` → `rust:1-slim`,
`pom.xml` → `eclipse-temurin:21-jdk`, lockfile → el package manager que
corresponda).

**Salvedad:** algunos proyectos son internos y no se dockerizan. El `AGENTS.md`
de cada proyecto manda sobre la regla general.
