---
description: Entrena y evalúa modelos de RUL en Bearlytics (baselines + modelos finales) con el score asimétrico PHM 2012.
agent: bearlytics-lead
---

Fase **Modeling** de Bearlytics. Objetivo: estimar la vida útil remanente de los rodamientos y medirlo con la métrica oficial del challenge.

Alcance de esta petición: $ARGUMENTS

## Pasos

1. **Gate previo**: confirma que existe la tabla de features de `PreProcess/` y que el split por rodamiento está definido. Si no, indícalo y ofrece volver a `/preprocess`.
2. **Baseline primero**: regresión lineal/polinómica RUL ~ HI, y referencia trivial (media de RUL de train). Reporta su score PHM 2012: es la vara de medir de todo lo demás.
3. **Modelos**: regresión ridge/SVR/GBM/kNN/RF sobre el vector de features o sobre el HI; modelos sobre la trayectoria temporal del HI si el EDA lo justifica. Justifica cada elección con el EDA.
4. **Protocolo**: train para entrenar, validation para hiperparámetros, test una sola vez al final. `rng` explícita.
5. **Evaluación** (ver skill `phm-scoring`): score PHM 2012 (0-100) por rodamiento y agregado, RMSE, MAE, y trayectoria RUL real vs predicho por rodamiento.
6. **Comparación**: tabla de modelos (score, RMSE, MAE, tiempo de entrenamiento) y figura de trayectorias. Documenta el mejor modelo y el porqué.

## Gate de salida

- Tabla comparativa de modelos en `results/` y en `Modeling/README.md`.
- Figura de trayectorias RUL real vs predicho por rodamiento.
- Semilla y protocolo documentados, de modo que la ejecución se pueda reproducir.
- Todas las cifras verificadas con una ejecución real (`matlab -batch`).

## Entrega

Informa de: modelos evaluados, score de cada uno, modelo elegido y motivo, y qué habría que mejorar para el siguiente ciclo.
