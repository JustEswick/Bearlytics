function scaler = fitFeatureScaler(trainingPredictors)
%FITFEATURESCALER Ajusta media y desviación solo con predictores de train.
%   INPUT: matriz numérica finita n x p de entrenamiento (sin etiquetas).
%   OUTPUT: struct con center, scale y constantColumns; escala 1 si std=0.
%   SUPUESTOS: el llamador separó train por identidad de rodamiento.
%   No imputa ni recorta valores; no descarta características constantes.

validateattributes(trainingPredictors, {'double'}, ...
    {'2d', 'real', 'finite', 'nonempty'});
if size(trainingPredictors, 1) < 2
    error('bearlytics:fitFeatureScaler:tooFewRows', ...
        'Se requieren al menos dos filas de entrenamiento.');
end
scaler.center = mean(trainingPredictors, 1);
scaler.scale = std(trainingPredictors, 0, 1);
scaler.constantColumns = scaler.scale == 0;
scaler.scale(scaler.constantColumns) = 1;
if any(~isfinite([scaler.center, scaler.scale]))
    error('bearlytics:fitFeatureScaler:nonFinite', 'Estadísticos no finitos.');
end
end
