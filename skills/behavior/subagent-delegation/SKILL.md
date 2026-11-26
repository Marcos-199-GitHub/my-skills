---
name: subagent-delegation
description: Decide when to run part of a task in a subagent instead of inline - to parallelize independent investigations, to keep heavy exploration out of the main context, and to get a conclusion instead of a transcript. Use when a task spans many files, when several independent questions can be investigated at once, when the context window is filling up, or when the result only matters as findings.
license: MIT
metadata:
  category: behavior
  version: "1"
---

# Delegación a subagentes

El contexto de una sesión es finito y el de un subagente también. Delegar
no es "mandar trabajo": es **decidir qué parte del contexto no necesita
existir en el hilo principal**.

## Las tres razones

| Razón | Qué gana |
|---|---|
| **Contexto** | El subagente carga lo que necesita y devuelve la conclusión. El hilo principal no se ensucia con lo intermedio |
| **Paralelismo** | Tareas independientes corren a la vez, en vez de una atrás de otra |
| **Foco** | El subagente arranca con contexto limpio: sin las suposiciones, los desvíos ni el cansancio de la conversación principal |

La tercera es la que más se subestima. Un subagente que arranca fresco
reconsidera el problema; el hilo principal, con diez turnos de contexto,
tiende a confirmar lo que ya venir pensándolo.

## El criterio

> **Delegá cuando el resultado importa y el camino no.**

Delegá si se cumple alguna de estas:

| Señal | Por qué |
|---|---|
| La tarea abarca muchos archivos | El subagente lee 30 archivos y te devuelve 5 hallazgos; vos leés 5 líneas |
| Hay varias preguntas **independientes** | Se pueden investigar en paralelo |
| Solo necesitás el **resultado**, no el proceso | "Qué archivos tocan el auth" es un resultado; "cómo funciona el módulo" es un proceso |
| El contexto principal ya está cargado | Bajar 40k tokens de golpe |
| La búsqueda es abierta y el resultado es incierto | Un subagente que vuelve con "no hay" también vale: es un resultado |

**No delegues** si:

| Señal | Por qué |
|---|---|
| La tarea es chica | El costo de arranque (contexto nuevo + informe) no se amortiza |
| El resultado se usa **tal cual** (código a escribir, un diff a aplicar) | El informe no es el entregable; vas a tener que reconstruirlo |
| La tarea depende del hilo acumulado | El subagente arranca sin contexto: hay que reexplicarle todo, y lo que se reexplica es lo que se pierde |
| Necesitás **intervenir** durante el proceso | No podés redirigir a un subagente que ya va por otro camino |

## Cómo delegar bien

El subagente **arranca con contexto vacío**. No sabe nada de tu
conversación, ni de lo que ya encontraste, ni de lo que ya decidiste. Su
prompt tiene que ser autocontenido.

### 1. Que el prompt sea autocontenido

Mal:

> "Revisá el tema de autenticación"

Bien:

> "En el repo /ruta/al/proyecto, buscá todos los lugares donde se validan
> credenciales: middleware, guards de rutas, servicios de login. No hace falta
> que edites nada. Devolvé una lista de archivo:línea con una línea de qué
> valida cada uno."

### 2. Pedí el resultado, no la transcripción

| En vez de | Pedí |
|---|---|
| "Explorá el proyecto y contame qué encontraste" | "Devolvé una lista de hallazgos con `archivo:línea` y una línea cada uno" |
| "Investigá si hay un bug de race condition" | "Decidí: ¿hay race condition? Sí/No + el archivo y la línea donde ocurre" |
| "Revisá los tests" | "Devolvé los nombres de los archivos de test que faltan para cubrir X" |

Si no definís el formato de salida, el subagente devuelve un muro de texto
que vos tenés que procesar — que es exactamente lo que querías evitar.

### 3. Decidí el criterio por adelantado

Si el subagente tiene que decidir algo, decile **con qué criterio**:

> "Si encontrás más de 5 lugares que validan credenciales, devolvé solo los 5
> más usados. Si encontrás menos, devolvé todos."

Sin eso, el subagente decide con un criterio que no es el tuyo.

### 4. Consumí el informe, no lo pegues

El informe es un **resumen**, no la fuente. Verificá los hallazgos que van a
tocar código antes de actuar sobre ellos: un subagente puede estar
equivocado con total seguridad.

## Paralelismo

Las tareas que **no dependen entre sí** se lanzan a la vez:

```
→ subagente A: "buscá dónde se validan credenciales"
→ subagente B: "buscá dónde se registran tokens"
→ subagente C: "mirá si hay tests de expiración de token"
```

Si B necesita el resultado de A, **no es paralelo**: es una cadena, y ahí
conviene hacerlo en el hilo principal o delegar A primero.

## Límites

- **Los subagentes no lanzan subagentes** (en OpenCode, `subagent_depth` es 1
  por default). Si sentís que necesitás tres niveles, el problema es de
  **partición**: dividí la tarea en dos y repartilas vos.
- **El subagente también corre con el bloque always-on**, así que ya conoce el
  protocolo de trabajo. No hace falta reexplicarle las reglas del repo.
- Cada subagente tiene su **propio contexto**: no ve lo que otro subagente
  encontró. Si dos necesitan compartir un hallazgo, pasáselo vos.

## Detalle

- Mecánica por agente (OpenCode: `mode: subagent`, permisos, `subagent_depth`,
  agentes built-in): `references/opencode.md`
