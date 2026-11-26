# Criterios de commit

Referencia extendida de las reglas `[commit-*]` del protocolo de trabajo.

## Checklist antes de commitear

- [ ] El commit incluye código, documentación y pruebas del mismo cambio
      (ver `[commit-atomic]`).
- [ ] Revertirlo no deja documentación desactualizada ni pruebas huérfanas.
- [ ] Las revisiones del proyecto pasan (ver `[commit-verify]`).
- [ ] No hay secretos, artefactos de debug ni archivos generados (ver `[commit-never]`).
- [ ] No hay cambios ajenos al objetivo mezclados en el diff.
- [ ] El mensaje sigue `<tipo>(<scope>): <descripción>`, en imperativo y sin
      punto final, de ≤72 caracteres.
- [ ] Si el usuario te corrigió durante este cambio, la lección quedó registrada
      (ver `[learn-from-error]`).

## Ejemplos

### Bien

```
feat(auth): add refresh token rotation
fix(parser): handle CRLF in legacy CSV imports
refactor(skills): extract frontmatter parsing into a helper
docs(readme): document the bootstrap prompt
chore(deps): bump jq to 1.7.1
```

Un cambio completo se comitea junto: una optimización incluye la
implementación, la medición que la justifica, el test que evita la regresión y
la línea de documentación que declara el presupuesto. Separar eso en cuatro
commits obligaría a revertir cuatro para deshacer una sola cosa.

### Mal

```
update
fix
wip
changes
feat: stuff
Fixed the bug that was causing the issue in the module
```

## Tipos

| Tipo | Para qué |
|---|---|
| `feat` | Funcionalidad nueva |
| `fix` | Corrección de un bug |
| `refactor` | Reestructuración sin cambio de comportamiento |
| `perf` | Mejora de rendimiento |
| `docs` | Documentación |
| `test` | Tests |
| `build` | Build, dependencias, tooling |
| `chore` | Mantenimiento que no es ninguno de los anteriores |

## Scopes

El scope es el área del sistema. Usá el que ya exista en el repo: si el
proyecto usa scopes por módulo (`api`, `db`, `ui`), seguí esa convención. Si
no usa scopes, no los inventes.

## Commits vs. branches

- Un commit por cambio lógico, en la rama en la que trabajás.
- No commitees directamente en la rama principal si el proyecto usa pull
  requests. Leé `AGENTS.md` del proyecto para saber la convención.
- Si un commit se rompe a la mitad, hacé `git reset --soft HEAD~1` y rehacelo.
  Eso es seguro: no se pierde nada.

## Qué NO va en un commit

| Archivo | Por qué |
|---|---|
| `.env` con valores | Secretos |
| `*.log` | Ruido |
| `dist/`, `build/`, `out/` | Generado |
| `node_modules/`, `vendor/` | Dependencias |
| `.coverage`, `coverage/` | Generado |
| Screenshots de debug | Ruido |
| `*.orig`, `*.rej` | Artefactos de merge |
