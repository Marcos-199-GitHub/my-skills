# Protocolo de conciliación

Paso a paso. Cada paso dice qué hacer, cómo verificarlo y qué hacer si falla.

## 0. Preparación

Desde la raíz del repo de esta biblioteca:

```bash
git status --short          # el árbol tiene que estar limpio
git pull --ff-only          # conciliar sobre una base vieja es peor que no conciliar
```

Si el árbol está sucio: **no lo toques**. Reportá y preguntá.

Si el pull trae cambios: releé el diff de las skills que ibas a tocar. Puede
que otra máquina ya concilió algo parecido y tu entrada ahora sea redundante.

## 1. Leer el inbox

```bash
cat .learning/inbox.md
```

Si no existe o está vacío → no hay nada que conciliar. Decilo y terminá.

Contá cuántas entradas hay. Ese número es tu métrica de la conciliación.

## 2. Clasificar

Para cada entrada, aplicá la regla `[classify-before-writing]` y anotá el
destino. Armá una tabla mental:

| # | Entrada | Destino | Nota |
|---|---|---|---|
| L-2026-11-26-2214-vm1 | no commitear sin lint | `work-protocol` → `[commit-verify]` | endurece la regla |

**Caso especial — entrada de proyecto.** Si el destino es el `AGENTS.md` de un
repo que **no es esta biblioteca**, no lo escribas: no tenés el repo. Dejala en
el inbox, marcala como `pendiente:<proyecto>` en la propuesta, y decilo en el
reporte.

## 3. Agrupar

Agrupá las entradas que van al mismo destino. Si dos entradas tocan la misma
regla, **una** regla nueva las cubre.

El objetivo es que el diff sea chico y completo, no que refleje entrada por
entrada.

## 4. Redactar

Para cada grupo, escribí el cambio exacto:

- **Skill existente, regla existente** → el texto nuevo de esa regla, con su
  ID intacto.
- **Skill existente, regla nueva** → la regla nueva, con ID nuevo y único, en
  la posición correcta dentro del `SKILL.md`.
- **Skill nueva** → la carpeta, el `SKILL.md` completo y su frontmatter.

Verificá el ID de la regla nueva contra las que ya existen en esa skill: no
puede repetirse.

Si el cambio **debilita** una regla, marcalo en la propuesta con una línea
que lo diga (regla `[never-weaken-silently]`).

## 5. Proponer

Presentá la propuesta con el formato de `assets/proposal-template.md`:

- Una sección por grupo.
- El diff exacto, no un resumen.
- Una línea de motivo por grupo.
- Las entradas que se descartan, con el motivo.

**Esperá aprobación explícita.** No apliques nada antes.

Si el usuario pide cambios, ajustá y volvé a proponer. Si aprueba una parte
solamente, aplicala solo a esa parte.

## 6. Aplicar

Aplicá **solo** lo aprobado. Si un grupo no fue aprobado, su entrada queda en el
inbox.

## 7. Validar

Verificá sin escribir:

```bash
bash tools/validate.sh --check
```

Si falla: **revertí**. No apliques un cambio que rompe la biblioteca. El
validador mira, entre otras cosas, que los `requires` apunten a skills que
existen, que los `overrides` apunten a reglas que existen, que no haya IDs
duplicados y que el índice del README esté al día.

Volvé a revisar el grupo que rompió y rehacelo. Si no se puede arreglar sin
debilitar algo, eso es una decisión del usuario: presentalo.

Una vez aplicado lo aprobado, regenerá el índice:

```bash
bash tools/validate.sh --write
```

## 8. Indexar

Por cada entrada conciliada, agregá **una fila** al índice de
`skills/behavior/work-protocol/references/lessons.md`:

```
| 2026-11-26 | vm1 | No commitear sin lint en verde | `work-protocol` → `[commit-verify]` |
```

Si un aprendizaje no pertenece a ninguna skill, su contenido va completo en la
sección de abajo del índice, no solo una fila.

## 9. Limpiar el inbox

Sacá las entradas conciliadas. Si el usuario aprobó solo una parte, sacá solo
esa parte. **No se sale de este paso hasta verificarlo**:

```bash
bash skills/maintenance/learning-reconcile/scripts/check-inbox.sh <id-aplicado> ...
```

El script falla si cualquiera de esos IDs sigue en el inbox. La limpieza va
antes del commit: si la conciliación se publica con entradas aplicadas adentro,
la próxima sesión las vuelve a proponer.

Las entradas descartadas también se borran: una entrada descartada está
conciliada igual (se decidió que no aplica en ninguna skill). Pero
informá cuáles eran y por qué: el usuario puede no estar de acuerdo.

## 10. Commit y distribución

Solo si el usuario lo pide:

```bash
bash tools/validate.sh --check
git add -A
git commit -m "feat(skills): reconcile learning into <destinos>"
git push gitea main   # o `origin` en las máquinas que clonaron desde Gitea
```

El push **pide confirmación**: el agente principal tiene `git push *` en
`ask`. Es el último control y está ahí a propósito: una conciliación
toca la biblioteca que usan las otras máquinas.

Un solo commit para la conciliación entera. Si el diff incluye cambios que no
son de conciliación, van en otro commit (regla `[no-refactor-on-the-side]`).

Las otras máquinas:

```bash
git pull --ff-only
bash tools/validate.sh --check
```

## 11. Reportar

- Entradas conciliadas y destino de cada una.
- Entradas descartadas, con motivo.
- Entradas que quedaron en el inbox, con motivo.
- Resultado del validador.
- Cambios que debilitan reglas, dichos explícitamente.
- Qué quedó pendiente para la próxima.
