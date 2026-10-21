---
name: matlab-conventions
description: Use when writing, reviewing or running MATLAB code in Bearlytics - project code style (camelCase identifiers, English code with Spanish comments), folder layout, toolbox requirements, how to run scripts headless with matlab -batch, and the review checklist before declaring code done.
license: MIT
metadata:
  project: Bearlytics
  domain: conventions
---

# Convenciones MATLAB de Bearlytics

## Stack

- **MATLAB R2026b**, ejecutado desde **VS Code** con la extensión oficial **"MATLAB" (MathWorks)**.
- Toolbox de referencia: **Signal Processing** y **Statistics and Machine Learning**. Wavelet Toolbox es opcional; si no está disponible, implementa la descomposición de forma explícita y documéntalo.
- Nada de Python, R ni dependencias externas. No hay gestor de paquetes.

## Idioma

- **Identificadores, funciones, variables, campos de tabla: inglés.**
- **Comentarios, docstrings, documentación (README/AGENTS.md) y mensajes al usuario: español.**
- Nombres de funciones y variables: `camelCase`. Nombres de carpetas: `snake_case`.

## Estructura de carpetas

```
Bearlytics/
├── EDA/Uni/          % scripts de análisis univariado
├── EDA/Multi/        % scripts de análisis multivariado
├── PreProcess/       % pipeline de features
├── Modeling/         % experimentos de modelado
├── results/          % figuras, tablas y .mat generados (los .mat no se versionan)
├── +bearlytics/      % paquete con las funciones reutilizables
│   ├── io/           % lectura de datos
│   ├── features/     % extracción de features
│   └── evaluation/   % métricas (incl. score PHM 2012)
└── 10. FEMTO Bearing/ % dataset, solo lectura, fuera de git
```

- **Un fichero por función**, con el nombre del fichero igual al nombre de la función.
- Las funciones reutilizables van en `+bearlytics/`; los scripts de ejecución en la carpeta de su fase.
- Docstring en la cabecera de cada función: propósito, entradas, salidas y supuestos.

```matlab
function features = computeRmsFeatures(signal, fs)
%COMPUTERMSFEATURES Calcula RMS, crest factor y kurtosis de una señal.
%   INPUTS:
%       signal - vector de muestras de vibración
%       fs     - frecuencia de muestreo en Hz
%   OUTPUTS:
%       features - struct con los campos rms, crestFactor y kurtosis
```

## Reglas de escritura

- `readtable` para CSV. **Nunca** `csvread`/`dlmread` (obsoletos).
- Vectorizar antes que bucles; si un bucle es inevitable, justificarlo.
- `validateattributes` para validar dimensiones de entrada.
- `rng(seed, 'twister')` explícito en todo lo que tenga aleatoriedad.
- Nada de `clear all`, `close all`, `clc` en scripts versionados.
- Sin variables globales: los datos se pasan como argumentos.
- Rutas relativas a la raíz del repo, resueltas desde la raíz del propio script:

```matlab
thisDir  = fileparts(mfilename('fullpath'));
rootDir  = fileparts(fileparts(thisDir));
datasetDir = fullfile(rootDir, '10. FEMTO Bearing');
```

Nunca uses rutas absolutas ni dependas del directorio actual de trabajo.

## Ejecución

Desde VS Code: botón de ejecución de la extensión, o `%%` como celda.
Desde línea de comandos (para automatización y CI):

```powershell
matlab -batch "addpath('PreProcess'); build_dataset"
```

- Los scripts deben poder ejecutarse **sin interacción manual**.
- Si la ejecución falla, pega el error real; no lo reescribas ni lo describas de memoria.

## Checklist antes de dar por terminado un script

1. ¿Se ejecuta de principio a fin con `matlab -batch` sin errores?
2. ¿La salida (figuras, tablas) va a `results/` con nombre descriptivo?
3. ¿Las figuras tienen título, ejes con unidades y leyenda?
4. ¿Hay docstring en todas las funciones?
5. ¿No hay NaN/Inf sin tratar ni `csvread`?
6. ¿El dataset se ha tratado como solo lectura?
7. ¿El código es reproducible (rng explícito, sin rutas absolutas)?
