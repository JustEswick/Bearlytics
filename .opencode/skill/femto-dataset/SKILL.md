---
name: femto-dataset
description: Use when working with the FEMTO/PRONOSTIA bearing dataset in Bearlytics - locating files under "10. FEMTO Bearing", reading the per-bearing CSV snapshots, knowing the sampling rate, operating conditions, snapshot cadence, and how to derive the RUL ground truth. Covers "10. FEMTO Bearing", Bearing1_1, Training_set.zip, Validation_Set.zip, Test_set.zip, RUL_FEMTO, 25.6 kHz, 2560 samples, operating condition, snapshot.
license: MIT
metadata:
  project: Bearlytics
  domain: dataset
---

# Dataset FEMTO / PRONOSTIA (IEEE PHM 2012)

Conocimiento de referencia del dataset que usa Bearlytics. **Verifica siempre el layout real en disco antes de asumir nada**: la partición local es una reorganización (tipo Kaggle) del conjunto original del challenge.

## Procedencia y cita

- Instituto **FEMTO-ST** (Besançon, Francia), plataforma **PRONOSTIA**.
- **IEEE PHM 2012 Prognostic Challenge** (conferencia IEEE PHM 2012, Denver, Colorado, USA).
- Espejo de descarga: entrada "10. FEMTO Bearing" en el repositorio de datos de la PHM Society / NASA (https://data.phmsociety.org/nasa).
- Cita: P. Nectoux, R. Gouriveau, K. Medjaher, E. Ramasso, B. Morello, N. Zerhouni, C. Varnier. *PRONOSTIA: An Experimental Platform for Bearings Accelerated Life Test*. IEEE PHM 2012, Denver, CO, USA, 2012.

## Facts del dataset

| Elemento | Valor |
|---|---|
| Rodamientos | 17 en total: 6 con fallo completo (training) + 11 truncados (test) |
| Sensores | 2 acelerómetros por rodamiento: **horizontal** y **vertical** |
| Frecuencia de muestreo | **25 600 Hz** |
| Muestras por fichero | **2560** (= 0,1 s a 25,6 kHz) |
| Ficheros por snapshot | **10** por sensor (0,1 s × 10 = 1 s de señal) |
| Cadencia de snapshot | cada **10 s** hasta el fallo |
| Fallos | Reales y naturales (no se indujeron defectos) |

### Condiciones de operación

| Condición | Velocidad | Carga |
|---|---|---|
| 1 | 1800 rpm | 4000 N |
| 2 | 1650 rpm | 4200 N |
| 3 | 1500 rpm | 5000 N |

El rodamiento se codifica como `BearingX_Y`, donde `X` es la condición de operación y `Y` el número de rodamiento dentro de esa condición.

## Ubicación local

El dataset vive **solo en local** en `10. FEMTO Bearing/` (raíz del repo) y está excluido de git:

```
10. FEMTO Bearing/
├── FEMTOBearingDataSet.zip   # conjunto original completo (~1,1 GB)
├── Training_set.zip          # partición de entrenamiento (~134 MB)
├── Validation_Set.zip        # partición de validación (~302 MB)
└── Test_set.zip              # partición de test (~673 MB)
```

Rutas relativas a la raíz del repo; nunca absolutas.

## Reglas de acceso

- La carpeta es **solo lectura**: no editar, renombrar, mover ni borrar ficheros de datos.
- Nunca añadirla a git ni relajar el `.gitignore` para hacerlo.
- No asumir nombres de ficheros ni el número de snapshots: **inspecciona** (`dir`, `unzip -l`) y documenta el layout encontrado.

## Inspección del layout (empieza siempre aquí)

```matlab
% Listar particiones y rodamientos disponibles
datasetRoot = fullfile(fileparts(mfilename('fullpath')), '10. FEMTO Bearing');
parts = dir(datasetRoot);
disp({parts.name});

% Listar el contenido de un rodamiento concreto (ajusta la ruta real)
bearingDir = fullfile(datasetRoot, 'Training_set', 'Bearing1_1');
if isfolder(bearingDir)
    files = dir(fullfile(bearingDir, '*.txt'));
    fprintf('Ficheros: %d\n', numel(files));
    disp({files(1:min(10, end)).name});
end
```

Documenta en `PreProcess/README.md` el layout real que encontraste (nombres, nº de ficheros, nº de snapshots, longitud del último fichero truncado).

## Lectura de un snapshot en MATLAB

```matlab
% Un fichero = 2560 muestras de un sensor. Usa readtable (nunca csvread).
T = readtable(fullfile(bearingDir, 'Bearing1_1_1.txt'), 'ReadVariableNames', false);
signal = T{:, 1};
```

Ojo: el último fichero de cada rodamiento suele estar **truncado** (menos de 2560 muestras). Valida siempre la longitud antes de operar con ventanas o FFT.

## Ground truth del RUL

Con `N` snapshots hasta el fallo y el snapshot actual indexado como `i` (empezando en 1):

```matlab
dt = 10;                       % segundos entre snapshots
rulSeconds = (N - i) * dt;     % RUL en segundos
rulSteps   = N - i;            % RUL en número de snapshots
```

- Solo es válido para rodamientos con **fallo completo** (training).
- Para el **test truncado**, el RUL real no es observable: el challenge original lo publicaba en el fichero `RUL_FEMTO.txt`. Si tu partición local no lo incluye, dilo explícitamente y evalúa sobre validation.
- Al construir la tabla de modelado, el RUL debe **decrecer** snapshot a snapshot dentro de cada rodamiento. Verifícalo: es un control de coherencia cheap que detecta errores de indexado.

## Estructura canónica del conjunto original (referencia)

El challenge original organizaba los datos así (compruébalo contra tu partición):

- `Learning_set/` — rodamientos con fallo completo (6 usados en el challenge).
- `Full_Test_Set/` — 11 rodamientos con datos truncados, más `RUL_FEMTO.txt` con las etiquetas reales.

Tu partición local (Training / Validation / Test) es una reorganización: la asignación rodamiento → partición puede ser distinta de la del challenge. **Documenta cuál es la asignación real**, porque condiciona el split y, por tanto, la validez de los resultados.
