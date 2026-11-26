# Protocolo de importación

Paso a paso.

## 0. Preparación

```bash
cd ~/my-skills
git status --short
git pull --ff-only
```

Árbol limpio y base al día. Conciliar o importar sobre una base vieja
produce conflictos que no son reales.

## 1. Inventariar

Recorré **todas** las fuentes:

```bash
# Del proyecto en el que estás
find <proyecto>/.opencode/skills  -name SKILL.md 2>/dev/null
find <proyecto>/.agents/skills    -name SKILL.md 2>/dev/null
find <proyecto>/.claude/skills    -name SKILL.md 2>/dev/null

# Globales
find ~/.config/opencode/skills    -name SKILL.md 2>/dev/null
find ~/.agents/skills             -name SKILL.md 2>/dev/null
find ~/.claude/skills             -name SKILL.md 2>/dev/null
```

Cada hallazgo es una **candidata**. Anotá: nombre, ruta de origen, y de dónde
vino (si hay un lock file o un README que lo diga).

Una misma skill en varias carpetas es normal: el agente usa una sola por ID.

## 2. Detectar colisiones

Compará los nombres de las candidatas con los IDs de esta biblioteca:

```bash
bash tools/validate.sh --graph    # muestra los IDs de la biblioteca
```

Para cada candidata cuyo ID **ya existe en la biblioteca**, resolvelo con la
regla `[no-clobber]`: por default se renombra **la importada**. Renombrar la
de la biblioteca solo si la importada es estrictamente mejor y la de la
biblioteca no tiene consumidores; no importar solo si no es reusable.
**Preguntá únicamente** cuando ninguna de esas opciones sea aceptable.

También revisá colisiones **entre** las candidatas: si dos traen el mismo ID,
solo puede entrar una.

Y colisiones con skills de **internet** ya instaladas: si el usuario tiene
`code-review` de un repo público y trae su propia `code-review`, el nombre
final tiene que distinguirla.

## 3. Clasificar

Para cada candidata, aplicá `[classify-reusable]`:

| Destino | Criterio |
|---|---|
| A la biblioteca | El procedimiento sirve en cualquier proyecto |
| Se queda en el proyecto | Depende de rutas, dominio o deploy de ese repo |
| Interna | Conocimiento general que no querés anunciar |

Justificá cada decisión en una línea. Si dudás entre la biblioteca y el
proyecto, se queda en el proyecto: es la opción que no rompe nada.

## 4. Normalizar

Aplicá `[normalize-frontmatter]` a cada skill que va a entrar.

Revisá además:

- El body, ¿repite lo que el modelo ya sabe? (ver las pautas de creación del
  `AGENTS.md` de la biblioteca)
- Las reglas, ¿tienen ID las que van a ser sobrescribibles?
- Las referencias a archivos: `references/…`, `scripts/…`, `assets/…` tienen
  que existir en la carpeta importada. Si la skill traída apunta a archivos
  que no vienen con ella, traelos o sacá la referencia.
- Si la skill declara `metadata.requires`, cada skill requerida tiene que
  estar **nombrada en la sección `## Prerequisites`** del body: el agente
  nunca ve el frontmatter de otras skills.
- Si la skill declara `metadata.overrides`, el `rule-id` tiene que existir
  como `### [rule-id]` en la skill base.
- `SKILL.md` < 500 líneas. Si es más larga, el detalle va a `references/`.

## 5. Copiar y renombrar

```bash
mkdir -p skills/<categoria>/<nombre-final>
cp -r <origen>/<nombre>/. skills/<categoria>/<nombre-final>/
```

El nombre de la carpeta final tiene que ser el `name` del frontmatter. Si
renombrás, **cambiá las dos cosas**: carpeta y `name`. El validador lo exige.

## 6. Agregar la procedencia

Al final del body de la skill importada:

```markdown
---

> Origen: `<repo o ruta>`, importada el `<fecha>`.
> Normalizado: `<qué se cambió respecto del original>`.
```

## 7. Proponer

Presentá la propuesta con `assets/import-proposal-template.md` y **esperá
aprobación**.

## 8. Validar

```bash
bash tools/validate.sh --write
```

Si falla: **revertí** lo importado y rehacelo. Los casos típicos:

- **`ID duplicado`** → te faltó un nombre final único.
- **`name` no coincide con la carpeta** → renombrá una de las dos.
- **`metadata.category` no coincide** → la carpeta no es la que pensaste.
- **`metadata` no es string** → una lista o un mapa donde va un valor simple.
- **`requires` apunta a algo inexistente** → traé la skill base o sacá el
  `requires`.
- **`requires` no aparece en `## Prerequisites`** → el agente nunca ve el
  frontmatter de otras skills: nombrala en el body.
- **`overrides` no matchea ninguna regla `[rule-id]`** → el ID cambió en la
  skill base, o el `### [rule-id]` no está.
- **`description` multilinea** → el parser solo lee la primera línea: la
  descripción se pierde. Va en una sola línea.

## 9. Commit y distribución

Solo si el usuario lo pide:

```bash
bash tools/validate.sh --check
git add -A
git commit -m "feat(skills): import <n> skills from <origen>"
git push gitea main   # o `origin` en las máquinas que clonaron desde Gitea
```

Un commit por importación, o uno por origen. No mezcles una importación con
una conciliación: si el validador falla, tiene que ser obvio cuál de las dos
cosas rompió la skill.

## 10. Reportar

- Qué se importó, de dónde, a qué categoría y con qué nombre final.
- Qué se quedó en el proyecto y por qué.
- Qué no se importó y por qué.
- Qué normalizaciones se hicieron.
- Resultado del validador.
