%% EDA univariado: tabla de features, resumen y figuras de tendencia
% Recorre todos los snapshots de aceleración del dataset FEMTO, calcula las
% cuatro features univariadas en los sensores H y V, genera una figura de
% tendencia por rodamiento y feature y escribe las tablas de features y de
% resumen en results/.
%
% Ejecutar desde la raíz del repositorio con:
%     matlab -batch "run('EDA/Uni/run_eda_uni.m')"
%
% El script no modifica el dataset: solo lee los ficheros acc_*.csv.

scriptPath = mfilename('fullpath');
uniDir = fileparts(scriptPath);
edaDir = fileparts(uniDir);
repoRoot = fileparts(edaDir);

pathEntries = strsplit(path, pathsep);
if ~any(strcmpi(pathEntries, repoRoot))
    addpath(repoRoot);
end
% Se añade también la carpeta del script para que plotFeatureTrend se
% resuelva con independencia del directorio de invocación.
if ~any(strcmpi(pathEntries, uniDir))
    addpath(uniDir);
end

datasetRoot = fullfile(repoRoot, '10. FEMTO Bearing');
resultsDir = fullfile(repoRoot, 'results');

if ~isfolder(datasetRoot)
    error('runEdaUni:datasetMissing', ...
        'No se encuentra el dataset FEMTO en: %s', datasetRoot);
end
if ~isfolder(resultsDir)
    mkdir(resultsDir);
end

partitionNames = {'Learning_set', 'Full_Test_Set'};
snapshotIntervalSeconds = 10;

% Metadatos de las features: clave para nombres de fichero, etiqueta para
% las figuras y columnas H/V en la matriz de features.
featureSpecs = struct( ...
    'key', {'rms', 'kurtosis', 'crest_factor', 'skewness'}, ...
    'label', {'RMS', 'Kurtosis', 'Crest factor', 'Skewness'}, ...
    'columns', {[1, 2], [3, 4], [5, 6], [7, 8]});
sensorLabels = {'H', 'V'};

runTimer = tic;

%% Enumeración de rodamientos y snapshots
% Primera pasada: nombres de rodamiento por partición. Así se puede
% preasignar el tamaño de las celdas que se rellenan después.
bearingsPerPartition = cell(numel(partitionNames), 1);
for p = 1:numel(partitionNames)
    partitionName = partitionNames{p};
    partitionDir = fullfile(datasetRoot, partitionName);
    if ~isfolder(partitionDir)
        error('runEdaUni:partitionMissing', ...
            'No se encuentra la partición: %s', partitionDir);
    end

    entries = dir(fullfile(partitionDir, 'Bearing*'));
    entries = entries([entries.isdir]);
    if isempty(entries)
        error('runEdaUni:noBearings', ...
            'No hay rodamientos en la partición: %s', partitionDir);
    end

    bearingsPerPartition{p} = sort({entries.name});
end

nBearings = sum(cellfun(@numel, bearingsPerPartition));
bearingPartitions = cell(nBearings, 1);
bearingNames = cell(nBearings, 1);
bearingConditions = zeros(nBearings, 1);
bearingFiles = cell(nBearings, 1);
bearingCounts = zeros(nBearings, 1);

% Segunda pasada: snapshots acc_*.csv de cada rodamiento.
bearingIndex = 0;
for p = 1:numel(partitionNames)
    partitionName = partitionNames{p};
    partitionDir = fullfile(datasetRoot, partitionName);
    names = bearingsPerPartition{p};

    for b = 1:numel(names)
        bearingIndex = bearingIndex + 1;
        bearingName = names{b};

        tokens = regexp(bearingName, '^Bearing(\d+)_(\d+)$', 'tokens', 'once');
        if isempty(tokens)
            error('runEdaUni:invalidBearingName', ...
                'El nombre de rodamiento no cumple BearingX_Y: %s', bearingName);
        end
        % En BearingX_Y, X es la condición de operación (1-3) e Y el
        % número de rodamiento dentro de esa condición.
        condition = str2double(tokens{1});

        bearingDir = fullfile(partitionDir, bearingName);
        files = dir(fullfile(bearingDir, 'acc_*.csv'));
        fileNames = sort({files.name});
        if isempty(fileNames)
            error('runEdaUni:noSnapshots', ...
                'No hay snapshots acc_*.csv en: %s', bearingDir);
        end

        % Los sufijos numéricos deben ser exactamente 1:n para que el
        % índice de snapshot y el tiempo transcurrido sean fiables.
        suffixTokens = regexp(fileNames, '^acc_(\d+)\.csv$', 'tokens', 'once');
        emptySuffix = cellfun(@isempty, suffixTokens);
        if any(emptySuffix)
            badIndex = find(emptySuffix, 1, 'first');
            error('runEdaUni:invalidSnapshotName', ...
                'Nombre de snapshot no válido en %s: %s', ...
                bearingName, fileNames{badIndex});
        end
        suffixes = cellfun(@(token) str2double(token{1}), suffixTokens);
        expectedSuffixes = 1:numel(suffixes);
        if any(sort(suffixes) ~= expectedSuffixes)
            error('runEdaUni:snapshotSequence', ...
                'Los snapshots de %s no son consecutivos 1:n (rango %d-%d, %d ficheros).', ...
                bearingName, min(suffixes), max(suffixes), numel(suffixes));
        end

        bearingPartitions{bearingIndex, 1} = partitionName;
        bearingNames{bearingIndex, 1} = bearingName;
        bearingConditions(bearingIndex, 1) = condition;
        bearingFiles{bearingIndex, 1} = fileNames;
        bearingCounts(bearingIndex, 1) = numel(fileNames);
    end
end

nTotal = sum(bearingCounts);
bearingStarts = cumsum([1; bearingCounts(1:end - 1)]);

fprintf('Rodamientos encontrados: %d\n', nBearings);
fprintf('Snapshots totales: %d\n', nTotal);

%% Cálculo de features
partitionCol = strings(nTotal, 1);
bearingCol = strings(nTotal, 1);
conditionCol = zeros(nTotal, 1);
snapshotIndexCol = zeros(nTotal, 1);
elapsedHoursCol = zeros(nTotal, 1);
featureMatrix = zeros(nTotal, 8);

figureCount = 0;

for b = 1:nBearings
    bearingTimer = tic;

    rowStart = bearingStarts(b);
    count = bearingCounts(b);
    rows = rowStart:(rowStart + count - 1);
    partitionName = bearingPartitions{b};
    bearingName = bearingNames{b};
    condition = bearingConditions(b);

    partitionCol(rows) = partitionName;
    bearingCol(rows) = bearingName;
    conditionCol(rows) = condition;
    snapshotIndexCol(rows) = (1:count)';
    elapsedHoursCol(rows) = (0:(count - 1))' * snapshotIntervalSeconds / 3600;

    bearingDir = fullfile(datasetRoot, partitionName, bearingName);
    fileNames = bearingFiles{b};

    for k = 1:count
        csvPath = fullfile(bearingDir, fileNames{k});
        [signalH, signalV] = bearlytics.loadAccSnapshot(csvPath);
        featuresH = bearlytics.computeTimeFeatures(signalH);
        featuresV = bearlytics.computeTimeFeatures(signalV);

        featureMatrix(rows(k), :) = [ ...
            featuresH.rms, featuresV.rms, ...
            featuresH.kurtosis, featuresV.kurtosis, ...
            featuresH.crestFactor, featuresV.crestFactor, ...
            featuresH.skewness, featuresV.skewness];
    end

    for f = 1:numel(featureSpecs)
        figurePath = fullfile(resultsDir, sprintf( ...
            'eda_uni_%s_%s_trend.png', lower(bearingName), featureSpecs(f).key));
        plotFeatureTrend( ...
            figurePath, bearingName, partitionName, condition, ...
            elapsedHoursCol(rows), ...
            featureMatrix(rows, featureSpecs(f).columns(1)), ...
            featureMatrix(rows, featureSpecs(f).columns(2)), ...
            featureSpecs(f).label);
        figureCount = figureCount + 1;
    end

    fprintf('%-14s %-11s %5d snapshots  %7.1f s\n', ...
        partitionName, bearingName, count, toc(bearingTimer));
end

if any(~isfinite(featureMatrix(:)))
    error('runEdaUni:nonFiniteFeatures', ...
        'La matriz de features contiene valores NaN o Inf.');
end

%% Tabla de features
rmsH = featureMatrix(:, 1);
rmsV = featureMatrix(:, 2);
kurtosisH = featureMatrix(:, 3);
kurtosisV = featureMatrix(:, 4);
crestFactorH = featureMatrix(:, 5);
crestFactorV = featureMatrix(:, 6);
skewnessH = featureMatrix(:, 7);
skewnessV = featureMatrix(:, 8);

featuresTable = table( ...
    partitionCol, bearingCol, conditionCol, snapshotIndexCol, elapsedHoursCol, ...
    rmsH, rmsV, kurtosisH, kurtosisV, ...
    crestFactorH, crestFactorV, skewnessH, skewnessV, ...
    'VariableNames', { ...
    'partition', 'bearing', 'condition', 'snapshotIndex', 'elapsedHours', ...
    'rmsH', 'rmsV', 'kurtosisH', 'kurtosisV', ...
    'crestFactorH', 'crestFactorV', 'skewnessH', 'skewnessV'});

featuresPath = fullfile(resultsDir, 'eda_uni_features.csv');
writetable(featuresTable, featuresPath);
fprintf('Tabla de features: %s (%d filas)\n', featuresPath, height(featuresTable));

%% Tabla de resumen por rodamiento, feature y sensor
nSummaryRows = nBearings * numel(featureSpecs) * numel(sensorLabels);

summaryBearing = strings(nSummaryRows, 1);
summaryPartition = strings(nSummaryRows, 1);
summaryCondition = zeros(nSummaryRows, 1);
summaryFeature = strings(nSummaryRows, 1);
summarySensor = strings(nSummaryRows, 1);
summaryNSnapshots = zeros(nSummaryRows, 1);
summaryFirst = zeros(nSummaryRows, 1);
summaryLast = zeros(nSummaryRows, 1);
summaryDelta = zeros(nSummaryRows, 1);
summaryMin = zeros(nSummaryRows, 1);
summaryMax = zeros(nSummaryRows, 1);
summaryMonotonic = zeros(nSummaryRows, 1);

summaryRow = 0;
for b = 1:nBearings
    rowStart = bearingStarts(b);
    count = bearingCounts(b);
    rows = rowStart:(rowStart + count - 1);
    bearingFeatures = featureMatrix(rows, :);

    for f = 1:numel(featureSpecs)
        for s = 1:numel(sensorLabels)
            summaryRow = summaryRow + 1;
            values = bearingFeatures(:, featureSpecs(f).columns(s));

            firstValue = values(1);
            lastValue = values(end);
            deltaValue = lastValue - firstValue;

            if count == 1
                monotonicFraction = 1;
            else
                differences = diff(values);
                if deltaValue >= 0
                    monotonicFraction = mean(differences >= 0);
                else
                    monotonicFraction = mean(differences <= 0);
                end
            end

            summaryBearing(summaryRow) = bearingNames{b};
            summaryPartition(summaryRow) = bearingPartitions{b};
            summaryCondition(summaryRow) = bearingConditions(b);
            summaryFeature(summaryRow) = featureSpecs(f).key;
            summarySensor(summaryRow) = sensorLabels{s};
            summaryNSnapshots(summaryRow) = count;
            summaryFirst(summaryRow) = firstValue;
            summaryLast(summaryRow) = lastValue;
            summaryDelta(summaryRow) = deltaValue;
            summaryMin(summaryRow) = min(values);
            summaryMax(summaryRow) = max(values);
            summaryMonotonic(summaryRow) = monotonicFraction;
        end
    end
end

summaryTable = table( ...
    summaryBearing, summaryPartition, summaryCondition, ...
    summaryFeature, summarySensor, summaryNSnapshots, ...
    summaryFirst, summaryLast, summaryDelta, ...
    summaryMin, summaryMax, summaryMonotonic, ...
    'VariableNames', { ...
    'bearing', 'partition', 'condition', 'feature', 'sensor', 'nSnapshots', ...
    'first', 'last', 'delta', 'min', 'max', 'monotonicFraction'});

summaryPath = fullfile(resultsDir, 'eda_uni_summary.csv');
writetable(summaryTable, summaryPath);
fprintf('Tabla de resumen: %s (%d filas)\n', summaryPath, height(summaryTable));

%% Recuento final
totalSeconds = toc(runTimer);
fprintf('\n== EDA univariado completado ==\n');
fprintf('Snapshots procesados: %d\n', height(featuresTable));
fprintf('Rodamientos: %d\n', nBearings);
fprintf('Figuras generadas: %d\n', figureCount);
fprintf('Filas de resumen: %d\n', height(summaryTable));
fprintf('Tiempo total: %.1f s (%.2f min)\n', totalSeconds, totalSeconds / 60);
