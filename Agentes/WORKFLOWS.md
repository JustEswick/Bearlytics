# Flujos de trabajo de Bearlytics

## Flujo end-to-end

```
        ┌──────────┐   ┌──────────┐   ┌────────────┐   ┌──────────┐
        │ EDA/Uni  │ → │ EDA/Multi│ → │ PreProcess │ → │ Modeling │
        └──────────┘   └──────────┘   └────────────┘   └──────────┘
        eda-analyst    eda-analyst    feature-engineer  rul-modeler
             ▲                                                 │
             └──────── matlab-reviewer ◄───────────────────┘
                            (revisa antes de cerrar cada fase)
```

Cada fase vive en su propia rama `feature/<fase>-<tarea>` y llega a `main` mediante un **PR revisado por una persona**. Ninguna fase empieza hasta que el gate de la anterior está mergeado en `main`.

`bearlytics-lead` orquesta: comprueba el gate de entrada de cada fase, delega en el agente correspondiente y verifica los entregables antes de pasar a la siguiente.

## Gate 1 — EDA univariado (`EDA/Uni/`)

**Entrada:** dataset descargado y legible.

**Trabajo:** evolución temporal de RMS, kurtosis, crest factor, skewness y peak-to-peak por rodamiento y sensor; delimitación de la zona degradada; espectros de inicio/medio/final; detección de artefactos.

**Salida esperada:**
- Una figura por rodamiento con las features clave, rotuladas.
- Una tabla con la feature que mejor sigue la degradación por rodamiento.
- Sección en `EDA/Uni/README.md` con los hallazgos y las cifras.

**Gate de salida:** existe una lectura clara de *cuándo* empieza a degradarse cada rodamiento y *qué* feature lo detecta antes. Sin esto, no tiene sentido construir el HI.

## Gate 2 — EDA multivariado (`EDA/Multi/`)

**Entrada:** Gate 1 cumplido.

**Trabajo:** correlación entre features, correlación entre sensores horizontal/vertical, PCA (varianza explicada y loadings), comparación entre las 3 condiciones de operación, ranking de candidatas a HI.

**Salida esperada:** figuras de correlación y de PCA, tabla de candidatas a HI y sección en `EDA/Multi/README.md`.

**Gate de salida:** está decidido si las features son comparables entre condiciones (y, si no, cómo normalizar) y qué features entran al HI.

## Gate 3 — Pre-procesamiento (`PreProcess/`)

**Entrada:** Gates 1 y 2 cumplidos.

**Trabajo:**
1. Ingesta snapshot a snapshot con `readtable`, sin cargar todo en memoria.
2. Extracción de features (time/frequency domain, envelope, WPD opcional).
3. Construcción del Health Index monótono y comparable entre rodamientos.
4. Ground truth: `RUL = (N_snapshots - i) * 10 s`; para el test truncado, etiqueta oficial si existe.
5. Tabla de modelado en `results/` (una fila por rodamiento × snapshot × sensor).
6. Split train/validation/test **por rodamiento**, con la asignación documentada.

**Salida esperada:** `PreProcess/build_dataset.m` ejecutable con `matlab -batch`, tabla sin NaN/Inf, conteo de filas y rodamientos por partición, sección en `PreProcess/README.md`.

**Gate de salida:** la tabla de modelado existe, es reproducible y no tiene fuga de información. Todo ajuste se hizo con train.

## Gate 4 — Modelado (`Modeling/`)

**Entrada:** Gate 3 cumplido.

**Trabajo:**
1. Baseline: regresión RUL ~ HI y referencia trivial (media de RUL de train).
2. Modelos justificados por el EDA.
3. Entrenamiento con train, hiperparámetros con validation, test una sola vez.
4. Evaluación con score PHM 2012, RMSE y MAE, por rodamiento y agregada.

**Salida esperada:** tabla comparativa de modelos, figuras de trayectoria RUL real vs predicho, sección en `Modeling/README.md`.

**Gate de salida:** hay un modelo elegido, con su score, sus métricas y la comparación explícita contra el baseline.

## Handoffs entre agentes

| De | A | Qué se entrega |
|---|---|---|
| `eda-analyst` | `feature-engineer` | Ranking de features, zonas de degradación detectadas y comparabilidad entre condiciones |
| `feature-engineer` | `rul-modeler` | Tabla de features, HI, ground truth, asignación de rodamientos por partición y esquema de columnas |
| `rul-modeler` | `matlab-reviewer` | Código de entrenamiento y evaluación para revisión |
| `matlab-reviewer` | (lead) | Informe con bloqueantes / importantes / sugerencias |
| `bearlytics-lead` | usuario | Resumen de fase, ficheros cambiados, pendientes y decisiones requeridas |

## Hitos transversales

- **H1 — Dataset listo**: estructura real documentada, particiones identificadas, layout por rodamiento registrado.
- **H2 — Dataset de modelado**: tabla reproducible, splits sin leakage, ground truth verificado (RUL decreciente por rodamiento).
- **H3 — Modelo evaluado**: score PHM 2012 comparable con el baseline, figuras y tabla de resultados.
- **H4 — Documentado**: `README.md` de cada fase y `README.md` raíz al día.

Cada hito se cierra con un **PR a `main`** que cumple el gate de su fase, revisado y mergeado por una persona. La política de ramas está en [`GIT_WORKFLOW.md`](GIT_WORKFLOW.md).

## Antipatrones a evitar

- Trabajar o commitear directamente en `main`.
- Saltarse de fase "para ir rápido" y descubrir en `Modeling` que el HI no es monótono.
- Normalizar con todo el dataset (incluido test) antes de partir.
- Partir por snapshot: filtra información y falsea los resultados.
- Normalizar con el valor inicial en lugar de con la media/std del train.
- Reportar métricas sin la ejecución real que las produce.
- Ajustar a los datos de test una vez que se ha visto el score de test.
- Mezclar dos fases o dos temas en la misma rama.
