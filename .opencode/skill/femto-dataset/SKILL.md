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
| Rodamientos | 17 únicos: 6 en `Learning_set` + 11 en `Full_Test_Set`; `Test_set` repite esos mismos 11 en versión truncada |
| Sensores | 2 acelerómetros por rodamiento: **horizontal** y **vertical** |
| Frecuencia de muestreo | **25 600 Hz** |
| Muestras por `acc_*.csv` | **2 560** (= 0,1 s a 25,6 kHz) |
| Ficheros por snapshot | **1 `acc_*.csv`** con las dos señales |
| Columnas de `acc_*.csv` | 6: hora, minuto, segundo, microsegundo, señal H, señal V |
| Temperatura | `temp_*.csv` aparte, solo en algunos rodamientos: 5 columnas (marca temporal + temperatura), hasta ~600 filas; no son snapshots |
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

```text
10. FEMTO Bearing/
├── FEMTOBearingDataSet.zip   # contenedor original completo (~1,1 GB)
├── Training_set.zip          # -> Learning_set/ (6 rodamientos)
├── Validation_Set.zip        # -> Full_Test_Set/ (11 rodamientos)
├── Test_set.zip              # -> Test_set/ (11 rodamientos truncados)
├── Learning_set/             # 7.534 acc + 850 temp
├── Full_Test_Set/            # 17.355 acc + 2.168 temp
└── Test_set/                 # 13.959 acc + 1.726 temp
```

Los conteos distinguen `acc_*.csv` (snapshots de aceleración, 2.560 × 6) de `temp_*.csv` (temperatura, ~600 × 5). Los totales de CSV son 8.384, 19.523 y 15.685.

`Test_set/` es un prefijo de `Full_Test_Set/`: los mismos 11 rodamientos en versión truncada, con menos snapshots. No es una partición independiente.

## Reglas de acceso

- La carpeta es **solo lectura**: no editar, renombrar, mover ni borrar ficheros de datos.
- Rutas relativas a la raíz del repo; nunca absolutas.
- Nunca añadirla a git ni relajar el `.gitignore` para hacerlo.
- No asumir nombres de ficheros ni el número de snapshots: **inspecciona** (`dir`, `unzip -l`) y documenta el layout encontrado.

## Inspección del layout (empieza siempre aquí)

```matlab
% Ejecutar desde la raíz del repo (pwd debe ser la raíz).
datasetRoot = fullfile(pwd, '10. FEMTO Bearing');
parts = dir(datasetRoot);
disp({parts.name});

bearingDir = fullfile(datasetRoot, 'Learning_set', 'Bearing1_1');
if isfolder(bearingDir)
    files = dir(fullfile(bearingDir, 'acc_*.csv'));
    fprintf('Ficheros: %d\n', numel(files));
    disp({files(1:min(10, end)).name});
end
```

Documenta en `PreProcess/README.md` el layout real que encontraste (nombres, nº de `acc_*.csv`, filas del último `acc_*.csv` y, si existe, filas del último `temp_*.csv`).

## Lectura de un snapshot en MATLAB

```matlab
% Un acc_*.csv = 2.560 muestras × 6 columnas; las señales están en 5 y 6.
T = readtable(fullfile(bearingDir, 'acc_00001.csv'), 'ReadVariableNames', false);
signalH = T{:,5};
signalV = T{:,6};
% Los temp_*.csv son temperatura (~600 × 5), no snapshots.
```

No fijes `Delimiter`: hay ficheros con `,` y con `;`, y `readtable` lo detecta.

No asumas que el último `acc_*.csv` está truncado. Verifica `height(T)` en cada fichero de aceleración; en `Full_Test_Set/Bearing1_3` el último tiene 2.560 filas. Los `temp_*.csv` sí pueden ser más cortos (p. ej. 517 filas) y no son snapshots.

## Ground truth del RUL

Con `N` = número de `acc_*.csv` hasta el fallo y el snapshot actual indexado como `i` (empezando en 1):

```matlab
dt = 10;                       % segundos entre snapshots
rulSeconds = (N - i) * dt;     % RUL en segundos
rulSteps   = N - i;            % RUL en número de snapshots
```

- Solo es válido para `Learning_set/` y `Full_Test_Set/` (trayectorias completas).
- `Test_set/` no tiene etiqueta oficial: no hay `RUL_FEMTO.txt` en esta descarga. No inventes el RUL de test; documenta la limitación y evalúa sobre `Full_Test_Set/` o define un protocolo explícito.
- No uses `Full_Test_Set/` como validación y `Test_set/` como test: comparten los mismos 11 rodamientos (fuga de identidad).
- Al construir la tabla de modelado, el RUL debe **decrecer** snapshot a snapshot dentro de cada rodamiento. Verifícalo: es un control de coherencia barato que detecta errores de indexado.

## Estructura real de esta descarga

- `Learning_set/` — 6 rodamientos completos, 7.534 `acc_*.csv` + 850 `temp_*.csv` (8.384 CSV).
- `Full_Test_Set/` — 11 rodamientos completos, 17.355 `acc_*.csv` + 2.168 `temp_*.csv` (19.523 CSV).
- `Test_set/` — prefijo truncado de los mismos 11 rodamientos, 13.959 `acc_*.csv` + 1.726 `temp_*.csv` (15.685 CSV); sin etiquetas RUL.

La asignación rodamiento → partición condiciona el split y la validez de los resultados. Documenta qué rodamientos entran en train, validation y test antes de implementar el preprocesamiento.
