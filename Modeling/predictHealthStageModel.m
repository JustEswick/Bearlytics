function [rulPred, healthIndex, fptByRow] = predictHealthStageModel(model, evalTable)
%PREDICTHEALTHSTAGEMODEL Predice RUL (segundos) con un modelo de fitHealthStageModel.
%   Para cada rodamiento de evalTable calcula el HI causal, detecta el FPT y
%   predice healthyRulSeconds antes del FPT y
%   max(degradationSeconds - (i - FPT) * dt, 0) desde el FPT. Cada predicción
%   solo usa snapshots hasta la fila actual.
%
%   INPUTS:
%       model     - struct de fitHealthStageModel.
%       evalTable - filas con bearing, snapshotIndex, rmsHMean y rmsVMean SIN
%                   escalar; puede mezclar rodamientos y estar desordenada.
%   OUTPUTS (alineados con las filas de evalTable):
%       rulPred     - RUL predicha en segundos.
%       healthIndex - HI de cada fila.
%       fptByRow    - snapshotIndex del FPT del rodamiento de la fila (NaN si
%                     no se detectó en la secuencia observada).

arguments
    model (1, 1) struct
    evalTable table
end
required = {'bearing', 'snapshotIndex', 'rmsHMean', 'rmsVMean'};
if ~all(ismember(required, evalTable.Properties.VariableNames))
    error('bearlytics:predictHealthStageModel:schema', ...
        'evalTable debe contener bearing, snapshotIndex, rmsHMean y rmsVMean.');
end
n = height(evalTable);
rulPred = zeros(n, 1);
healthIndex = zeros(n, 1);
fptByRow = nan(n, 1);
bearing = string(evalTable.bearing);
bearingNames = unique(bearing, 'stable');
for b = 1:numel(bearingNames)
    rows = find(bearing == bearingNames(b));
    [~, order] = sort(evalTable.snapshotIndex(rows));
    rows = rows(order);
    trace = evalTable(rows, :);
    hi = bearlytics.computeHealthIndex(trace, model.referenceSnapshots);
    fpt = detectFirstPredictingTime(hi, model.threshold, model.persistence);
    prediction = repmat(model.healthyRulSeconds, numel(rows), 1);
    if ~isnan(fpt)
        elapsed = ((fpt:numel(rows))' - fpt) * model.snapshotIntervalSeconds;
        prediction(fpt:end) = max(model.degradationSeconds - elapsed, 0);
        fptByRow(rows) = trace.snapshotIndex(fpt);
    end
    rulPred(rows) = prediction;
    healthIndex(rows) = hi;
end
end
