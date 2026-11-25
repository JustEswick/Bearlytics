function [historyTable, predictorNames] = computeCausalHistory(featureTable, windowSnapshots, snapshotIntervalSeconds)
%COMPUTECAUSALHISTORY Predictores de historia causal de UN rodamiento, sin RUL.
%   Para cada una de las 8 features base (RMS, kurtosis, crest factor y
%   skewness en H y V) calcula media, desviación estándar y pendiente en una
%   ventana RETROSPECTIVA de windowSnapshots snapshots: cada fila solo usa
%   esa fila y las anteriores. Por eso sirve igual para una trayectoria
%   completa (PreProcess) que para un rodamiento todavía en marcha (app de
%   inferencia): el valor de una fila no cambia al llegar snapshots nuevos.
%
%   INPUTS:
%       featureTable            - tabla de UN rodamiento, ordenada por
%                                 snapshot (fila 1 = primer snapshot), con las
%                                 columnas rmsH, rmsV, kurtosisH, kurtosisV,
%                                 crestFactorH, crestFactorV, skewnessH,
%                                 skewnessV. Otras columnas se ignoran.
%       windowSnapshots         - ventana entera positiva (por defecto 31).
%       snapshotIntervalSeconds - separación entre snapshots (por defecto 10 s).
%   OUTPUTS:
%       historyTable   - tabla con historyCount y los 32 predictores, en el
%                        orden de predictorNames, una fila por snapshot.
%       predictorNames - cellstr 1 x 32: las 8 features base seguidas de
%                        <feature>Mean, <feature>Std y <feature>SlopePerSecond.
%   SUPUESTOS: las filas son snapshots consecutivos del mismo rodamiento; la
%   función no conoce identidades ni índices, así que validarlos es tarea de
%   quien llama. Las primeras filas usan ventanas más cortas ('shrink'): la
%   primera desviación y la primera pendiente valen 0 y historyCount
%   registra el soporte real. La pendiente es la de una regresión lineal
%   local contra el índice del snapshot, convertida a unidades por segundo.

arguments
    featureTable table
    windowSnapshots (1, 1) double {mustBeInteger, mustBePositive} = 31
    snapshotIntervalSeconds (1, 1) double {mustBePositive, mustBeFinite} = 10
end
baseNames = {'rmsH', 'rmsV', 'kurtosisH', 'kurtosisV', ...
    'crestFactorH', 'crestFactorV', 'skewnessH', 'skewnessV'};
if isempty(featureTable) || ~all(ismember(baseNames, featureTable.Properties.VariableNames))
    error('bearlytics:computeCausalHistory:schema', ...
        'Se requiere una tabla no vacía con las 8 features base H/V.');
end
values = double(featureTable{:, baseNames});
validateattributes(values, {'double'}, {'2d', 'real', 'finite'}, ...
    mfilename, 'features base');

n = size(values, 1);
historyTable = table(min((1:n)', windowSnapshots), 'VariableNames', {'historyCount'});
predictorNames = baseNames;
for k = 1:numel(baseNames)
    historyTable.(baseNames{k}) = values(:, k);
end

% Ventana retrospectiva [w-1, 0]: nunca mira snapshots futuros.
index = (0:n-1)';
window = [windowSnapshots - 1, 0];
meanIndex = movmean(index, window, 'Endpoints', 'shrink');
indexVariance = movmean(index .^ 2, window, 'Endpoints', 'shrink') - meanIndex .^ 2;
valid = indexVariance > 0;
for k = 1:numel(baseNames)
    current = values(:, k);
    trailingMean = movmean(current, window, 'Endpoints', 'shrink');
    covariance = movmean(index .* current, window, 'Endpoints', 'shrink') ...
        - meanIndex .* trailingMean;
    slope = zeros(n, 1);
    slope(valid) = covariance(valid) ./ indexVariance(valid) / snapshotIntervalSeconds;
    historyTable.([baseNames{k}, 'Mean']) = trailingMean;
    historyTable.([baseNames{k}, 'Std']) = movstd(current, window, 0, 'Endpoints', 'shrink');
    historyTable.([baseNames{k}, 'SlopePerSecond']) = slope;
    predictorNames = [predictorNames, ...
        {[baseNames{k}, 'Mean'], [baseNames{k}, 'Std'], [baseNames{k}, 'SlopePerSecond']}]; %#ok<AGROW>
end
historyTable = historyTable(:, [{'historyCount'}, predictorNames]);
if any(~isfinite(historyTable{:, predictorNames}), 'all')
    error('bearlytics:computeCausalHistory:nonFinite', ...
        'Las características temporales contienen valores no finitos.');
end
end
