# Modeling

Modelos de RUL: baselines + modelo predictivo final, con métricas tipo PHM 2012 (penalización asimétrica).

> **Estado (2026-11-19): código preliminar, sin ejecutar.** No había MATLAB en la sesión de desarrollo,
> así que ni las pruebas ni los baselines se han corrido y esta carpeta **no publica ninguna cifra**.
> Modeling no está habilitado hasta que se cierren los gates de EDA/Multi y PreProcess
> (ver `Agentes/WORKFLOWS.md`). Este código vive en una rama `exp/` apilada sobre el
> preprocesamiento preliminar y no está pensado para mergearse antes que él.

## Dependencias

- Salidas de `PreProcess/run_preprocess.m` (preprocesamiento preliminar): una carpeta
  `results/preprocess/<rodamiento>_w<ventana>/` por cada uno de los 6 rodamientos de
  `Learning_set` (los 6 folds), con `train.csv`, `validation.csv`, `test.csv`,
  `split_manifest.csv` y `predictors.csv`.
- MATLAB R2026b. Este código no necesita toolboxes adicionales ni el dataset crudo.

## Protocolo `LOBO-TRAJ`

Leave-one-bearing-out, evaluación de **trayectoria**, solo filas con **RUL > 0**.

- **Validación:** 6 folds sobre `Learning_set`; en cada uno, 5 rodamientos entrenan y 1 valida.
- **Test:** los 11 rodamientos de `Full_Test_Set`, evaluados **una sola vez** al final con el modelo
  entrenado con los 6 de `Learning_set`. `Test_set` queda excluido (misma identidad que `Full_Test_Set`).
- **Filas evaluadas:** todos los snapshots con `rulSeconds > 0`. En el último snapshot el RUL real es 0 y
  el error relativo del score no está definido; esas filas se cuentan como excluidas.
- **Agregación:** el score, RMSE y MAE se calculan por rodamiento y el resumen es el promedio **entre
  rodamientos** (cada uno pesa igual; Bearing1_1 tiene 2.803 snapshots frente a 230 de Bearing2_7).
- **No es el score oficial del challenge**, que evalúa un único punto por rodamiento en el corte del test.
  No comparar directamente con cifras publicadas.

## Métrica

Score PHM 2012 (Nectoux et al., 2012), con `Er = 100 * (RUL_real - RUL_pred) / RUL_real`:

```
A = exp(-ln(0.5) * Er / 5)    si Er <= 0   (sobreestimación)
A = exp( ln(0.5) * Er / 20)   si Er >  0   (subestimación)
score = promedio de A, en [0, 1]
```

- La escala es la oficial `[0, 1]`, no 0-100.
- Las predicciones **no se recortan**.
- **Diferencia con el skill `phm-scoring`:** ese documento usa escalas de 0,2 y 0,5 sobre el error relativo
  (mitad de score a 20 % de sobreestimación y 50 % de subestimación) y recorta `RUL_pred <= RUL_real`, lo que
  anula la penalización por sobreestimar. Aquí se usan 5 % y 20 %. Conviene confirmar las constantes con el
  artículo original y corregir el skill en un PR aparte.

## Contenido

| Fichero | Función |
|---|---|
| `+bearlytics/+evaluation/phm2012Score.m` | Score PHM 2012 sobre pares (predicho, real). |
| `+bearlytics/+evaluation/rulMetrics.m` | Score, RMSE y MAE por rodamiento y promedio (LOBO-TRAJ). |
| `Modeling/loadFold.m` | Lee y valida un fold de PreProcess (esquema, fugas, RUL, finitud). |
| `Modeling/meanRulBaseline.m` | Baseline trivial: media de RUL de train. |
| `Modeling/train_baseline_mean.m` | Entrada: 6 folds de validación y, opcional, test una vez. |
| `Modeling/test_modeling.m` | Pruebas con datos sintéticos y valores calculados a mano. |

El paquete de evaluación es `+bearlytics/+evaluation/` (en MATLAB, un subpaquete necesita su propio `+`).

## Ejecución (desde la raíz del repo)

1. Generar los 6 folds de preprocesamiento (ver `PreProcess/README.md`):

   ```matlab
   addpath('PreProcess');
   names = {'Bearing1_1','Bearing1_2','Bearing2_1','Bearing2_2','Bearing3_1','Bearing3_2'};
   for k = 1:numel(names), run_preprocess(names{k}, 31); end
   ```

2. Pruebas de Modeling (no necesitan los folds):

   ```matlab
   r = runtests('Modeling/test_modeling.m'); assertSuccess(r);
   ```

3. Baseline en validación (el test queda sin tocar):

   ```matlab
   addpath('Modeling'); results = train_baseline_mean;
   ```

4. Solo cuando la configuración esté cerrada, evaluación única en test:

   ```matlab
   addpath('Modeling'); results = train_baseline_mean(31, true);
   ```

Equivalente en terminal: `matlab -batch "addpath('Modeling'); train_baseline_mean;"`.

## Salidas

En `results/` (se reescriben al repetir la ejecución):

- `modeling_baseline_mean_rul_validation.csv`: una fila por fold, con la constante usada y las métricas.
- `modeling_baseline_mean_rul_summary.csv`: promedio entre rodamientos en validación y, si se evaluó, en test.
- `modeling_baseline_mean_rul_test.csv`: métricas por rodamiento de `Full_Test_Set` (solo con `evaluateTest = true`).

## Resultados

| Modelo | Split | Score PHM 2012 (0-1) | RMSE (s) | MAE (s) |
|---|---|---|---|---|
| Media de RUL de train | validación (6 folds) | pendiente de ejecución | pendiente | pendiente |
| Media de RUL de train | test (`Full_Test_Set`) | pendiente de ejecución | pendiente | pendiente |

## Limitaciones y pendientes

- **Sin HI:** PreProcess aún no construye un Health Index, así que el baseline `RUL ~ HI` queda diferido.
  Un sustituto razonable es una regresión ridge sobre los 32 predictores, con lambda elegido por los 6 folds
  (a evaluar además contra un modelo robusto a outliers, porque PreProcess no recorta picos).
- **Entrenamiento final con los 6 de `Learning_set`:** `makeBearingSplit` siempre aparta un rodamiento de
  validación. Para la media de RUL basta unir `train` y `validation` de cualquier fold; para modelos que usan
  el escalador habrá que ampliar PreProcess con un modo sin validación.
- **Constante por snapshot:** la media de RUL pondera por snapshot, así que los rodamientos largos pesan más.
- **Cifras:** todas deben salir de una ejecución real con `matlab -batch`; las tablas anteriores se completan
  solo con esa salida.
