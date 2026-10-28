# Bearlytics

Plataforma basada en un modelo predictivo de **RUL (Remaining Useful Life)** para estimar la vida útil remanente de rodamientos y anticipar fallos, usando el dataset de degradación acelerada **FEMTO / PRONOSTIA** (IEEE PHM 2012 Data Challenge).

## Flujo de trabajo

```
EDA (Uni + Multi)  ->  PreProcess  ->  Modeling
```

1. **EDA** — Análisis exploratorio de las señales de vibración:
   - `Uni/`: análisis univariado (RMS, kurtosis, crest factor, skewness, etc. por sensor).
   - `Multi/`: análisis multivariado (correlaciones sensor hor./vert., PCA, patrones entre condiciones de operación).
2. **PreProcess** — Extracción de features, normalización, ventaneo y construcción del dataset de modelado.
3. **Modeling** — Modelos de RUL (baselines + modelo predictivo final), evaluación con métricas tipo PHM 2012 (penalización asimétrica: sobreestimar el RUL cuesta más).

## Estructura del proyecto

```
Bearlytics/
├── EDA/
│   ├── Uni/            # EDA univariado
│   └── Multi/          # EDA multivariado
├── PreProcess/         # Pre-procesamiento y extracción de features
├── Modeling/           # Modelos de RUL
├── results/            # Figuras y tablas generadas
├── +bearlytics/        # Funciones reutilizables (paquete MATLAB)
├── AGENTS.md           # Reglas del proyecto para agentes de IA
├── opencode.json       # Configuración de agentes (permisos, agente por defecto)
├── .opencode/          # Agentes, comandos y skills de IA
├── Agentes/            # Documentación de roles, flujos y política de git
├── scripts/            # Utilidades de validación de la configuración
├── .github/            # CODEOWNERS, plantilla de PR y CI
├── 10. FEMTO Bearing/  # Dataset (solo local, excluido de git)
└── README.md
```

---

## Guía del dataset: FEMTO / PRONOSTIA

### Procedencia

Datos generados por la plataforma **PRONOSTIA** del instituto **FEMTO-ST** (Besançon, Francia) para el **IEEE PHM 2012 Prognostic Challenge**. Recogido del [NASA PHM Data Repository](https://data.phmsociety.org/nasa) (entrada "10. FEMTO Bearing").

> **Cita:** P. Nectoux, R. Gouriveau, K. Medjaher, E. Ramasso, B. Morello, N. Zerhouni, C. Varnier. *PRONOSTIA: An Experimental Platform for Bearings Accelerated Life Test*. IEEE International Conference on Prognostics and Health Management (PHM'12), Denver, CO, USA, 2012.

### En qué consiste

- **17 rodamientos únicos**: 6 con trayectoria completa en `Learning_set` y 11 en `Full_Test_Set`; `Test_set` contiene versiones truncadas de esos mismos 11 rodamientos.
- **3 condiciones de operación:**

  | Condición | Velocidad | Carga |
  |-----------|-----------|-------|
  | 1 | 1800 rpm | 4000 N |
  | 2 | 1650 rpm | 4200 N |
  | 3 | 1500 rpm | 5000 N |

- **2 acelerómetros** por ensayo (horizontal y vertical), muestreo a **25,6 kHz**: cada snapshot de aceleración es **un `acc_*.csv` de 2.560 filas × 6 columnas** (4 de marca temporal + 2 señales), es decir, 0,1 s de señal; los snapshots se registran **cada 10 s** hasta el fallo.
- **Temperatura**: no todos los rodamientos incluyen `temp_*.csv`; cuando existen, tienen 5 columnas (marca temporal + temperatura), hasta ~600 filas y aproximadamente un fichero por minuto. **No son snapshots de vibración** y no entran en el cálculo de RUL.

### Localización y estructura de los ficheros

El dataset vive **solo en local** en la carpeta raíz del proyecto:

```text
10. FEMTO Bearing/
├── FEMTOBearingDataSet.zip   # contenedor original completo (~1,1 GB)
├── Training_set.zip          # -> Learning_set/ (~134 MB)
├── Validation_Set.zip        # -> Full_Test_Set/ (~302 MB)
├── Test_set.zip              # -> Test_set/ (~673 MB)
├── Learning_set/             # 6 rodamientos · 7.534 acc + 850 temp
├── Full_Test_Set/            # 11 rodamientos · 17.355 acc + 2.168 temp
└── Test_set/                 # 11 rodamientos · 13.959 acc + 1.726 temp
```

| Carpeta extraída | Rodamientos | `acc_*.csv` | `temp_*.csv` | CSV totales | Contenido |
|---|---:|---:|---:|---:|---|
| `Learning_set/` | 6 | 7.534 | 850 | 8.384 | Trayectorias completas hasta el fallo |
| `Full_Test_Set/` | 11 | 17.355 | 2.168 | 19.523 | Trayectorias completas hasta el fallo |
| `Test_set/` | 11 | 13.959 | 1.726 | 15.685 | Prefijo truncado de `Full_Test_Set` |

> La partición Training/Validation/Test es una **reorganización tipo Kaggle** del conjunto original. `Test_set` no contiene rodamientos nuevos: es una versión truncada de las trayectorias de los mismos 11 rodamientos de `Full_Test_Set` (mismos valores, menos snapshots). No uses `Full_Test_Set` y `Test_set` como validación y test independientes.

### Cómo usarlo

1. Descomprimir dentro de `10. FEMTO Bearing/`:
   - `Training_set.zip` → `Learning_set/`
   - `Validation_Set.zip` → `Full_Test_Set/`
   - `Test_set.zip` → **solo** la carpeta `Test_set/`; el zip contiene además copias anidadas de `Training_set.zip` y `Validation_Set.zip` que no hay que extraer.
2. Cada rodamiento (p. ej. `Learning_set/Bearing1_1/`) contiene un `acc_*.csv` por snapshot de aceleración: `acc_00001.csv`, `acc_00002.csv`, etc.
3. Cada `acc_*.csv` tiene **2.560 filas × 6 columnas**, sin cabecera: las cuatro primeras columnas son la marca temporal (hora, minuto, segundo, microsegundo) y las columnas **5 y 6** son las dos señales de aceleración. Los `temp_*.csv` son registros de temperatura (~600 filas × 5 columnas) y no deben leerse como snapshots.
4. Los scripts de `EDA/`, `PreProcess/` y `Modeling/` deben resolver la ruta de forma relativa a la raíz del repo; nunca con rutas absolutas.

> **Ground truth:** no hay `RUL_FEMTO.txt` en ninguna de las tres particiones. En `Learning_set` y `Full_Test_Set` (trayectorias completas) el RUL se calcula como `(N - i) * 10 s`, donde `N` es el número de `acc_*.csv` del rodamiento e `i` va de 1 a `N`; en `Test_set` no hay etiqueta oficial, así que la evaluación final debe plantearse sobre `Full_Test_Set` o documentar explícitamente la limitación.

### ¿Por qué está excluido de git?

Los zips ocupan entre **134 MB y 1,1 GB**, y GitHub rechaza archivos mayores de 100 MB. Por eso `10. FEMTO Bearing/` y `*.zip` están en `.gitignore`: el repo versiona solo el código. Para reproducir el proyecto, descarga el dataset de la entrada "10. FEMTO Bearing" en [data.phmsociety.org/nasa](https://data.phmsociety.org/nasa) y colócalo en `10. FEMTO Bearing/`.

---

## Workflow MATLAB + VS Code

Este proyecto se desarrolla en **MATLAB R2026b** editando desde **VS Code**.

### Configuración (una sola vez)

1. Instala la extensión oficial **"MATLAB" (MathWorks)** desde el marketplace de VS Code → conectable con MATLAB R2021a o superior (R2026b ✔).
2. Asegúrate de que MATLAB R2026b tiene instaladas **Signal Processing Toolbox** y **Statistics and Machine Learning Toolbox**, requeridas por el pipeline.
3. VS Code detectará automáticamente tu instalación de MATLAB (`matlab` en PATH; si no, indicar la ruta en `Settings → MATLAB > Sign In / Install path`).
4. Opcional: crear `Bearlytics.code-workspace` con settings de indentación para `.m`.

### Cómo trabajar

- **Scripts `.m`**: ejecutar ficheros/selecciones con el botón de la extensión o `Ctrl+Enter` (requiere MATLAB abierto y registrado desde VS Code la primera vez).
- **Notebooks MATLAB**: VS Code soporta notebooks `.m` por celdas (`%% << nombre de celda`), ideales para el EDA iterativo.
- **Convención**: cada carpeta (`EDA/Uni`, `PreProcess`, ...) contendrá sus scripts/notebooks; usar `cd` o `addpath` al root del proyecto en la sesión para resolver rutas del dataset.

### Depuración

Con la extensión oficial se puede depurar (breakpoints, workspace, step-through) directamente en VS Code contra la sesión local de MATLAB.

---

## Agentes de IA (configuración compartida)

El repositorio incluye una configuración de agentes de IA **versionada**, para que todo el equipo trabaje con la misma lógica y las mismas reglas.

```
AGENTS.md          # reglas del proyecto (cargadas automáticamente en cada sesión)
opencode.json      # permisos, agente por defecto, rutas de instrucciones
.opencode/
├── agent/         # 5 agentes: lead, eda-analyst, feature-engineer, rul-modeler, matlab-reviewer
├── command/       # /eda, /preprocess, /model, /score, /branch
└── skill/         # femto-dataset, matlab-conventions, rul-features, phm-scoring, git-workflow
Agentes/
├── README.md      # roles, invocación y permisos
├── WORKFLOWS.md   # flujo EDA → PreProcess → Modeling, gates y handoffs
└── GIT_WORKFLOW.md # política de ramas, protección de main y onboarding
CLAUDE.md          # puente para Claude Code / Cursor
```

### Qué hay preparado

- **Roles por fase**: cada agente escribe únicamente en la carpeta de su fase (`EDA/`, `PreProcess/`, `Modeling/`), y el dataset es de **solo lectura** para todos.
- **Comandos de flujo**: `/eda`, `/preprocess`, `/model` y `/score` ejecutan una fase completa con su gate de salida; `/branch` crea la rama de trabajo de una fase.
- **Skills de dominio**: conocimiento del dataset FEMTO, convenciones MATLAB, catálogo de features, métrica PHM 2012 y política de git, disponibles bajo demanda.
- **Git bajo control**: los agentes comprueban la rama antes de commitear, nunca commitean en `main`, el push a `main` está bloqueado por permisos y el merge lo hace el owner.

### Cómo lo obtienen los colaboradores

1. **Clonar el repositorio** (la configuración viene dentro).
2. **Instalar opencode** (https://opencode.ai) y autenticarse con un proveedor de modelo; la configuración del repo se carga al arrancar.
3. **Instalar MATLAB R2026b** + **Signal Processing Toolbox** + **Statistics and Machine Learning Toolbox** + la extensión oficial "MATLAB" de MathWorks en VS Code.
4. **Descargar el dataset** y extraerlo **en `10. FEMTO Bearing/`** según la guía del dataset: `Learning_set/`, `Full_Test_Set/` y `Test_set/` (no se versiona). No extraigas los zips anidados de `Test_set.zip`.
5. **Reiniciar opencode** tras el pull: la configuración se carga al arrancar, no en caliente.

Detalle completo en [`Agentes/README.md`](Agentes/README.md), [`Agentes/WORKFLOWS.md`](Agentes/WORKFLOWS.md) y [`Agentes/GIT_WORKFLOW.md`](Agentes/GIT_WORKFLOW.md).

---

## Flujo de trabajo Git (colaboración)

El proyecto usa **trunk-based por fases**: `main` es el trunk y **no se trabaja directamente sobre ella**.

- **Ramas cortas por entregable**, creadas desde `main` actualizado:
  `feature/eda-uni-<tarea>` · `feature/eda-multi-<tarea>` · `feature/preprocess-<tarea>` · `feature/modeling-<tarea>`
  (además `fix/`, `exp/`, `docs/`, `chore/`).
- **Cada PR cumple el gate de su fase** e incluye la evidencia de ejecución real (salida de `matlab -batch`).
- GitHub exige **1 revisión aprobadora de otra persona** (nadie aprueba su propio PR) y la CI en verde. El **merge a `main` lo hace el owner**; los agentes preparan el PR y lo dejan listo.
- Rebase sí en tu rama de trabajo; nunca force-push ni reescritura de `main`.
- Métodos de merge: solo **squash** y **rebase**.
- Etiquetas por fase cerrada: `v0.1.eda-uni`, `v0.2.preprocess`, `v0.3.modeling`.

```bash
git switch main && git pull --ff-only
git switch -c feature/eda-uni-degradacion-inicial
# ... trabajo ...
git pull --rebase origin main
git push -u origin feature/eda-uni-degradacion-inicial
```

En opencode, el comando `/branch <fase> [tarea]` crea la rama correcta por ti. La plantilla de PR está en `.github/PULL_REQUEST_TEMPLATE.md` y la CI valida la configuración de agentes y el título del PR en cada PR.

### Protección de `main` (activa)

`main` está protegida por el **ruleset** `main trunk-based`: PR obligatorio, 1 aprobación de otra persona, CI obligatoria, force push y borrado bloqueados, métodos de merge squash/rebase y bypass del owner solo vía PR (no puede pushear a `main`). Además, `.github/CODEOWNERS` solicita automáticamente la revisión del owner en cada PR y en cada fase.

Política completa, estado real de la protección y onboarding de colaboradores: [`Agentes/GIT_WORKFLOW.md`](Agentes/GIT_WORKFLOW.md) · resumen operativo en [`AGENTS.md`](AGENTS.md) §7.
