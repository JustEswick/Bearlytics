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
- Nunca push directo a `main` (ni con `--force`, ni siquiera sin `--force`): GitHub lo rechaza.
- Nunca un PR que entre a `main` sin 1 revisión aprobadora de otra persona.
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

**Métodos de merge permitidos:** solo **squash** y **rebase** (lo restringe el ruleset de GitHub; el botón de merge commit no existe). El squash mantiene el historial de `main` lineal y legible, que es el objetivo del modelo trunk-based.

## 7. Roles

| Quién | Puede | No puede |
|---|---|---|
| Persona autora | Escribir código, commitear, pushear su rama, abrir PR | Aprobar su propio PR (GitHub no cuenta la aprobación del autor) |
| Persona revisora | Comentar, **aprobar**, **solicitar cambios** (bloquea el merge) | — |
| Owner del repo (`@JustEswick`) | Lo de arriba + mergear cualquier PR + poner tags | Saltarse el PR: el bypass es *solo para pull requests* |
| Agente de IA | Escribir código en la carpeta de su fase, commitear y pushear **su rama** con confirmación, preparar el PR | Mergear a `main`, pushear a `main`, hacer force-push, tocar el dataset, salir del ámbito de su fase |

## 8. Protección de `main` en GitHub

`main` está protegida mediante un **ruleset** de GitHub (`main trunk-based`), que es la vía moderna y sustituye a las *branch protection rules* clásicas.

### 8.1 Configuración activa (verificada por API)

| Campo | Valor |
|---|---|
| Ruleset name | `main trunk-based` |
| Enforcement status | `Active` |
| Target branches | `refs/heads/main` |
| Bypass list | `@JustEswick` → **Allow for pull requests only** |
| Restrict deletions | ✅ |
| Block force pushes | ✅ |
| Require a pull request before merging | ✅ |
| ↳ Required approvals | **1** |
| ↳ Dismiss stale approvals on push | ✅ |
| ↳ Require approval of the most recent reviewable push | ✅ |
| ↳ Require conversation resolution | ✅ |
| ↳ Allowed merge methods | **Squash, Rebase** |
| Require status checks to pass | ✅ → `Valida opencode.json, agentes, comandos y skills` (GitHub Actions) |
| ↳ Require branches to be up to date before merging | ✅ (modo estricto) |
| Require linear history | ⬜ omitido (los métodos de merge ya lo garantizan) |

### 8.2 Estado real de la protección

Qué exige GitHub en la práctica, y qué pasa si alguien lo incumple:

| Requisito | Qué exige | Quién puede cumplirlo | Si no se cumple |
|---|---|---|---|
| Cambios en `main` | Siempre mediante Pull Request | Todos | Push directo rechazado (`GH006: Protected branch update failed`) |
| Aprobación | 1 revisión aprobadora de **otra** persona | Owner o cualquier collaborator | Botón de merge deshabilitado |
| Auto-aprobación | El autor del PR no puede aprobar su propio PR | — | Merge deshabilitado hasta que revise otro |
| Revisión caducada | Si se suben commits nuevos, la aprobación previa se descarta | Revisor | Merge deshabilitado hasta nueva aprobación |
| Conversación resuelta | Ningún comentario del reviewer puede quedar abierto | Autor del PR | Merge deshabilitado |
| CI | `Valida opencode.json, agentes, comandos y skills` en verde | GitHub Actions | Merge deshabilitado |
| Rama al día | El PR se evalúa contra `main` actualizado | Autor del PR | GitHub pide actualizar la rama y repite la CI |
| Force push | Bloqueado en `main` | — | Push rechazado |
| Borrado | `main` no se puede borrar | — | Borrado rechazado |
| Métodos de merge | Solo squash y rebase | Todos | El botón de merge commit no aparece |
| Bypass | Solo el owner y **únicamente vía PR** | Owner | Puede mergear sin CI ni aprobación |

**La asimetría del bypass, dicha con claridad:** el owner puede mergear cualquier PR sin CI en verde y sin aprobación de terceros (bypass). Los colaboradores **no**: su PR necesita CI en verde y una aprobación de otra persona. En la práctica, el owner **usa el botón *Approve*** en lugar de apoyarse en el bypass, para que el PR quede con registro real de revisión.

### 8.3 Procedimiento para crear o editar el ruleset

1. Repo → **Settings** → **Rules** → **Rulesets** → **New ruleset** → **New branch ruleset**.
2. *Ruleset name*: `main trunk-based`. *Enforcement status*: `Active`.
3. *Bypass list* → **Add bypass** → pestaña **Users** → `JustEswick` → en el kebab (`⋯`) → **For pull requests only**.
   - Importante: *For pull requests only* impide que el owner pushee directo a `main`; solo puede saltarse las reglas al mergear un PR.
4. *Target branches* → **Add target** → *Include branches* → escribir **`main`** (solo `main`, **sin** el prefijo `refs/heads/`: si se escribe completo, GitHub lo duplica y el ruleset deja de aplicarse).
5. *Branch rules*: activar las de la tabla 8.1.
6. *Create* / *Save*.

**Verificación (API, sin necesidad de token con permisos de administración):**

```powershell
Invoke-WebRequest -UseBasicParsing "https://api.github.com/repos/JustEswick/Bearlytics/rulesets" `
  -Headers @{ 'User-Agent'='opencode'; 'Accept'='application/vnd.github+json' }

# Debe devolver 4 reglas: deletion, non_fast_forward, pull_request, required_status_checks
Invoke-WebRequest -UseBasicParsing "https://api.github.com/repos/JustEswick/Bearlytics/rules/branches/main" `
  -Headers @{ 'User-Agent'='opencode'; 'Accept'='application/vnd.github+json' }
```

Si `rules/branches/main` devuelve `[]`, el patrón de destino está mal y **el ruleset no protege nada**.

### 8.4 CODEOWNERS

`.github/CODEOWNERS` asigna `@JustEswick` como owner de todo el repositorio y de cada carpeta de fase. GitHub **solicita automáticamente** esa revisión en cada PR que toque esas rutas.

En el ruleset, la opción **Require review from Code Owners** puede activarse para que la revisión del owner sea **obligatoria** y no solo una solicitud. Recomendación: activarlo cuando el equipo esté asentado y el flujo se vea estable.

### 8.5 Onboarding de colaboradores

Checklist para quien entra al proyecto:

1. **Rol en GitHub**: *Write* (Settings → Collaborators → Invite people). Con Write puede crear ramas, pushear y abrir PRs, pero **no** puede saltarse el ruleset: el bypass es solo del owner.
2. **Clonar el repo**: `git clone https://github.com/JustEswick/Bearlytics.git`.
3. **Instalar opencode** (https://opencode.ai) y autenticarse con un proveedor de modelo. La configuración del proyecto viene dentro del repo.
4. **Instalar MATLAB R2026b** + **Signal Processing Toolbox** + **Statistics and Machine Learning Toolbox** + la extensión oficial "MATLAB" de MathWorks en VS Code. Verifica:
   ```powershell
   matlab -batch "fprintf('%d %d\n', exist('pwelch'), exist('fitlm'));"
   ```
   Salida esperada: `2 2` (`pwelch`, `fitlm`).
5. **Descargar el dataset** y extraerlo **en `10. FEMTO Bearing/`** según `README.md` raíz: `Learning_set/`, `Full_Test_Set/` y `Test_set/` (no se versiona). No extraigas los zips anidados de `Test_set.zip`.
6. **Reiniciar opencode** tras el pull: la configuración se carga al arrancar, no en caliente.
7. **Leer** `AGENTS.md` (reglas), este documento y `Agentes/WORKFLOWS.md` (fases y gates).
8. **Primer cambio**: crear una rama `feature/<fase>-<tarea>` desde `main` actualizado y abrir un PR siguiendo la plantilla.
9. **Revisión**: ningún collaborator aprueba su propio PR (GitHub no lo permite con la regla de *most recent reviewable push*). Revisa PRs de otras fases cuando te lo pidan; el owner revisa siempre las rutas de CODEOWNERS.
10. **Reglas de oro**: nunca se commitea en `main`, nunca se pushea a `main`, nunca force-push a una rama compartida, y el dataset no se toca.

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
- [ ] El título del PR sigue el formato Conventional Commits (lo verifica la CI).
- [ ] La CI está en verde.
- [ ] Hay 1 revisión aprobadora de otra persona.
- [ ] El merge lo hace el owner.

## 11. Referencias

- `AGENTS.md` (sección 7) — versión resumida de esta política, cargada en cada sesión de agente.
- `.opencode/skill/git-workflow/SKILL.md` — referencia rápida para agentes.
- `.opencode/command/branch.md` — comando `/branch` para crear la rama de una fase.
- `.github/PULL_REQUEST_TEMPLATE.md` — plantilla de PR.
- `.github/CODEOWNERS` — owners por fase (revisión automática).
- `Agentes/WORKFLOWS.md` — flujo por fases y handoffs.
