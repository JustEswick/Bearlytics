# Modeling

Modelos de RUL: baselines + modelo predictivo final, con métricas tipo PHM 2012 (penalización asimétrica).

> **Estado (2026-11-24): ejecutado con MATLAB R2026b.** Baseline de media y regresión ridge
> evaluados en validación (6 folds) y, **una única vez**, en test (`Full_Test_Set`). La configuración
> (ventana 31, 32 predictores, rejilla de alpha) quedó congelada antes de mirar el test. Las cifras de
> la sección *Resultados* salen de `results/modeling_comparison.csv` y de la salida de `run_modeling`.
> Parte de `main` con el gate de EDA/Multi ya cerrado (#8).

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
| `Modeling/train_baseline_mean.m` | Baseline: 6 folds de validación y, opcional, test una vez. |
| `Modeling/fitRidgeRul.m` | Ajuste ridge de forma cerrada; el intercepto no se penaliza. |
| `Modeling/predictRidgeRul.m` | Predicción ridge (segundos), sin recorte. |
| `Modeling/train_ridge_rul.m` | Ridge: elige alpha con los 6 folds, figura de trayectorias y, opcional, test una vez. |
| `Modeling/run_modeling.m` | **Punto de entrada**: ejecuta ambos modelos y escribe la tabla comparativa. |
| `Modeling/test_modeling.m` | Pruebas con datos sintéticos y valores calculados a mano (21). |

El paquete de evaluación es `+bearlytics/+evaluation/` (en MATLAB, un subpaquete necesita su propio `+`).

## Modelo ridge

Regresión lineal con penalización L2 (Hoerl y Kennard, 1970) sobre los 32 predictores autorizados de
`predictors.csv` (8 features H/V y su media, desviación y pendiente causales en 31 snapshots), ya escalados
con el escalador de train del fold. Objetivo: `rulSeconds`.

- **Penalización:** `lambda = alpha * nTrain`, para que la misma alpha sea comparable entre folds de distinto
  tamaño y en el reajuste final.
- **Selección:** rejilla `alpha = 10^(-4:0.5:3)` (15 valores). Se elige la alpha con mayor score PHM 2012
  medio entre los 6 rodamientos de validación (en empate, la más regularizada). Resultado: **alpha = 10**.
  Rejilla completa en `results/modeling_ridge_rul_grid.csv`.
- **Modelo final:** escalador y ridge se reajustan con los 6 rodamientos de `Learning_set` a partir de
  `features_unscaled.csv` (sin tocar PreProcess) y se evalúa `Full_Test_Set` una vez.
- Sin aleatoriedad: no requiere semilla.

## Ejecución (desde la raíz del repo)

1. Generar los 6 folds de preprocesamiento (ver `PreProcess/README.md`; `results/preprocess/` no se versiona):

   ```matlab
   addpath('PreProcess');
   names = {'Bearing1_1','Bearing1_2','Bearing2_1','Bearing2_2','Bearing3_1','Bearing3_2'};
   for k = 1:numel(names), run_preprocess(names{k}, 31); end
   ```

2. Pruebas de Modeling (no necesitan los folds):

   ```matlab
   r = runtests('Modeling/test_modeling.m'); assertSuccess(r);
   ```

3. Comparación en validación (el test queda sin tocar):

   ```matlab
   addpath('Modeling'); comparison = run_modeling;
   ```

4. Evaluación única en test (ya realizada el 2026-11-24 con la configuración congelada):

   ```matlab
   addpath('Modeling'); comparison = run_modeling(31, true);
   ```

Equivalente en terminal: `matlab -batch "addpath('Modeling'); run_modeling(31, true);"`.

## Salidas

En `results/` (se reescriben al repetir la ejecución):

- `modeling_comparison.csv`: tabla comparativa (modelo × split, promedio entre rodamientos).
- `modeling_baseline_mean_rul_{validation,test,summary}.csv`: baseline por fold / rodamiento de test / resumen.
- `modeling_ridge_rul_{validation,test,summary,grid}.csv`: ridge por fold / rodamiento de test / resumen / rejilla.
- `modeling_ridge_rul_{validation,test}_predictions.csv`: RUL real y predicho por snapshot.
- `modeling_ridge_rul_{validation,test}_trajectories.png`: RUL real frente a predicho por rodamiento.

## Resultados

Promedio entre rodamientos (cada rodamiento pesa igual), protocolo LOBO-TRAJ, filas con RUL > 0.

| Modelo | Split | Rodamientos | Score PHM 2012 (0-1) | RMSE (s) | MAE (s) |
|---|---|---:|---:|---:|---:|
| Media de RUL de train | validación (6 folds) | 6 | 0,0772 | 6616 | 5823 |
| Ridge (alpha = 10) | validación (6 folds) | 6 | 0,0986 | 6349 | 5576 |
| Media de RUL de train | test (`Full_Test_Set`) | 11 | 0,1340 | 6630 | 5862 |
| Ridge (alpha = 10) | test (`Full_Test_Set`) | 11 | 0,1455 | 6708 | 5916 |

Score PHM 2012 por rodamiento de test:

| Rodamiento | Media de RUL | Ridge |
|---|---:|---:|
| Bearing1_3 | 0,203 | 0,278 |
| Bearing1_4 | 0,231 | 0,237 |
| Bearing1_5 | 0,199 | 0,213 |
| Bearing1_6 | 0,200 | 0,221 |
| Bearing1_7 | 0,207 | 0,229 |
| Bearing2_3 | 0,219 | 0,211 |
| Bearing2_4 | 0,0069 | 0,0006 |
| Bearing2_5 | 0,205 | 0,211 |
| Bearing2_6 | 0,0021 | 0,0002 |
| Bearing2_7 | ≈0 | ≈0 |
| Bearing3_3 | ≈0 | ≈0 |

Figuras: [validación](../results/modeling_ridge_rul_validation_trajectories.png) ·
[test](../results/modeling_ridge_rul_test_trajectories.png).

### Interpretación

- **Ridge mejora poco al baseline.** En test sube el score medio (0,1455 frente a 0,1340) y gana en 6 de
  11 rodamientos, pero su RMSE y MAE medios son algo **peores** (6708 frente a 6630 s). La alpha elegida es
  muy regularizada y el modelo queda cerca de la media de train.
- **Las trayectorias explican por qué.** Durante la fase sana las features son casi planas, así que la
  predicción se mantiene en ≈2,5-2,8 h sea cual sea el RUL real; solo reacciona cuando aparece la
  degradación, al final (p. ej. Bearing1_3 y Bearing1_4). Con features de dominio temporal y un modelo lineal
  no se puede saber cuánto falta mientras el rodamiento no muestra daño.
- **Fallo sistemático en rodamientos cortos.** Bearing2_4, 2_6, 2_7 y 3_3 (≤ 2,1 h) tienen score ≈0 con
  ambos modelos: se predice siempre más RUL del real y el score PHM castiga la sobreestimación con más
  fuerza (mitad de score a 5 % frente a 20 % al subestimar).
- **Validación frente a test.** El score de test es mayor que el de validación para ambos modelos; no indica
  mejor generalización. Una explicación probable (no verificada) es que `Full_Test_Set` tiene más rodamientos largos de condición 1, donde una
  constante de ≈2,5 h acierta parte del tramo final.

## Limitaciones y pendientes

- **Sin HI:** PreProcess aún no construye un Health Index. EDA/Multi recomienda usar el cambio relativo
  frente a una referencia inicial por rodamiento (RMS H/V primero) y evitar umbrales absolutos entre
  condiciones; es el siguiente paso natural, junto con una división en fase sana / degradación.
- **Test ya consumido:** cualquier modelo nuevo debe seleccionarse solo con los 6 folds; volver a usar
  `Full_Test_Set` para decidir invalida la comparación. Las cifras de test de esta tabla quedan como
  referencia de la configuración congelada.
- **Constante por snapshot:** la media de RUL pondera por snapshot, así que los rodamientos largos pesan más.
- **No es el score oficial del challenge**, que evalúa un único punto por rodamiento en el corte del test.
- **Cifras:** todas salen de `matlab -batch "addpath('Modeling'); run_modeling(31, true);"` (2026-11-24).
