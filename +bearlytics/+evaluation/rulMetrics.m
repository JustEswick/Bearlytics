function [perBearing, summary] = rulMetrics(bearing, rulPred, rulTrue)
%RULMETRICS Métricas de RUL por rodamiento bajo el protocolo LOBO-TRAJ.
%   Evalúa la trayectoria completa de cada rodamiento, pero solo las filas con
%   rulTrue > 0: en el último snapshot el RUL real es 0 y el score PHM 2012
%   no está definido. Las filas con RUL = 0 se cuentan en summary.nExcluded.
%
%   INPUTS:
%       bearing - identificador de rodamiento por fila (string, cellstr o
%                 categorical), mismo largo que los RUL.
%       rulPred - RUL predicho (segundos), vector.
%       rulTrue - RUL real (segundos), vector no negativo.
%   OUTPUTS:
%       perBearing - tabla con bearing, nEvaluated, score (0-1), rmse y mae
%                    (segundos), una fila por rodamiento.
%       summary    - struct con nBearings, nEvaluated, nExcluded y el promedio
%                    ENTRE rodamientos de score, rmse y mae (cada rodamiento
%                    pesa igual, aunque tenga más snapshots).
%   SUPUESTOS: el score de cada rodamiento es el promedio de A sobre sus
%   snapshots evaluados (ver phm2012Score). No es el score oficial del
%   challenge, que evalúa un único punto por rodamiento.

validateattributes(rulPred, {'numeric'}, {'vector', 'real', 'finite'}, ...
    'rulMetrics', 'rulPred');
validateattributes(rulTrue, {'numeric'}, {'vector', 'real', 'finite'}, ...
    'rulMetrics', 'rulTrue');
bearing = string(bearing(:));
rulPred = double(rulPred(:));
rulTrue = double(rulTrue(:));
if numel(bearing) ~= numel(rulPred) || numel(rulPred) ~= numel(rulTrue)
    error('bearlytics:rulMetrics:size', ...
        'bearing, rulPred y rulTrue deben tener la misma longitud.');
end
if any(ismissing(bearing))
    error('bearlytics:rulMetrics:identity', 'Hay filas sin identificador de rodamiento.');
end
if any(rulTrue < 0)
    error('bearlytics:rulMetrics:negativeTrue', 'rulTrue no puede ser negativo.');
end

keep = rulTrue > 0;
nExcluded = nnz(~keep);
if ~any(keep)
    error('bearlytics:rulMetrics:empty', 'No hay filas con RUL real positivo.');
end
bearing = bearing(keep);
rulPred = rulPred(keep);
rulTrue = rulTrue(keep);

names = unique(bearing, 'stable');
n = numel(names);
nEvaluated = zeros(n, 1);
score = zeros(n, 1);
rmse = zeros(n, 1);
mae = zeros(n, 1);
% Una iteración por rodamiento: cada identidad se evalúa por separado.
for b = 1:n
    rows = bearing == names(b);
    nEvaluated(b) = nnz(rows);
    score(b) = bearlytics.evaluation.phm2012Score(rulPred(rows), rulTrue(rows));
    residual = rulPred(rows) - rulTrue(rows);
    rmse(b) = sqrt(mean(residual .^ 2));
    mae(b) = mean(abs(residual));
end
perBearing = table(names, nEvaluated, score, rmse, mae, ...
    'VariableNames', {'bearing', 'nEvaluated', 'score', 'rmse', 'mae'});
summary = struct('nBearings', n, 'nEvaluated', sum(nEvaluated), ...
    'nExcluded', nExcluded, 'score', mean(score), 'rmse', mean(rmse), ...
    'mae', mean(mae));
end
