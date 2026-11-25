function [modelTable, predictorNames] = prepareRulTable(featuresTable, windowSnapshots)
%PREPARERULTABLE Valida features completas y añade RUL e historia causal.
%   INPUTS: tabla del EDA/Uni y ventana entera positiva en snapshots.
%   OUTPUTS: tabla ordenada con RUL en segundos y lista de predictores.
%   SUPUESTOS: Learning_set/Full_Test_Set contienen trayectorias completas,
%   con índices 1:N y cadencia de 10 s. Rechaza Test_set, huecos, duplicados
%   y NaN/Inf. No revalida los CSV originales ni elimina picos físicos.
%   N se usa SOLO para etiquetar RUL; nunca entra en los predictores.

arguments
    featuresTable table
    windowSnapshots (1, 1) double = 31
end
validateattributes(windowSnapshots, {'double'}, {'integer', 'positive', 'finite'});

baseNames = {'rmsH', 'rmsV', 'kurtosisH', 'kurtosisV', ...
    'crestFactorH', 'crestFactorV', 'skewnessH', 'skewnessV'};
metadataNames = {'partition', 'bearing', 'condition', 'snapshotIndex', 'elapsedHours'};
requiredNames = [metadataNames, baseNames];
if isempty(featuresTable) || ...
        ~all(ismember(requiredNames, featuresTable.Properties.VariableNames))
    error('bearlytics:prepareRulTable:schema', ...
        'Se requiere una tabla no vacía con las 13 columnas de EDA/Uni.');
end
% Lista explícita: no admitir accidentalmente RUL ni otras columnas futuras.
modelTable = featuresTable(:, requiredNames);
modelTable.partition = string(modelTable.partition);
modelTable.bearing = string(modelTable.bearing);
if any(ismissing(modelTable.partition)) || any(ismissing(modelTable.bearing)) || ...
        any(strlength(modelTable.bearing) == 0) || ...
        any(~ismember(modelTable.partition, ["Learning_set", "Full_Test_Set"]))
    error('bearlytics:prepareRulTable:partition', ...
        'Solo se admiten identidades válidas y trayectorias completas; Test_set se excluye.');
end
numericNames = [metadataNames(3:5), baseNames];
% Se valida por columna para informar del primer campo corrupto.
for k = 1:numel(numericNames)
    validateattributes(modelTable.(numericNames{k}), {'numeric'}, ...
        {'real', 'finite', 'column'}, mfilename, numericNames{k});
end
if any(modelTable.rmsH <= 0 | modelTable.rmsV <= 0) || ...
        any(modelTable.kurtosisH <= 0 | modelTable.kurtosisV <= 0) || ...
        any(modelTable.crestFactorH < 1 | modelTable.crestFactorV < 1)
    error('bearlytics:prepareRulTable:featureRange', ...
        'RMS/kurtosis deben ser positivos y crest factor debe ser al menos 1.');
end
modelTable = sortrows(modelTable, {'bearing', 'snapshotIndex'});
modelTable.rulSeconds = zeros(height(modelTable), 1);
modelTable.historyCount = zeros(height(modelTable), 1);
predictorNames = baseNames;
for k = 1:numel(baseNames)
    for suffix = ["Mean", "Std", "SlopePerSecond"]
        name = char(string(baseNames{k}) + suffix);
        modelTable.(name) = zeros(height(modelTable), 1);
        predictorNames{end + 1} = name; %#ok<AGROW>
    end
end

% Cada trayectoria necesita su propia ventana: nunca se cruzan rodamientos.
bearingNames = unique(modelTable.bearing, 'stable');
dt = 10;
for b = 1:numel(bearingNames)
    rows = find(modelTable.bearing == bearingNames(b));
    current = modelTable(rows, :);
    tokens = regexp(char(bearingNames(b)), '^Bearing([1-3])_([1-9]\d*)$', 'tokens', 'once');
    n = numel(rows);
    if isempty(tokens) || numel(unique(current.partition)) ~= 1
        error('bearlytics:prepareRulTable:identity', ...
            'Nombre inválido o identidad repetida entre particiones: %s.', bearingNames(b));
    end
    if any(current.condition ~= str2double(tokens{1}))
        error('bearlytics:prepareRulTable:condition', ...
            'La condición no coincide con el nombre de %s.', bearingNames(b));
    end
    if ~isequal(double(current.snapshotIndex), (1:n)')
        error('bearlytics:prepareRulTable:sequence', ...
            '%s tiene índices duplicados, incompletos o no consecutivos desde 1.', bearingNames(b));
    end
    expectedHours = (0:n-1)' * dt / 3600;
    if any(abs(current.elapsedHours - expectedHours) > 1e-8)
        error('bearlytics:prepareRulTable:time', ...
            'La cadencia/origen temporal de %s no coincide con 10 s.', bearingNames(b));
    end
    modelTable.rulSeconds(rows) = (n - current.snapshotIndex) * dt;
    modelTable.historyCount(rows) = min((1:n)', windowSnapshots);

    % Ventana retrospectiva [w-1,0]. La pendiente es una regresión local
    % contra el índice; convertir de unidades/snapshot a unidades/segundo.
    index = (0:n-1)';
    window = [windowSnapshots - 1, 0];
    meanIndex = movmean(index, window, 'Endpoints', 'shrink');
    indexVariance = movmean(index .^ 2, window, 'Endpoints', 'shrink') - meanIndex .^ 2;
    for k = 1:numel(baseNames)
        values = double(current.(baseNames{k}));
        trailingMean = movmean(values, window, 'Endpoints', 'shrink');
        covariance = movmean(index .* values, window, 'Endpoints', 'shrink') ...
            - meanIndex .* trailingMean;
        slope = zeros(n, 1);
        valid = indexVariance > 0;
        slope(valid) = covariance(valid) ./ indexVariance(valid) / dt;
        modelTable.(char(string(baseNames{k}) + "Mean"))(rows) = trailingMean;
        modelTable.(char(string(baseNames{k}) + "Std"))(rows) = ...
            movstd(values, window, 0, 'Endpoints', 'shrink');
        modelTable.(char(string(baseNames{k}) + "SlopePerSecond"))(rows) = slope;
    end
end
if any(~isfinite(modelTable{:, predictorNames}), 'all')
    error('bearlytics:prepareRulTable:nonFinite', ...
        'Las características temporales contienen valores no finitos.');
end
end
