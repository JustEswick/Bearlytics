function [perBearing, summary, constantSeconds] = meanRulBaseline(trainTable, evalTable)
%MEANRULBASELINE Baseline trivial: predice siempre la media de RUL de train.
%   INPUTS:
%       trainTable - tabla de entrenamiento con rulSeconds (todas sus filas,
%                    incluido el último snapshot de cada rodamiento).
%       evalTable  - tabla a evaluar con bearing y rulSeconds.
%   OUTPUTS:
%       perBearing      - métricas por rodamiento (ver rulMetrics, protocolo LOBO-TRAJ).
%       summary         - promedio entre rodamientos (ver rulMetrics).
%       constantSeconds - media de rulSeconds de train, en segundos.
%   SUPUESTOS: no usa predictores, índice ni tiempo transcurrido. La media es
%   por snapshot, así que los rodamientos largos pesan más en la constante.
%   Es la vara de medir mínima: cualquier modelo debe superarla.

if ~istable(trainTable) || ~istable(evalTable) || ...
        ~ismember('rulSeconds', trainTable.Properties.VariableNames) || ...
        ~all(ismember({'bearing', 'rulSeconds'}, evalTable.Properties.VariableNames))
    error('bearlytics:meanRulBaseline:schema', ...
        'Se requieren tablas con rulSeconds (train) y bearing/rulSeconds (evaluación).');
end
validateattributes(trainTable.rulSeconds, {'numeric'}, ...
    {'vector', 'real', 'finite', 'nonnegative'}, 'meanRulBaseline', 'trainTable.rulSeconds');
constantSeconds = mean(double(trainTable.rulSeconds));
rulPred = constantSeconds * ones(height(evalTable), 1);
[perBearing, summary] = bearlytics.evaluation.rulMetrics( ...
    evalTable.bearing, rulPred, evalTable.rulSeconds);
end
