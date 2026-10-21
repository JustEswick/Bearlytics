# AGENTS.md — Bearlytics

Reglas del proyecto para cualquier agente de IA (opencode, Claude Code, Cursor) que trabaje en este repositorio.
Leer este archivo **completo antes de tocar código**.

## 1. Qué es este proyecto

**Bearlytics** es una plataforma de predicción de **RUL (Remaining Useful Life)** para rodamientos.
Datos: dataset **FEMTO / PRONOSTIA** (IEEE PHM 2012 Data Challenge, instituto FEMTO-ST).
Salida: modelos que estiman la vida útil remanente de un rodamiento a partir de señales de vibración.

## 2. Stack (no negociable)

- **MATLAB R2026b** como único lenguaje de ejecución. Nada de Python, R, Julia o scripts de shell que reimplementen lógica de análisis.
- **VS Code** con la extensión oficial **"MATLAB" (MathWorks)**. Ejecución por celdas (`%%`), debugging integrado.
- Ficheros: solo `.m` (scripts y funciones) y MATLAB Notebooks `.m`. Markdown solo para documentación.
- Toolbox de referencia: **Signal Processing** y **Statistics and Machine Learning**. Wavelet Toolbox es opcional (si no está, usar descomposición de filtros propia y documentarlo).
- No añadir dependencias externas, no añadir `requirements.txt` ni equivalentes, no usar `pip`.

## 3. Flujo de trabajo por fases (obligatorio)

```
EDA/Uni  ->  EDA/Multi  ->  PreProcess  ->  Modeling
```

El proyecto avanza por fases y cada una tiene un **gate**. No se escribe código de la fase siguiente hasta que la anterior esté validada y documentada.

| Fase | Carpeta | Gate de salida | PR a `main` |
|------|---------|-----------------|-------------|
| EDA univariada | `EDA/Uni/` | Al menos una figura por rodamiento/feature + observaciones escritas | Requerido antes de empezar la fase siguiente |
| EDA multivariada | `EDA/Multi/` | Correlaciones / PCA con interpretación sobre la degradación | Requerido antes de empezar la fase siguiente |
| Pre-procesamiento | `PreProcess/` | Tabla de features reproducible, split train/val/test sin leakage | Requerido antes de empezar la fase siguiente |
| Modelado | `Modeling/` | Baseline + modelo evaluado con score PHM 2012 y tablas comparativas | Requerido antes de empezar la fase siguiente |

Un agente que reciba una petición de una fase posterior debe primero verificar el gate anterior y, si no está cumplido, decirlo y proponer el trabajo de la fase previa.

## 4. Dataset: `10. FEMTO Bearing/`

- Es **solo lectura**. Nunca editar, renombrar, mover, borrar ni regenerar ficheros de esa carpeta.
- Nunca añadirlo a git. Ya está en `.gitignore` junto con `*.zip`. **No modificar el `.gitignore` para meterlo.**
- Los datos no se versionan: cada colaborador lo descarga aparte (ver `README.md`).
- Todo acceso a datos pasa por rutas relativas a la raíz del repo, resueltas con `fileparts(mfilename('fullpath'))` o `pwd`, nunca con rutas absolutas ni `C:\...`.
- Antes de asumir la estructura interna de los zips, **inspeccionarla** (ver skill `femto-dataset`). No inventar nombres de ficheros ni conteos de muestras.

## 5. Convenciones de código MATLAB

- **Identificadores, funciones y variables en inglés.** Comentarios, documentación y comunicación con el usuario en **español**.
- Una función principal por fichero; el nombre del fichero = nombre de la función.
- Funciones de proyecto en `+bearlytics/` (paquete con `+`) para lo reutilizable; scripts de ejecución en la carpeta de su fase.
- Nombres: `camelCase` en variables y funciones, `snake_case` en carpetas.
- Documentar con `%` docstring en la cabecera de cada función: propósito, entradas, salidas, supuestos.
- `readtable` para CSV; **nunca** `csvread`/`dlmread` (obsoletos).
- Vectorizar antes que bucles; si un bucle es inevitable, justificarlo.
- Validar entradas con `validateattributes` cuando la función reciba dimensiones concretas.
- Semilla aleatoria explícita (`rng(seed, 'twister')`) en todo lo que tenga aleatoriedad, para reproducibilidad.
- Prohibido `clear all`, `close all`, `clc` en scripts versionados.
- Nada de variables globales; pasar datos como argumentos.

## 6. Rigor metodológico (no negociable)

- **No inventar números.** Toda métrica, figura o resultado citado debe existir de verdad en `results/` o en la salida de una ejecución.
- Antes de afirmar un resultado, **ejecuta** el script correspondiente con `matlab -batch "..."` y muestra la salida real.
- Si MATLAB no está disponible en la sesión, dilo explícitamente y entrega el código sin afirmar resultados no verificados.
- El split train/validation/test se define **por rodamiento**, nunca por snapshot (evita fuga de información entre snapshots del mismo rodamiento).
- Toda normalización, imputación o selección de features se ajusta **solo** con el train y se aplica a val/test.
- Cita la referencia de la literatura cuando una técnica sea estándar (p. ej. score PHM 2012, HI de Xu et al.).

## 7. Git

### 7.1 Modelo de ramas: trunk-based por fases

`main` es el **trunk**: nunca se trabaja directamente sobre ella. Todo el trabajo vive en ramas cortas, y llega a `main` mediante un Pull Request revisado por una persona.

```
main (protegida)
  ├── feature/eda-uni-<tarea>        ── PR ──┐
  ├── feature/eda-multi-<tarea>       ── PR ──┤
  ├── feature/preprocess-<tarea>      ── PR ──┤──> merge por persona ──> main
  ├── feature/modeling-<tarea>        ── PR ──┤
  ├── fix/<tarea>                     ── PR ──┤
  ├── exp/<experimento>               ── PR ──┤
  ├── docs/<tarea> | chore/<tarea>    ── PR ──┘
```

**Nomenclatura de ramas** (obligatoria):

| Prefijo | Uso | Fases válidas |
|---|---|---|
| `feature/` | Trabajo nuevo de una fase del pipeline | `eda-uni`, `eda-multi`, `preprocess`, `modeling` |
| `fix/` | Corrección de un fallo | — |
| `exp/` | Experimento de modelado que no entra en `main` | — |
| `docs/` | Solo documentación | — |
| `chore/` | Configuración, CI, refactors sin cambio de comportamiento | — |

Formato: `<prefijo>/<fase>-<tarea-corta-en-kebab-case>` (p. ej. `feature/eda-uni-degradacion-inicial`).

**Ciclo de vida de una rama:**

```bash
git switch main
git pull --ff-only                 # main siempre actualizado antes de ramificar
git switch -c feature/eda-uni-degradacion-inicial
# ... trabajo ...
git add -A && git commit -m "feat(eda-uni): ... "
git pull --rebase origin main      # mantener la rama al día sin ruido en el historial
git push -u origin feature/eda-uni-degradacion-inicial
# abrir PR hacia main
```

### 7.2 Reglas obligatorias

1. **Nunca trabajes ni commitees en `main`.** Antes de cualquier commit, comprueba la rama activa con `git branch --show-current`. Si es `main`, crea primero la rama de tu fase.
2. **Una rama, un tema.** Rama corta (días, no semanas) y orientada a un único entregable.
3. **Toda rama nace de `main` actualizado**, no de otra rama de trabajo.
4. **Todo PR debe cumplir el gate de su fase** (ver tabla de la sección 3) e incluir la evidencia de ejecución real.
5. **El merge a `main` lo hace siempre una persona.** Los agentes preparan el PR y lo dejan listo; no lo mergean.
6. **Rebase sí** en tu rama de trabajo (`git pull --rebase origin main`) para mantener el historial lineal. **Nunca** rebases `main` ni ramas compartidas.
7. **Prohibido** `git push --force`, `git push -f` y `git reset --hard` sobre ramas compartidas. `--force-with-lease` solo sobre ramas personales.
8. **Commits atómicos**: un commit = un cambio con sentido. Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`) con el alcance de fase opcional (`feat(eda-uni): ...`).
9. **Antes de abrir el PR**: `git status` y `git diff` limpios, sin ficheros ajenos en el stage, sin dataset ni `.mat` pesados.
10. **Tags**: al cerrar una fase completa se etiqueta `v0.<n>.<fase>` (p. ej. `v0.1.eda-uni`). El tag lo pone una persona.
11. **No hacer `git commit` ni `git push` sin autorización explícita del usuario** en la conversación actual.
12. Nunca hacer `git push --force`, `git reset --hard` ni reescribir historia.

### 7.3 Protección de `main` en GitHub

`main` debe estar protegida (Settings → Branches → Branch rules):

- Require a pull request before merging.
- Require approvals: 1 revisor.
- Require linear history.
- Do not allow bypassing the above settings.
- Block force pushes y block deletions.

Ver el procedimiento completo en `Agentes/GIT_WORKFLOW.md`.

## 8. Entregables por fase

- Código en la carpeta de su fase, con un script "de entrada" fácil de ejecutar.
- Figuras y resultados numéricos en `results/` (las figuras se versionan; los `.mat` pesados no).
- Hallazgos escritos en el `README.md` de la carpeta correspondiente (una sección breve por análisis).
- Si el análisis revela algo que contradice una suposición previa, decirlo de forma explícita en el resumen final.

## 9. Referencias internas

- `Agentes/WORKFLOWS.md` — flujo end-to-end, handoffs y gates entre agentes.
- `Agentes/GIT_WORKFLOW.md` — política de ramas, ciclo de vida de una rama y protección de `main`.
- `Agentes/README.md` — roles de los agentes y cuándo invocarlos.
- Skills del proyecto: `femto-dataset`, `matlab-conventions`, `rul-features`, `phm-scoring`, `git-workflow`.
