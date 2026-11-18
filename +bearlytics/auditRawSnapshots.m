function auditTable = auditRawSnapshots(datasetRoot, featuresTable)
%AUDITRAWSNAPSHOTS Audita acc_*.csv en modo lectura y contrasta el EDA.
%   INPUTS: raíz local del dataset y tabla completa de EDA/Uni.
%   OUTPUT: tabla por rodamiento, solo si TODOS los snapshots son válidos.
%   SUPUESTOS: carpetas Learning_set/Full_Test_Set y cadencia de 10 s.
%   Verifica índices, dimensiones, señales finitas, features y marcas de
%   inicio de snapshot (tol. 0,1 s; admite cruce de medianoche). No imputa,
%   no filtra ni elimina picos. Los bucles permiten leer un fichero a la vez.

arguments
    datasetRoot (1, 1) string
    featuresTable table
end
if ~isfolder(datasetRoot)
    error('bearlytics:auditRawSnapshots:datasetMissing', ...
        'No existe la raíz local del dataset: %s.', datasetRoot);
end
[checkedTable, ~] = bearlytics.prepareRulTable(featuresTable, 1);
baseNames = {'rmsH', 'rmsV', 'kurtosisH', 'kurtosisV', ...
    'crestFactorH', 'crestFactorV', 'skewnessH', 'skewnessV'};
bearingNames = unique(checkedTable.bearing, 'stable');
nBearings = numel(bearingNames);
partition = strings(nBearings, 1);
nSnapshots = zeros(nBearings, 1);
maxFeatureDifference = zeros(nBearings, 1);
maxCadenceErrorSeconds = zeros(nBearings, 1);

for b = 1:nBearings
    current = checkedTable(checkedTable.bearing == bearingNames(b), :);
    partition(b) = current.partition(1);
    bearingDir = fullfile(datasetRoot, partition(b), bearingNames(b));
    files = dir(fullfile(bearingDir, 'acc_*.csv'));
    n = height(current);
    if numel(files) ~= n
        error('bearlytics:auditRawSnapshots:count', ...
            '%s: %d snapshots crudos frente a %d filas del EDA.', ...
            bearingNames(b), numel(files), n);
    end
    tokens = regexp({files.name}, '^acc_(\d+)\.csv$', 'tokens', 'once');
    if any(cellfun(@isempty, tokens))
        error('bearlytics:auditRawSnapshots:filename', 'Nombre acc_*.csv inválido.');
    end
    indices = cellfun(@(token) str2double(token{1}), tokens);
    [indices, order] = sort(indices);
    files = files(order);
    if ~isequal(indices(:), (1:n)')
        error('bearlytics:auditRawSnapshots:sequence', ...
            'La secuencia cruda de %s tiene huecos o duplicados.', bearingNames(b));
    end
    startSeconds = zeros(n, 1);
    for k = 1:n
        filePath = fullfile(bearingDir, files(k).name);
        [signalH, signalV] = bearlytics.loadAccSnapshot(filePath);
        featuresH = bearlytics.computeTimeFeatures(signalH);
        featuresV = bearlytics.computeTimeFeatures(signalV);
        actual = [featuresH.rms, featuresV.rms, featuresH.kurtosis, ...
            featuresV.kurtosis, featuresH.crestFactor, featuresV.crestFactor, ...
            featuresH.skewness, featuresV.skewness];
        expected = current{k, baseNames};
        difference = abs(actual - expected);
        if any(difference > 1e-9 + 1e-8 * abs(expected))
            error('bearlytics:auditRawSnapshots:staleFeatures', ...
                'Features crudas y EDA no coinciden: %s.', filePath);
        end
        maxFeatureDifference(b) = max(maxFeatureDifference(b), max(difference));
        % La carga anterior comprueba forma y señales. Esta lectura extra
        % valida las cuatro columnas temporales sin alterar el loader común.
        snapshot = readtable(filePath, 'ReadVariableNames', false);
        timestamps = snapshot{:, 1:4};
        validateattributes(timestamps, {'numeric'}, ...
            {'real', 'finite', 'size', [2560, 4]});
        if any(timestamps(:, 1) < 0 | timestamps(:, 1) >= 24) || ...
                any(timestamps(:, 2) < 0 | timestamps(:, 2) >= 60) || ...
                any(timestamps(:, 3) < 0 | timestamps(:, 3) >= 60) || ...
                any(timestamps(:, 4) < 0 | timestamps(:, 4) >= 1e6)
            error('bearlytics:auditRawSnapshots:timestamp', ...
                'Marca temporal fuera de rango: %s.', filePath);
        end
        startSeconds(k) = timestamps(1, :) * [3600; 60; 1; 1e-6];
    end
    increments = diff(startSeconds);
    increments(increments < -43200) = increments(increments < -43200) + 86400;
    cadenceError = abs(increments - 10);
    if any(cadenceError > 0.1)
        error('bearlytics:auditRawSnapshots:cadence', ...
            '%s no cumple cadencia de 10 s (tol. 0,1 s). Revisar tiempos antes de etiquetar.', ...
            bearingNames(b));
    end
    maxCadenceErrorSeconds(b) = max([0; cadenceError]);
    nSnapshots(b) = n;
    fprintf('Auditado %s/%s: %d snapshots.\n', partition(b), bearingNames(b), n);
end
auditTable = table(bearingNames, partition, nSnapshots, ...
    maxFeatureDifference, maxCadenceErrorSeconds, ...
    'VariableNames', {'bearing', 'partition', 'nSnapshots', ...
    'maxFeatureDifference', 'maxCadenceErrorSeconds'});
end
