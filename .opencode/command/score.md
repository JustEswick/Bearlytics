---
description: Evalúa un modelo de RUL de Bearlytics con la métrica oficial PHM 2012 y genera el informe de resultados con trayectorias y tabla por rodamiento.
agent: bearlytics-lead
---

Evaluación y reporte de resultados de un modelo de RUL de Bearlytics.

Modelo o experimento a evaluar: $ARGUMENTS

## Pasos

1. **Carga la skill `phm-scoring`** y aplica la función de score tal y como está definida (no improvises una variante).
2. **Localiza las predicciones**: tabla de predicciones por (rodamiento, snapshot) y RUL real. Si no existe, indica que hay que ejecutar `/model` primero.
3. **Calcula**:
   - Score PHM 2012 por rodamiento y agregado (0-100).
   - RMSE y MAE de la predicción de RUL.
   - Error relativo por rodamiento, con especial atención a la sobreestimación (es la penalizada).
4. **Genera figuras** en `results/`: trayectoria de RUL real vs predicho por rodamiento, y diagrama de barras del score por rodamiento.
5. **Informe**: añade una sección a `Modeling/README.md` con la tabla, las figuras y la interpretación (qué rodamientos fallan, por qué, y si el sesgo es sistemático).

## Gate de salida

- Tabla de resultados por rodamiento y agregado, exportada a `results/`.
- Figuras con título, ejes rotulados y leyenda.
- Interpretación escrita, distinguiendo claramente lo verificado de lo hipotético.

## Entrega

Informa de: score agregado, score del peor rodamiento, métricas de error y la lectura del resultado en dos o tres frases.
