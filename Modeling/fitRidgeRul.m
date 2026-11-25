function model = fitRidgeRul(trainTable, predictorNames, lambda)
%FITRIDGERUL Ajusta una regresión ridge lineal de RUL sobre predictores escalados.
%   Resuelve de forma cerrada (Hoerl y Kennard, 1970):
%       beta = (Xa' * Xa + lambda * P) \ (Xa' * y),   Xa = [1, X]
%   donde P = diag([0, 1, ..., 1]): el intercepto NO se penaliza.
%
%   INPUTS:
%       trainTable     - tabla de entrenamiento con rulSeconds y las columnas
%                        de predictorNames (ya escaladas con el scaler de train).
%       predictorNames - string con la lista autorizada de inputs
%                        (predictors.csv de PreProcess).
%       lambda         - penalización L2 (escalar >= 0). Se aplica sobre la
%                        suma de cuadrados, así que su magnitud depende del
%                        número de filas de train.
%   OUTPUT:
%       model - struct con intercept (s), coefficients (p x 1, s por unidad
%               escalada), predictorNames y lambda.
%   SUPUESTOS: los predictores ya están estandarizados con estadísticos de
%   train; esta función no escala, no recorta y no usa metadatos (bearing,
%   índice, tiempo o condición). Usa todas las filas de train, incluida la de
%   RUL = 0, igual que el baseline de media.

arguments
    trainTable table
    predictorNames (:, 1) string
    lambda (1, 1) double {mustBeNonnegative, mustBeFinite}
end
required = ["rulSeconds"; predictorNames];
if ~all(ismember(required, string(trainTable.Properties.VariableNames)))
    error('bearlytics:fitRidgeRul:schema', ...
        'trainTable debe contener rulSeconds y todos los predictores.');
end
X = double(trainTable{:, cellstr(predictorNames)});
y = double(trainTable.rulSeconds);
validateattributes(X, {'double'}, {'2d', 'real', 'finite', 'nonempty'}, ...
    'fitRidgeRul', 'predictores');
validateattributes(y, {'double'}, {'vector', 'real', 'finite', 'nonnegative'}, ...
    'fitRidgeRul', 'rulSeconds');
p = size(X, 2);
if size(X, 1) <= 1
    error('bearlytics:fitRidgeRul:tooFewRows', 'Se requieren al menos dos filas.');
end

Xa = [ones(size(X, 1), 1), X];
penalty = lambda * diag([0, ones(1, p)]);
beta = (Xa' * Xa + penalty) \ (Xa' * y);
if any(~isfinite(beta))
    error('bearlytics:fitRidgeRul:nonFinite', ...
        'El sistema ridge no tiene solución finita (pruebe un lambda mayor).');
end
model = struct('intercept', beta(1), 'coefficients', beta(2:end), ...
    'predictorNames', predictorNames, 'lambda', lambda);
end
