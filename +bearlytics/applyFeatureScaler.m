function scaledPredictors = applyFeatureScaler(predictors, scaler)
%APPLYFEATURESCALER Aplica parámetros de entrenamiento a cualquier grupo.
%   INPUTS: matriz n x p finita y scaler devuelto por fitFeatureScaler.
%   OUTPUT: matriz estandarizada con igual número y orden de columnas.
%   SUPUESTOS: nunca reajusta parámetros con validación/test.

validateattributes(predictors, {'double'}, {'2d', 'real', 'finite', 'nonempty'});
if ~isstruct(scaler) || ~isscalar(scaler) || ...
        ~all(isfield(scaler, {'center', 'scale'}))
    error('bearlytics:applyFeatureScaler:parameters', 'Faltan parámetros del escalador.');
end
p = size(predictors, 2);
validateattributes(scaler.center, {'double'}, {'size', [1, p], 'real', 'finite'});
validateattributes(scaler.scale, {'double'}, {'size', [1, p], 'real', 'finite', 'positive'});
scaledPredictors = (predictors - scaler.center) ./ scaler.scale;
if any(~isfinite(scaledPredictors), 'all')
    error('bearlytics:applyFeatureScaler:nonFinite', 'La estandarización produjo NaN/Inf.');
end
end
