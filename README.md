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

- **17 rodamientos** sometidos a ensayos de degradación acelerada **hasta el fallo real** (fallos naturales, no inducidos artificialmente).
- **3 condiciones de operación:**

  | Condición | Velocidad | Carga |
  |-----------|-----------|-------|
  | 1 | 1800 rpm | 4000 N |
  | 2 | 1650 rpm | 4200 N |
  | 3 | 1500 rpm | 5000 N |

- **2 acelerómetros** por ensayo (horizontal y vertical), muestreo a **25,6 kHz** → 10 registros de 2560 muestras (0,1 s cada uno) por snapshot, **cada 10 segundos** hasta el fallo.

### Localización y estructura de los ficheros

El dataset vive **solo en local** en la carpeta raíz del proyecto:

```
10. FEMTO Bearing/
├── FEMTOBearingDataSet.zip   # dataset original completo (~1,1 GB)
├── Training_set.zip          # partición de entrenamiento (~134 MB)
├── Validation_Set.zip        # partición de validación (~302 MB)
└── Test_set.zip              # partición de test (~673 MB)
```

> Nota: la partición Training/Validation/Test es una **reorganización tipo Kaggle** del conjunto original del challenge (original: 6 rodamientos training conocidos + 11 test).

### Cómo usarlo

1. Descomprimir los zips necesarios dentro de `10. FEMTO Bearing/` (sin commitearlos: están en `.gitignore`).
2. Cada rodamiento (p. ej. `Bearing1_1`) contiene, por cada snapshot, un fichero CSV por sensor (acelerómetro horizontal y vertical) con la señal cruda muestreada a 25,6 kHz.
3. Los scripts de `EDA/`, `PreProcess/` y `Modeling/` apuntarán a esa ruta mediante un path relativo al root del proyecto.

### ¿Por qué está excluido de git?

Los zips ocupan entre **134 MB y 1,1 GB**, y GitHub rechaza archivos mayores de 100 MB. Por eso `10. FEMTO Bearing/` y `*.zip` están en `.gitignore`: el repo versiona solo el código. Para reproducir el proyecto, descarga el dataset de la entrada "10. FEMTO Bearing" en [data.phmsociety.org/nasa](https://data.phmsociety.org/nasa) y colócalo en la raíz.

---

## Workflow MATLAB + VS Code

Este proyecto se desarrolla en **MATLAB R2026b** editando desde **VS Code**.

### Configuración (una sola vez)

1. Instala la extensión oficial **"MATLAB" (MathWorks)** desde el marketplace de VS Code → conectable con MATLAB R2021a o superior (R2026b ✔).
2. VS Code detectará automáticamente tu instalación de MATLAB (`matlab` en PATH; si no, indicar la ruta en `Settings → MATLAB > Sign In / Install path`).
3. Opcional: crear `Bearlytics.code-workspace` con settings de indentación para `.m`.

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

1. Clonar el repositorio (la configuración viene dentro).
2. Tener MATLAB R2026b y la extensión oficial "MATLAB" de MathWorks en VS Code.
3. Descargar el dataset en `10. FEMTO Bearing/` (no se versiona, ver guía del dataset más arriba).
4. **Reiniciar opencode** tras el pull: la configuración se carga al arrancar, no en caliente.

Detalle completo en [`Agentes/README.md`](Agentes/README.md) y [`Agentes/WORKFLOWS.md`](Agentes/WORKFLOWS.md).

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
