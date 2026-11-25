# EDA / Multi

El análisis exploratorio multivariado estudia cómo se relacionan las características de vibración de los acelerómetros horizontal (H) y vertical (V), y cómo cambian esas relaciones a medida que avanza cada ensayo.

## Datos y método

La entrada es [la tabla de características de la EDA univariada](../../results/eda_uni_features.csv). Cada fila representa una captura de vibración con ocho características: RMS, kurtosis, factor de cresta y asimetría en H y V. La evidencia incorporada se centra en los rodamientos de `Learning_set`, con casos de las tres condiciones de operación.

- **Correlación de Spearman.** Se calcula por rodamiento sobre los rangos de las ocho características. Resume la asociación monotónica a lo largo de toda la trayectoria.
- **Diagramas de dispersión.** Se comparan RMS H con RMS V, kurtosis H con factor de cresta H y RMS H con kurtosis H. Cada punto es una captura y su color indica las horas transcurridas desde el comienzo del ensayo. El color permite ubicar cambios tardíos y picos aislados.
- **PCA exploratorio.** Se estandarizan las ocho variables con media y desviación de las capturas de `Learning_set` y se ajusta un PCA que da el mismo peso a cada captura. Los ensayos largos aportan más capturas. Para leer el signo de PC1, se orienta la componente hacia la suma de las cargas de RMS H y RMS V. Los parámetros son descriptivos. Cualquier PCA que se use como predictor debe volver a ajustarse solo con los rodamientos de entrenamiento de cada fold.

## Evidencia disponible

Las [capturas históricas de Spearman](resul/correlacion/) y de [dispersión](resul/screen/) conservan el análisis inicial. Dos capturas de RMS H frente a RMS V muestran el título `Bearing1_2`. Para identificar cada caso, se usan las figuras nuevas, cuyos títulos y nombres de archivo salen del mismo identificador utilizado para filtrar el CSV.

## Hallazgos sobre la degradación

- **Kurtosis y factor de cresta.** Los mapas reproducidos muestran una asociación positiva fuerte entre ambas características dentro de cada sensor. Las dos son sensibles a picos de vibración y pueden aportar información parcialmente redundante. En `Bearing3_1`, la dispersión muestra que los valores extremos de ambas características se concentran en unas pocas capturas tardías.
- **RMS horizontal y vertical.** Los mapas de `Bearing2_1` y `Bearing2_2` muestran una asociación más fuerte entre los canales que los de `Bearing3_1` y `Bearing3_2`. Aun así, en la dispersión de `Bearing3_2` los RMS más altos de ambos canales se concentran al final del ensayo. Un resumen de la trayectoria completa puede ocultar cambios de ese tramo.
- **RMS y kurtosis.** En `Bearing1_2` y `Bearing2_1` se observan picos de kurtosis H con RMS H relativamente bajo, mientras que varias capturas tardías con RMS H alto tienen kurtosis más moderada. El aumento de amplitud de la vibración y los picos impulsivos pueden aparecer en momentos distintos.

Estas observaciones describen las trayectorias disponibles. La comparación entre condiciones es exploratoria porque los ensayos tienen duraciones diferentes y hay dos rodamientos por condición. La redundancia de características debe validarse utilizando únicamente los rodamientos de entrenamiento de cada partición.

### PCA y comparación entre condiciones

PC1 explica el **49,66 %** de la varianza y sus cargas de mayor magnitud corresponden al factor de cresta y la kurtosis. PC2 explica el **20,35 %** y sus mayores cargas corresponden a RMS H y RMS V. La correlación de Spearman entre PC1 y el tiempo varía de **0,25 a 0,76** según el rodamiento. Por tanto, PC1 resume principalmente cambios en la impulsividad y su relación con el avance del ensayo depende del caso. [Cargas](../../results/eda_multi/pca_loadings.csv) · [Trayectorias](../../results/eda_multi/pca_pc1_trajectories.png)

La mediana de RMS H sube entre el primer y el último decil temporal en ambos rodamientos de las condiciones 1 y 2, y baja en ambos de la condición 3. Los picos tardíos de la condición 3 pueden coexistir con una mediana final más baja. Para el índice de salud se compararán cambios relativos respecto a una referencia inicial por rodamiento, disponible antes de emitir predicciones, y se evitará un umbral absoluto común entre condiciones. Cualquier parámetro compartido se ajustará solo con entrenamiento. [Resumen por rodamiento](../../results/eda_multi/bearing_summary.csv)

| Prioridad para el índice de salud | Características | Motivo |
| --- | --- | --- |
| Inicial | RMS H y RMS V | Capturan cambios de amplitud y la relación entre canales varía por caso. |
| Complementaria | Factor de cresta y kurtosis por sensor | Capturan impulsividad. Evaluar su redundancia con entrenamiento antes de seleccionar. |
| Exploratoria | Asimetría H y V y PC1 | Su utilidad como predictores queda por evaluar por rodamiento. |

## Reproducción en MATLAB

| Script | Salida |
| --- | --- |
| [generador_matriz.m](generador_matriz.m) | Mapa y matriz CSV de Spearman |
| [dispercion.m](dispercion.m) | Dispersión de RMS horizontal frente a vertical |
| [diagramdispercion.m](diagramdispercion.m) | Dispersiones de kurtosis H frente a factor de cresta H y RMS H frente a kurtosis H |

El punto de entrada [run_eda_multi.m](run_eda_multi.m) verifica la cobertura de `Learning_set` y exporta una matriz CSV de Spearman por rodamiento. Genera solo tres figuras: el mapa de `Bearing1_1`, la dispersión RMS H–V de `Bearing2_1` y las trayectorias de PC1. El PCA usa descomposición en valores singulares (`svd`) de la matriz estandarizada. El script resuelve las rutas desde su ubicación y escribe las salidas en [results/eda_multi](../../results/eda_multi/). Ejecutar desde la raíz:

```powershell
matlab -batch "addpath('EDA/Multi'); run_eda_multi"
```

## Pendientes de cierre

El cierre formal requiere integrar en `main` el código, los resultados y su interpretación mediante un PR revisado.
