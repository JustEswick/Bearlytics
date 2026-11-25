# PreProcess

Extracción de features, normalización, ventaneo y construcción del dataset de modelado a partir de los CSV del FEMTO dataset.

## Layout real verificado (2026-10-28)

| Partición | Rodamientos | `acc_*.csv` | `temp_*.csv` | CSV totales | Tipo |
|---|---:|---:|---:|---:|---|
| `Learning_set/` | 6 | 7.534 | 850 | 8.384 | Trayectorias completas hasta el fallo |
| `Full_Test_Set/` | 11 | 17.355 | 2.168 | 19.523 | Trayectorias completas hasta el fallo |
| `Test_set/` | 11 | 13.959 | 1.726 | 15.685 | Prefijo truncado de `Full_Test_Set` |

- Cada snapshot de aceleración es un `acc_*.csv` (`acc_00001.csv`, `acc_00002.csv`, ...).
- Cada `acc_*.csv` tiene 2.560 filas × 6 columnas, sin cabecera: 4 de marca temporal + 2 señales de aceleración (columnas 5 y 6). Muestreo a 25,6 kHz (0,1 s por snapshot).
- Los snapshots se registran cada 10 s.
- Algunos rodamientos incluyen `temp_*.csv` (4 columnas de marca temporal + temperatura; normalmente 600 filas, algunos más cortos); no son snapshots y no entran en el cálculo de RUL.
- No fijes el delimitador: hay ficheros con `,` y con `;`; `readtable` lo detecta.
- No hay `RUL_FEMTO.txt` en ninguna partición.
- `Test_set` no es independiente de `Full_Test_Set`: comparte los mismos 11 rodamientos y es un prefijo truncado de sus trayectorias.
- Para el RUL, `N` es el número de `acc_*.csv` del rodamiento en la partición usada, no el total de CSV.

### Consecuencia para el split

`Full_Test_Set` y `Test_set` no pueden usarse como validation y test independientes. La validación debe salir de rodamientos no usados en test y ningún rodamiento puede cruzar particiones. Antes de implementar el split hay que decidir qué rodamientos van a train/validation y si el test final se evalúa sobre `Full_Test_Set` (con RUL calculable) o sobre `Test_set` (sin etiqueta oficial), dejando constancia en este README.

## Primera implementación (preliminar, 2026-11-18)

Se comienza el plan solicitado por el usuario reutilizando
`results/eda_uni_features.csv`. No se altera el dataset ni se reimplementa
el cálculo de features: la auditoría opcional utiliza `loadAccSnapshot` y
`computeTimeFeatures` existentes. El informe multivariado recibido apoya
conservar ambos sensores y las ocho características originales. Aún faltan
reproducción numérica, PCA y verificación de comparabilidad entre condiciones;
el gate multivariado permanece abierto. Esta implementación no lo sustituye.

### Protocolo de separación

La primera ejecución construye un fold leave-one-bearing-out:

| Uso | Rodamientos |
|---|---|
| Train | Bearing1_1, Bearing2_1, Bearing2_2, Bearing3_1, Bearing3_2 |
| Validation | Bearing1_2 |
| Test reservado | Los 11 rodamientos de Full_Test_Set |
| Excluido | Test_set (identidades repetidas, trayectorias truncadas) |

Cambiar `validationBearing` a cada uno de los otros cinco rodamientos de
Learning_set permite completar seis folds. Cada ejecución reajusta el
escalador solo con los cinco rodamientos de entrenamiento de ese fold.
No elegir ventanas ni características mirando resultados de Full_Test_Set.
Tras elegir configuración con los seis folds, el futuro entrenamiento final
deberá reajustar el preprocesamiento con los seis Learning_set antes de
evaluar el modelo una sola vez sobre el test reservado. Ese entrenamiento
final pertenece a Modeling y no forma parte de este entregable.

### Transformaciones y controles

1. Se comprueban esquema, valores finitos, identidades, condiciones e índices
   consecutivos 1:N; se ordena por rodamiento e índice. Se rechazan huecos y
   duplicados en vez de inventar tiempos o etiquetas.
2. Se conserva el centrado ya realizado por `computeTimeFeatures`. No se
   eliminan picos, no se aplica filtrado adicional ni se imputan valores
   inválidos silenciosamente: se detiene la ejecución con error.
3. Se añaden media, desviación y pendiente lineal retrospectivas para cada
   una de las ocho características H/V: 32 predictores en total. Una ventana
   inicial de 31 snapshots abarca hasta 300 s entre extremos; es una elección
   inicial sin optimizar. Las ventanas iniciales se acortan, el primer std y
   la primera pendiente valen cero. `historyCount` registra el soporte real.
   El cálculo vive en `bearlytics.computeCausalHistory`, que no necesita RUL,
   partición ni `N`: sirve igual para trayectorias completas y para un
   rodamiento todavía en marcha (inferencia del sprint 3). Al ser
   retrospectivo, el valor de una fila no cambia al llegar snapshots nuevos;
   las pruebas lo verifican y comprueban que coincide con `prepareRulTable`.
4. RUL se calcula solo para trayectorias completas como `(N-i)*10` segundos;
   termina en cero. `N` no es predictor. Sin auditoría cruda, la cadencia y
   el endpoint se asumen a partir del CSV del EDA; no se consideran verificados
   contra los ficheros originales de esta sesión.
5. Media y std del escalador se ajustan exclusivamente con filas de train.
   Una columna constante en train conserva escala 1 y queda identificada.
   Validación/test pueden superar el rango observado; no se recortan.
6. No se ajustan PCA, selección automática ni HI en esta primera versión.
   Siguen pendientes de evidencia del EDA y validación con train.

La lista autorizada de inputs está en `predictors.csv` y `predictorNames`
dentro del MAT. **No usar todas las columnas numéricas como predictores**:
RUL, tiempos, índices, condición e identificadores son metadatos o etiquetas
en esta versión. La tabla es ancha: una fila por snapshot, H/V en columnas;
así se evita duplicar el objetivo por sensor.

### Ejecución desde la raíz

Pruebas de causalidad, etiquetas, secuencias y escalado (sin dataset crudo):

```matlab
matlab -batch "r = runtests('PreProcess/test_preprocess.m'); assertSuccess(r)"
```

Construcción preliminar con el CSV versionado:

```matlab
matlab -batch "addpath('PreProcess'); run_preprocess"
```

Construcción con auditoría de TODOS los snapshots originales en modo lectura:

```matlab
matlab -batch "addpath('PreProcess'); run_preprocess('Bearing1_2',31,true)"
```

La auditoría requiere el dataset local extraído. Contrasta número de ficheros,
índices, forma 2560x6, señales finitas, ocho features y marcas temporales de
inicio (10 s con tolerancia de 0,1 s; admite cruce de medianoche). Si detecta
irregularidades se detiene: revisar los tiempos y el etiquetado antes de
continuar. Lee un fichero a la vez; no utiliza temperatura ni Test_set.
No verifica por sí misma que el último registro sea el fallo físico: conserva
el supuesto de trayectoria completa documentado para las dos particiones.

Para otro fold/ventana, por ejemplo:

```matlab
matlab -batch "addpath('PreProcess'); run_preprocess('Bearing2_2',7)"
```

Los comandos anteriores son de terminal; en la consola MATLAB se ejecuta
solo el contenido entre comillas. Usar R2026b y las toolboxes del proyecto.

### Salidas previstas y estado de verificación

Se escribirán en `results/preprocess/<validationBearing>_w<window>/`:

- `features_unscaled.csv`: features originales, historia causal y RUL.
- `train.csv`, `validation.csv`, `test.csv`: mismas columnas, predictores escalados.
- `split_manifest.csv`: una identidad por fila con su split y conteo.
- `predictors.csv`, `scaler.csv`: esquema de inputs y parámetros de train.
- `preprocess_parameters.mat`: scaler, predictorNames y configuración; no versionar.
- `raw_audit.csv`: solo si terminó la auditoría opcional.

El nombre del fold y la ventana evitan mezclar configuraciones. Repetir una
configuración sobrescribe sus salidas; copiar evidencia de una ejecución si
se quiere conservar antes de repetirla. No se permite reemplazar una salida
auditada por modo sin auditoría. Ejecutar los seis folds requiere generar y
revisar cada uno; no se afirma que ya se hayan ejecutado.

### Evidencia de esta revisión (2026-11-24)

En MATLAB R2026b se ejecutó `runtests('PreProcess/test_preprocess.m')`:
**10 pruebas pasaron, 0 fallaron**. También se ejecutó `run_preprocess` con
la tabla versionada `results/eda_uni_features.csv`, sin auditoría de señales
crudas. La salida informó 6.663 snapshots de train (5 rodamientos), 871 de
validación (1 rodamiento) y 17.355 de test (11 rodamientos), con 32
predictores y una ventana de 31 snapshots. La corrida generó archivos bajo
`results/preprocess/Bearing1_2_w31/`; son salidas reproducibles y no forman
parte de este cambio.

La verificación cruda no se ejecutó porque el dataset no está incluido. El
gate multivariado sigue abierto por los pendientes documentados en
`EDA/Multi/README.md`; este preprocesamiento continúa siendo preliminar y no
habilita Modeling.

### Evidencia: historia causal reutilizable (2026-11-25)

La historia causal se extrajo de `prepareRulTable` a `bearlytics.computeCausalHistory`
sin cambiar el resultado. En MATLAB R2026b, `runtests('PreProcess/test_preprocess.m')`
da **14 pruebas pasadas, 0 fallidas** (10 previas y 4 nuevas: coincidencia con
`prepareRulTable`, prefijo igual a trayectoria completa, valores calculados a mano con
otra cadencia y rechazo de entradas inválidas). Se regeneraron los 6 folds con
`run_preprocess(<rodamiento>, 31)` y los 36 CSV (`features_unscaled`, `train`,
`validation`, `test`, `scaler` y `predictors` de cada fold) tienen el **mismo SHA-256**
que antes del cambio. Desde #8 el gate de EDA/Multi está cerrado; la nota anterior
sobre el gate abierto queda como histórico de esa revisión.
