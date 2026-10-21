# Flujo de trabajo Git de Bearlytics

Política de colaboración del proyecto. **Este documento manda**: si una regla de `AGENTS.md` o de un agente contradice este fichero, prevalece este.

## 1. Modelo: trunk-based por fases

`main` es el **trunk** del proyecto: siempre desplegable, siempre coherente, y **nunca se trabaja directamente sobre ella**. El trabajo se hace en ramas cortas que llegan a `main` mediante Pull Request revisado por una persona.

```
                          PR (gate cumplido)          PR
   main  ◄──── merge persona ──── feature/eda-uni-<tarea>
     ▲
     ├──────── merge persona ──── feature/eda-multi-<tarea>
     ├──────── merge persona ──── feature/preprocess-<tarea>
     ├──────── merge persona ──── feature/modeling-<tarea>
     ├──────── merge persona ──── fix/<tarea>
     └──────── merge persona ──── exp/<experimento>
```

**Por qué trunk-based y no GitFlow:** el proyecto es un pipeline de fases cortas con entregables verificables (figuras, tablas, score). Acumular fases en una rama de integración larga ralentiza la integración y hace los diffs ilegibles. Con trunk-based, cada PR es pequeño, revisable y su gate es comprobable de un vistazo.

**Qué NO se hace:**
- Nunca `git commit` directamente en `main`.
- Nunca push directo a `main` (ni con `--force`, ni siquiera sin `--force`).
- Nunca una rama que mezcla dos fases o dos temas.

## 2. Nomenclatura de ramas

| Prefijo | Uso | Fases válidas | Ramas de ejemplo |
|---|---|---|---|
| `feature/` | Trabajo nuevo de una fase | `eda-uni`, `eda-multi`, `preprocess`, `modeling` | `feature/eda-uni-degradacion-inicial` |
| `fix/` | Corrección de un fallo o regresión | — | `fix/indice-rul-desbordado` |
| `exp/` | Experimento de modelado que no entra en `main` | — | `exp/lstm-hi` |
| `docs/` | Solo documentación | — | `docs/guia-dataset` |
| `chore/` | Configuración, CI, refactors sin cambio de comportamiento | — | `chore/validacion-agentes` |

Formato: `<prefijo>/<fase>-<tarea-corta-en-kebab-case>`.

Reglas de la nomenclatura:
- En minúsculas, con guiones.
- La fase se escribe exactamente como en la tabla (`eda-uni`, no `eda_uni` ni `EDA/UNI`).
- La tarea describe el entregable, no la acción (`feature/modeling-score-phm2012`, no `feature/modeling-hacer-score`).

## 3. Ciclo de vida de una rama

```bash
# 1. Partir de main actualizado
git switch main
git pull --ff-only

# 2. Crear la rama de la fase
git switch -c feature/eda-uni-degradacion-inicial

# 3. Trabajar (commits atómicos)
git status
git diff
git add EDA/Uni/...
git commit -m "feat(eda-uni): deteccion de inicio de degradacion por RMS y kurtosis"

# 4. Actualizar la rama con main antes de pedir revision
git pull --rebase origin main

# 5. Publicar la rama
git push -u origin feature/eda-uni-degradacion-inicial

# 6. Abrir PR hacia main (title, descripcion, checklist del gate)
```

### Antes de abrir el PR

```bash
git status                      # working tree limpio
git diff main...HEAD --stat     # alcance real del PR
git log --oneline main..HEAD    # commits del PR
```

Y comprueba que:
- El PR toca **solo** la carpeta de su fase (más `results/`, docs y `README.md` de la fase).
- El gate de la fase está cumplido y documentado.
- La evidencia de ejecución (salida de `matlab -batch`) está en la descripción del PR.
- No hay dataset, `.mat` pesados ni ficheros generados por tu editor.

## 4. Gates por fase: qué debe cumplir cada PR

| Fase | Gate obligatorio en el PR |
|---|---|
| `eda-uni` | Figuras rotuladas por rodamiento, tabla de la feature con mejor poder de early warning y sección en `EDA/Uni/README.md` |
| `eda-multi` | Figuras de correlación y PCA, veredicto de comparabilidad entre condiciones y sección en `EDA/Multi/README.md` |
| `preprocess` | Tabla de features reproducible, conteo de filas por partición, split por rodamiento documentado y sección en `PreProcess/README.md` |
| `modeling` | Tabla comparativa de modelos, score PHM 2012 por rodamiento y agregado, figura de trayectorias y sección en `Modeling/README.md` |

Ningún PR avanza de fase sin que el gate de la fase anterior esté mergeado en `main`.

## 5. Commits

- **Conventional Commits**: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`, con el alcance de fase opcional: `feat(eda-uni): ...`.
- **Atómicos**: un commit = un cambio con sentido. No mezcles refactor y cambio de comportamiento.
- Mensaje en imperativo y en **español** (el proyecto se comunica en español), identificadores de código en inglés.
- El cuerpo del mensaje explica el **porqué**; el qué ya está en el diff.

```
feat(preprocess): normalizacion de features ajustada solo con train

Se ajusto el escalado con la media y desviacion del split de training
para evitar fuga de informacion hacia validation y test.
```

## 6. Merges, rebase y fuerzas

| Situación | Acción |
|---|---|
| Tu rama de trabajo está desfasada respecto a `main` | `git pull --rebase origin main` (rebase sí) |
| `main` tiene commits nuevos y tu rama va a `main` | Merge de `main` en el PR, nunca al revés |
| Corrección de un commit ya publicado en tu rama | `git rebase -i` solo si la rama es personal y nadie más la usa |
| `main` | Nunca se reescribe: no rebase, no `reset --hard`, no force-push |
| `git push --force` / `-f` | **Prohibido** en cualquier rama compartida. Solo `--force-with-lease` en rama personal |

## 7. Roles

| Quién | Puede | No puede |
|---|---|---|
| Persona autora | Escribir código, commitear, pushear su rama, abrir PR, **mergear a `main`**, poner tags | — |
| Persona revisora | Comentar, aprobar, solicitar cambios | — |
| Agente de IA | Escribir código en la carpeta de su fase, commitear y pushear **su rama** con confirmación, preparar el PR | Mergear a `main`, pushear a `main`, hacer force-push, tocar el dataset, salir del ámbito de su fase |

## 8. Protección de `main` en GitHub

`main` debe estar protegida. Configuración en **Settings → Branches → Branch rules → Add rule**:

| Regla | Valor |
|---|---|
| Branch name pattern | `main` |
| Require a pull request before merging | ✅ (1 approval, dismiss stale approvals ✅) |
| Require linear history | ✅ |
| Block force pushes | ✅ |
| Require status checks to pass | ✅ (`validate-agents`) |
| Do not allow bypassing the above settings | ✅ |
| Restrict deletions | ✅ |

Procedimiento manual (no hay `gh` CLI en el entorno de trabajo):

1. Abrir el repo en GitHub → **Settings** → **Branches**.
2. **Add rule** → *Branch name pattern* = `main`.
3. Activar las reglas de la tabla.
4. Guardar y verificar que aparece en *Branch protection rules*.

Hasta que la protección esté activa, la regla "nunca se commitea en `main`" depende de la disciplina del equipo; con la protección, pasa a ser una barrera técnica.

## 9. Versionado por fase

Cuando una fase se completa y se mergea en `main`, la persona responsable etiqueta el estado:

```bash
git tag -a v0.1.eda-uni -m "EDA univariada completa: degradacion detectada en 5 rodamientos"
git push origin v0.1.eda-uni
```

Esquema: `v<mayor>.<menor>.<fase>`, p. ej. `v0.1.eda-uni`, `v0.2.preprocess`, `v0.3.modeling`.

## 10. Checklist del PR (resumen)

- [ ] La rama sigue la nomenclatura y sale de `main` actualizado.
- [ ] El PR toca solo la carpeta de su fase (+ `results/`, README de la fase).
- [ ] El gate de la fase está cumplido (ver tabla de la sección 4).
- [ ] La descripción incluye la evidencia de ejecución real.
- [ ] `git status` limpio; sin dataset ni `.mat` pesados.
- [ ] Commits atómicos con Conventional Commits.
- [ ] Hay al menos un revisor aprobado antes de mergear.
- [ ] El merge lo hace una persona.

## 11. Referencias

- `AGENTS.md` (sección 7) — versión resumida de esta política, cargada en cada sesión de agente.
- `.opencode/skill/git-workflow/SKILL.md` — referencia rápida para agentes.
- `.opencode/command/branch.md` — comando `/branch` para crear la rama de una fase.
- `.github/PULL_REQUEST_TEMPLATE.md` — plantilla de PR.
- `Agentes/WORKFLOWS.md` — flujo por fases y handoffs.
