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

| Fase | Carpeta | Gate de salida |
|------|---------|----------------|
| EDA univariada | `EDA/Uni/` | Al menos una figura por rodamiento/feature + observaciones escritas |
| EDA multivariada | `EDA/Multi/` | Correlaciones / PCA con interpretación sobre la degradación |
| Pre-procesamiento | `PreProcess/` | Tabla de features reproducible, split train/val/test sin leakage |
| Modelado | `Modeling/` | Baseline + modelo evaluado con score PHM 2012 y tablas comparativas |

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

- **No hacer `git commit` ni `git push` sin autorización explícita del usuario** en la conversación actual.
- Nunca hacer `git push --force`, `git reset --hard` ni reescribir historia.
- Commits estilo **Conventional Commits**: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`.
- Revisar `git status` y `git diff` antes de commitear; stagear solo lo intencionado.
- No commitear `.mat` grandes, figuras pesadas ni el dataset.

## 8. Entregables por fase

- Código en la carpeta de su fase, con un script "de entrada" fácil de ejecutar.
- Figuras y resultados numéricos en `results/` (las figuras se versionan; los `.mat` pesados no).
- Hallazgos escritos en el `README.md` de la carpeta correspondiente (una sección breve por análisis).
- Si el análisis revela algo que contradice una suposición previa, decirlo de forma explícita en el resumen final.

## 9. Referencias internas

- `Agentes/WORKFLOWS.md` — flujo end-to-end, handoffs y gates entre agentes.
- `Agentes/README.md` — roles de los agentes y cuándo invocarlos.
- Skills del proyecto: `femto-dataset`, `matlab-conventions`, `rul-features`, `phm-scoring`.
