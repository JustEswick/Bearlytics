---
name: git-workflow
description: Use when creating a branch, committing, opening a pull request or merging in Bearlytics - the trunk-based policy per phase, branch naming rules, what a PR must include, and the git commands to use. Covers "rama", "branch", "commit", "pull request", "PR", "merge", "main", "feature/", "rebase".
license: MIT
metadata:
  project: Bearlytics
  domain: git
---

# Flujo Git de Bearlytics (trunk-based por fases)

Referencia rápida de la política. La versión completa está en `Agentes/GIT_WORKFLOW.md`.

## Regla que no se rompe

**Nunca trabajes ni commitees en `main`.** Antes de cada commit:

```bash
git branch --show-current
```

Si devuelve `main`, crea primero la rama de tu fase. Los pushes a `main` están bloqueados por permisos, y el merge lo hace una persona.

## Nomenclatura

| Prefijo | Fase válida | Ejemplo |
|---|---|---|
| `feature/` | `eda-uni`, `eda-multi`, `preprocess`, `modeling` | `feature/preprocess-tabla-features` |
| `fix/` | — | `fix/indice-rul-desbordado` |
| `exp/` | — | `exp/lstm-hi` |
| `docs/` | — | `docs/guia-dataset` |
| `chore/` | — | `chore/validacion-agentes` |

Formato: `<prefijo>/<fase>-<tarea-en-kebab-case>`, en minúsculas.

## Crear la rama de una fase

```bash
git switch main
git pull --ff-only
git switch -c feature/<fase>-<tarea>
```

## Commit

```bash
git status
git diff
git add <ficheros>
git commit -m "feat(<fase>): <descripcion en imperativo>"
```

- Conventional Commits, un commit = un cambio con sentido.
- Mensajes en español, identificadores de código en inglés.
- Nunca subas `.mat` pesados, el dataset ni ficheros del editor.

## Antes de abrir el PR

```bash
git pull --rebase origin main    # rebase sí en tu rama
git status                       # limpio
git diff main...HEAD --stat      # alcance del PR
git log --oneline main..HEAD
git push -u origin feature/<fase>-<tarea>
```

El PR debe:
1. Cumplir el gate de su fase (ver `AGENTS.md` §3).
2. Incluir la **evidencia de ejecución** (salida real de `matlab -batch`).
3. Tocar solo la carpeta de la fase (+ `results/` y el README de la fase).
4. Tener al menos un revisor aprobado.

Usa la plantilla `.github/PULL_REQUEST_TEMPLATE.md` al redactarlo.

## Prohibido

- `git commit` en `main`.
- `git push` a `main` (bloqueado por permisos).
- `git push --force` / `-f` en ramas compartidas.
- `git reset --hard` sobre trabajo de otros.
- Rebase de `main`.
- Mezclar dos fases en la misma rama.

## Excepciones

- Una etiqueta (`v0.1.eda-uni`) la pone una persona tras cerrar la fase.
- Un merge a `main` lo hace una persona; los agentes dejan el PR listo.
