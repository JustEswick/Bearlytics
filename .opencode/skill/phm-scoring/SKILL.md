---
name: phm-scoring
description: Use when evaluating or reporting RUL prediction results in Bearlytics - the IEEE PHM 2012 asymmetric scoring function for remaining useful life, plus RMSE, MAE and the evaluation protocol that avoids leakage between train/validation/test splits.
license: MIT
metadata:
  project: Bearlytics
  domain: evaluation
---

# Métrica de evaluación (IEEE PHM 2012)

## La métrica oficial

El *IEEE PHM 2012 Prognostic Challenge* evalúa la estimación del RUL con una función de puntuación **asimétrica**: sobreestimar la vida útil restante se penaliza mucho más que subestimarla (el coste de mantener un rodamiento que va a fallar es mayor que el de reemplazarlo antes de tiempo).

Con el error relativo

```
e = (RUL_pred - RUL_true) / RUL_true ,   e ∈ [-1, 1]
```

donde las predicciones se recortan al rango admisible (0 ≤ RUL_pred ≤ RUL_true), la puntuación por rodamiento es

```
score(e) = 2^(-e / 0.2)      si e ≥ 0   (sobreestimación, penalización fuerte)
score(e) = 2^(e  / 0.5)      si e < 0   (subestimación, penalización suave)
```

y la puntuación final del challenge es

```
Score_total = 100 × (1/N) × Σ score(e_i)
```

Es decir: 100 es perfecto, 50 corresponde a predecir el RUL real, 0 a predecir el extremo peor. Un modelo trivial que sobreestima mucho puntúa cerca de 0.

## Implementación MATLAB

```matlab
function score = phm2012Score(rulPred, rulTrue)
%PHM2012SCORE Puntuación asimétrica del IEEE PHM 2012 (0-100).
%   INPUTS:
%       rulPred  - vector de predicciones de RUL (segundos o snapshots)
%       rulTrue  - vector con el RUL real, misma longitud
%   OUTPUTS:
%       score    - puntuación agregada en el rango [0, 100]

    rulPred = min(max(rulPred, 0), rulTrue);      % recorte al rango admisible
    e = (rulPred - rulTrue) ./ max(rulTrue, eps);

    s = zeros(size(e));
    over = (e >= 0);
    s(over)  = 2 .^ (-e(over) / 0.2);
    s(~over) = 2 .^ ( e(~over) / 0.5);

    score = 100 * mean(s);
end
```

## Métricas complementarias

```matlab
rmse = sqrt(mean((rulPred - rulTrue).^2));
mae  = mean(abs(rulPred - rulTrue));
mape = mean(abs((rulPred - rulTrue) ./ max(rulTrue, eps)));
```

Reporta siempre RMSE y MAE junto al score: el score resume el objetivo del challenge, pero puede esconder errores grandes en algún rodamiento.

## Protocolo de evaluación

1. **Una predicción por rodamiento** para la métrica del challenge: la predicción final (último snapshot disponible).
2. Si además evalúas la **trayectoria** (predicción en cada snapshot), aplana todas las predicciones y calcula las métricas sobre ese conjunto, dejando claro qué variante se está reportando.
3. **Split por rodamiento**, nunca por snapshot: dos snapshots del mismo rodamiento son altamente correlacionados y mezclarlos filtra información.
4. Todo ajuste (escalado, imputación, selección de features, PCA del HI) se hace **solo con train**; validation sirve para elegir hiperparámetros; test se evalúa **una sola vez** al final.
5. Fijar `rng` para que los resultados sean reproducibles.

## Lectura de resultados

- Score agregado bajo ~60 indica sobreestimación sistemática: el modelo predice más vida de la que queda.
- Mirar el score **por rodamiento**, no solo el agregado: un rodamiento con score bajo puede estar bloqueando la media.
- Compara siempre contra el **baseline** (media de RUL de train, y regresión sobre HI). Un modelo solo es bueno si supera al baseline con margen.

## Referencias

- Nectoux et al., "PRONOSTIA: An Experimental Platform for Bearings Accelerated Life Test", IEEE PHM 2012.
- Saboori et al., "Remaining Useful Life Estimation of Rolling Element Bearings Using the IEEE PHM-2012 Data Challenge", MSSP 2018 (revisión del protocolo y la métrica).
