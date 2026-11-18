# EDA / Multi

## Informe del equipo

[Análisis multivariado (PDF)](Analisis_Multivariado.pdf), incorporado el
18 de noviembre de 2026. Se conserva el documento recibido sin modificar.
Contiene matrices de Spearman, diagramas de dispersión e interpretaciones de
los seis rodamientos de `Learning_set` (Bearing1_1, Bearing1_2, Bearing2_1,
Bearing2_2, Bearing3_1 y Bearing3_2).

## Decisiones para el preprocesamiento

- Conservar inicialmente RMS, kurtosis, crest factor y skewness de H y V.
  La relación H/V y RMS/kurtosis cambia entre rodamientos; no justifica
  descartar un canal ni sustituir todas las características por RMS.
- Evaluar la redundancia kurtosis/crest factor únicamente en entrenamiento,
  sin eliminar automáticamente ninguna de las dos.
- Conservar los picos de vibración: pueden ser transitorios físicos.
- Construir características temporales con presente y pasado exclusivamente.
- Separar entrenamiento, validación y test por identidad de rodamiento.

## Alcance y pendientes de validación

El PDF interpreta capturas redondeadas; no recalcula coeficientes ni ejecuta
PCA. La atribución de un diagrama de Bearing2_1 es provisional porque el
título indica Bearing1_2 (página 6). Debe verificarse contra los CSV.
La correlación no prueba causalidad ni capacidad de predecir RUL.

Quedan pendientes la reproducción en MATLAB de los coeficientes, la revisión
del rótulo, PCA y la comparabilidad entre condiciones. Por ello, incorporar
el informe **no cierra el gate multivariado**. El preprocesamiento solicitado
se prepara como desarrollo preliminar; no habilita todavía el modelado.
