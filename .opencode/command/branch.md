---
description: Crea la rama de trabajo de una fase de Bearlytics desde main actualizado y verifica que no se está trabajando sobre main.
agent: bearlytics-lead
---

Crea una rama de trabajo para una fase del pipeline de Bearlytics.

Fase: $ARGUMENTS

## Fases válidas

`eda-uni` · `eda-multi` · `preprocess` · `modeling`

Si la fase indicada no está en la lista, pide aclaración antes de crear la rama. Si la petición no incluye fase, propón la fase en la que estamos según el estado del repo.

## Pasos

1. **Comprueba la rama actual**:

```bash
git branch --show-current
git status --short
```

Si hay cambios sin commitear, no los muevas: avisa y pregunta si quieres que se commiteen en la rama actual o se descarten.

2. **Actualiza `main` y crea la rama**:

```bash
git switch main
git pull --ff-only
git switch -c feature/<fase>-<tarea>
```

Derivación de `<tarea>` a partir de la petición del usuario, en kebab-case y en minúsculas. Si no hay tarea clara, genera una descriptiva del entregable esperado (p. ej. `feature/eda-uni-degradacion-inicial`).

3. **Verifica el resultado**:

```bash
git branch --show-current
```

Confirma que la rama activa ya no es `main` y muéstrale al usuario la ruta exacta de la rama creada.

## Notas

- Nunca commitees en `main`; si la rama activa es `main`, este comando es el primer paso obligatorio.
- El merge a `main` lo hace una persona: tú preparas el trabajo y el PR.
- Más detalle en la skill `git-workflow` y en `Agentes/GIT_WORKFLOW.md`.
