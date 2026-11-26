---
name: learning-reconcile
description: Turn accumulated learning into concrete improvements to the skills - classify each pending entry by its target, group the ones that belong together, draft the exact changes, validate them and distribute them. Use when the user asks to reconcile learned lessons, apply pending learning, improve the skills based on what the agents learned, or process the learning inbox.
license: MIT
metadata:
  category: maintenance
  requires: "work-protocol"
  overrides: "work-protocol#commit-verify"
  version: "1"
---

# Conciliación del aprendizaje

Convierte lo aprendido en mejoras concretas de las skills.

El **inbox** dice *qué* se aprendió. Esta skill define *cómo* se aplica: el
protocolo, las pautas y las consideraciones.

## Prerequisites

Cargá la skill **`work-protocol`** antes de esta. Trae el flujo de trabajo, los
criterios de commit y la regla `[learn-from-error]` que origina las entradas
que conciliás.

## Overrides

- `[commit-verify]` (de `work-protocol`): en una conciliación, la verificación
  **no** son los comandos del proyecto: es `bash tools/validate.sh --check`.
  El validador es la red de seguridad, porque un cambio acá rompe la skill en
  todas las máquinas.

## El flujo, en corto

```
leer inbox  →  clasificar  →  agrupar  →  proponer  →  aprobar
                                                          ↓
   indexar  ←  limpiar inbox  ←  aplicar  ←  validar
```

El protocolo detallado, paso a paso, está en `references/protocol.md`.

## Reglas

### [reconcile-local-only] El inbox es de esta máquina

El inbox vive en la máquina donde se aprendió. Si el usuario pide conciliar lo
aprendido en otra máquina, no lo vas a encontrar acá: decile que lo haga en esa
máquina, o que comparta el inbox.

Para encontrarlo: está en `.learning/inbox.md`, en la **raíz del repo de esta
biblioteca** (tres niveles arriba del base dir de esta skill).

Nunca escribas en el inbox de otra máquina.

### [classify-before-writing] Clasificá antes de redactar

Cada entrada va a **uno** de estos destinos. Decidilo antes de redactar nada:

| Destino | Cuándo |
|---|---|
| Skill existente, regla existente | Endurece o aclara una regla que ya está |
| Skill existente, regla nueva | Es conocimiento nuevo que encaja en una skill |
| Skill nueva | Es un procedimiento completo que no existe todavía |
| `AGENTS.md` de un proyecto | Era específico de un repo, no global |
| Descartar | No es reutilizable, o ya está cubierto |

Si no sabés a qué destino va, la entrada probablemente no sea reutilizable.
Descartala y decí por qué.

El **tipo** de la entrada cambia la inclinación del destino:

| Tipo | Suele acabar en |
|---|---|
| `correccion` | Una regla que se endurece o se aclara. El comportamiento era incorrecto |
| `caso` | Conocimiento nuevo: una skill, una regla nueva, o un documento de referencia. No hubo error: hubo un problema que se resolvió |

Un `caso` que se resuelve con una regla general es un caso **encajado**: mejor
así que como documento suelto. Pero si el caso tiene partes que solo aplican a
una situación, el caso se documenta y la regla cubre lo general.

### [propose-then-apply] Proponé, esperá, después aplicá

Presentá el cambio **concreto** (el diff exacto, no un resumen) y esperá
aprobación explícita. Esto modifica la biblioteca que usan otras máquinas.

Si el usuario aprobó, aplicá **todo** lo aprobado. Si aprobó una parte, aplicá
solo esa parte y dejá las otras entradas en el inbox.

Una pregunta no es aprobación. Si el usuario pregunta «¿aprendiste?»,
«¿lo aplicaste?» o algo equivalente, la respuesta es el diff propuesto y la
espera: registrá la entrada en el inbox, mostrá el cambio concreto y no
toques la biblioteca hasta que diga explícitamente que sí. Aplicar por
adelantado salta el paso que protege a las otras máquinas.

### [never-weaken-silently] No debilites una regla sin decirlo

Si un cambio **reduce** el rigor de una regla existente —la hace opcional,
la acota, la contradice— decilo explícitamente en la propuesta, aunque no lo
hayas pedido.

Preferí **endurecer** a reemplazar: una regla nueva que contradice una vieja
convive con ella, o la reemplaza justificando por qué. Borrar una regla sin
razón es una regresión silenciosa.

### [validate-before-distribute] El validador es la red

Verificá antes de aplicar:

```bash
bash tools/validate.sh --check
```

Si falla, **no apliques**. Un `requires` que apunta a algo inexistente, un ID
duplicado o un `overrides` a una regla que no existe rompen la skill en todas
las máquinas. Revertí y rehacé el cambio. Después de aplicar, regenerá el
índice con `bash tools/validate.sh --write`: ese modo valida **y** escribe;
`--check` es el que solo verifica.

### [index-every-thing] Todo lo conciliado deja fila en el índice

Cada aprendizaje aplicado agrega **una fila** al índice de
`references/lessons.md` de `work-protocol`: fecha, origen (máquina), qué se
aprendió y en qué skill quedó.

Sin el índice, el aprendizaje queda aplicado pero invisible: nadie puede
auditar qué sabe la biblioteca ni rastrear de dónde salió.

### [clean-the-inbox] La conciliación no termina hasta limpiar el inbox

Una entrada conciliada que queda en el inbox se vuelve a proponer en la
próxima conciliación, puede divergir de lo que ya quedó aplicado en la skill y
ocupa contexto en cada sesión. Borrarla **es parte de la conciliación**, no un
paso opcional posterior: no se commitea ni se reporta como terminada una
conciliación con entradas aplicadas todavía presentes.

Procedimiento:

1. Borrá del inbox cada entrada aplicada o descartada, con su ID.
2. Verificá que no queden, pasando esos IDs al script:
   ```bash
   bash skills/maintenance/learning-reconcile/scripts/check-inbox.sh <id> ...
   ```
3. Recién ahí pasá al commit y al reporte.

Las entradas **descartadas** también se borran, pero informá cuáles eran y por
qué: el usuario puede no estar de acuerdo. Las **pendientes** —no aprobadas, o
específicas de otra máquina— se quedan: no son ruido, son trabajo que todavía
no se hizo. Decilo en el reporte.

### [no-refactor-on-the-side] Una conciliación es una conciliación

No mezcles limpieza, refactor, renombres ni reorganización con la
conciliación. Si mientras revisás notás que algo más necesita arreglarse,
anotalo y reportalo aparte: va en su propio commit.

El motivo: si el validador falla, tiene que ser obvio **qué** de la
conciliación rompió la skill.

## Reporte

Al terminar:

- Qué entradas se conciliaron y a qué destino fue cada una.
- Qué se descartó y por qué.
- Qué se dejó en el inbox y por qué.
- Resultado del validador.
- Si hubo cambios que debilitan reglas, decilo otra vez acá.

## Detalle

- Protocolo paso a paso: `references/protocol.md`
- Formato de la propuesta: `assets/proposal-template.md`
