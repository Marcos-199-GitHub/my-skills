---
name: skill-name
description: One sentence saying what the skill does and when to use it, in English. Include the trigger words a user would actually type.
license: MIT
# compatibility: requisitos de entorno, en una sola linea (<=500 caracteres).
# Opcional: solo si la skill tiene requisitos reales.
compatibility: Requires <lo que necesita>.
metadata:
  category: <categoria>
  version: "1"
---

# Título de la skill

<!--
  Reglas del repo:
  - name == nombre de la carpeta (kebab-case, <=64 chars, minusculas).
  - description en INGLES: qué hace + cuándo usarla. Es lo único que el
    modelo ve para decidir si la carga. Si no tiene trigger, no se carga nunca.
  - Body en español.
  - metadata.category tiene que coincidir con la carpeta donde va la skill:
    behavior, environment o maintenance.
  - Cada regla sobrescribible lleva un ID: ### [rule-id] Titulo
  - SKILL.md < 500 lineas. Lo demas a references/, assets/ o scripts/.
  - Si depende de otra skill: metadata.requires + seccion ## Prerequisites.
  - Si sobrescribe: metadata.overrides: "base-skill#rule-id"
-->

## Cuando usarla

<!-- Escenario concreto, no abstracto. -->

## Prerequisites

<!--
  Solo si metadata.requires tiene algo.
  Cada skill requerida tiene que estar nombrada acá, porque el agente nunca
  ve el frontmatter de otras skills.
-->

## Procedimiento

1. <!-- paso -->
2. <!-- paso -->

## Reglas

### [rule-id] Título de la regla

<!-- Regla imperativa y verificable. -->

## Detalle

<!--
  Los archivos de apoyo van aparte. Solo citá los que crees: el validador
  falla si el body cita un path que no existe. Para esta skill nueva:
-->

```text
references/REFERENCE.md   documentacion extendida
assets/TEMPLATE.md         plantillas
scripts/run.sh             scripts ejecutables
```
