function artifact = export_ridge_model(windowSnapshots, preprocessRoot)
%EXPORT_RIDGE_MODEL Exporta el modelo ridge final como artefacto versionado.
%   Reentrena el modelo final (escalador + ridge con los 6 rodamientos de
%   Learning_set) con la alpha CONGELADA que train_ridge_rul eligió por
%   validación, lo serializa con bearlytics.model.encodeModelArtifact y
%   comprueba que, al decodificarlo, reproduce las predicciones de test ya
%   publicadas. No vuelve a evaluar métricas de test ni elige nada con él.
%
%   INPUTS:
%       windowSnapshots - ventana usada en run_preprocess (por defecto 31).
%       preprocessRoot  - carpeta de salidas de PreProcess (por defecto
%                         results/preprocess).
%   OUTPUT:
%       artifact - struct exportado (ver decodeModelArtifact).
%   SALIDAS en results/:
%       modeling_ridge_rul_model.json        - artefacto (JSON UTF-8), en claro.
%       modeling_ridge_rul_model.sha256      - SHA-256 del JSON, para integridad.
%   REQUISITOS: los 6 folds de PreProcess y las salidas de
%   run_modeling(windowSnapshots, true): modeling_ridge_rul_summary.csv (con
%   fila de test) y modeling_ridge_rul_test_predictions.csv.
%   SEGURIDAD: el JSON no contiene secretos ni datos de usuarios; el cifrado y
%   la autenticación del artefacto para distribuirlo son del sprint 2
%   (bearlytics.security.sealArtifact, con el header como AAD).
%   Ejemplo desde la raíz: addpath('Modeling'); export_ridge_model;

arguments
    windowSnapshots (1, 1) double {mustBeInteger, mustBePositive} = 31
    preprocessRoot (1, 1) string = ""
end
repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(repoRoot);
resultsDir = fullfile(repoRoot, 'results');
learningBearings = ["Bearing1_1"; "Bearing1_2"; "Bearing2_1"; ...
    "Bearing2_2"; "Bearing3_1"; "Bearing3_2"];

% Configuración congelada: alpha y métricas salen de la ejecución publicada.
summaryPath = fullfile(resultsDir, 'modeling_ridge_rul_summary.csv');
predictionsPath = fullfile(resultsDir, 'modeling_ridge_rul_test_predictions.csv');
if ~isfile(summaryPath) || ~isfile(predictionsPath)
    error('export_ridge_model:resultsMissing', ...
        'Faltan resultados de ridge. Ejecute run_modeling(%d, true) primero.', windowSnapshots);
end
summary = readtable(summaryPath, 'TextType', 'string');
validationRow = summary(summary.split == "validation", :);
testRow = summary(summary.split == "test", :);
if height(validationRow) ~= 1 || height(testRow) ~= 1 || ...
        validationRow.alpha ~= testRow.alpha
    error('export_ridge_model:summary', ...
        'modeling_ridge_rul_summary.csv debe tener una fila de validación y una de test con la misma alpha.');
end
alpha = validationRow.alpha;

% Modelo final: igual que la evaluación única de test de train_ridge_rul.
fold = loadFold(learningBearings(1), windowSnapshots, preprocessRoot);
predictorNames = fold.predictorNames;
[learningTable, ~, scaler] = finalTrainingTables(fold, predictorNames, learningBearings);
lambda = alpha * height(learningTable);
model = fitRidgeRul(learningTable, predictorNames, lambda);

artifact = struct();
artifact.header = struct('schemaVersion', 1, 'modelId', "bearlytics-ridge-rul", ...
    'modelVersion', "1.0.0", 'modelType', "ridge_rul");
artifact.predictorNames = predictorNames;
artifact.windowSnapshots = windowSnapshots;
artifact.scaler = struct('center', scaler.center, 'scale', scaler.scale);
artifact.model = struct('intercept', model.intercept, ...
    'coefficients', model.coefficients, 'alpha', alpha, 'lambda', lambda, ...
    'target', "rulSeconds", 'units', "s");
artifact.training = struct('partition', "Learning_set", ...
    'bearings', learningBearings, 'nRows', height(learningTable), ...
    'protocol', "LOBO-TRAJ", 'sourceCommit', sourceCommit(repoRoot), ...
    'createdUtc', string(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z''')));
artifact.metrics = struct( ...
    'validation', metricStruct(validationRow), 'test', metricStruct(testRow), ...
    'scoreName', "PHM 2012 (0-1, Nectoux et al., 2012)");

[payload, ~] = bearlytics.model.encodeModelArtifact(artifact);

% Verificación: el artefacto decodificado reproduce las predicciones publicadas.
decoded = bearlytics.model.decodeModelArtifact(payload);
unscaled = readtable(fullfile(fold.directory, "features_unscaled.csv"), 'TextType', 'string');
testUnscaled = sortrows(unscaled(unscaled.partition == "Full_Test_Set", :), ...
    {'bearing', 'snapshotIndex'});
published = sortrows(readtable(predictionsPath, 'TextType', 'string'), ...
    {'bearing', 'snapshotIndex'});
if height(published) ~= height(testUnscaled) || ...
        any(published.bearing ~= testUnscaled.bearing) || ...
        any(published.snapshotIndex ~= testUnscaled.snapshotIndex)
    error('export_ridge_model:predictionsMismatch', ...
        'Las predicciones publicadas no corresponden a las filas de Full_Test_Set.');
end
rulPred = bearlytics.model.predictRulFromArtifact(decoded, testUnscaled);
maxDifference = max(abs(rulPred - published.rulPredSeconds));
tolerance = 1e-6;
if maxDifference > tolerance
    error('export_ridge_model:reproduction', ...
        'El artefacto no reproduce las predicciones publicadas (máx. %.3g s).', maxDifference);
end

jsonPath = fullfile(resultsDir, 'modeling_ridge_rul_model.json');
fileId = fopen(jsonPath, 'w');
if fileId < 0
    error('export_ridge_model:write', 'No se pudo escribir %s.', jsonPath);
end
closeFile = onCleanup(@() fclose(fileId));
fwrite(fileId, payload, 'uint8');
clear closeFile
digest = sha256Hex(payload);
writelines(digest + "  modeling_ridge_rul_model.json", ...
    fullfile(resultsDir, 'modeling_ridge_rul_model.sha256'));

fprintf('Artefacto %s v%s (alpha = %g, %d predictores, %d filas de train).\n', ...
    artifact.header.modelId, artifact.header.modelVersion, alpha, ...
    numel(predictorNames), height(learningTable));
fprintf('Reproduce las %d predicciones de test publicadas: máx. diferencia %.3g s (tolerancia %g s).\n', ...
    height(published), maxDifference, tolerance);
fprintf('Commit de origen: %s\n', artifact.training.sourceCommit);
fprintf('Bytes: %d | SHA-256: %s\n', numel(payload), digest);
end

function metrics = metricStruct(row)
metrics = struct('nBearings', row.nBearings, 'nEvaluated', row.nEvaluated, ...
    'score', row.score, 'rmseSeconds', row.rmse, 'maeSeconds', row.mae);
end

function commit = sourceCommit(repoRoot)
% Commit del código que generó el artefacto; "unknown" si git no está disponible.
[status, output] = system(sprintf('git -C "%s" rev-parse HEAD', repoRoot));
commit = "unknown";
if status == 0
    commit = strtrim(string(output));
end
end

function digest = sha256Hex(bytes)
% SHA-256 con el proveedor criptográfico de Java incluido en MATLAB.
engine = java.security.MessageDigest.getInstance('SHA-256');
hashBytes = typecast(engine.digest(typecast(bytes(:), 'int8')), 'uint8');
digest = string(lower(reshape(dec2hex(hashBytes, 2)', 1, [])));
end
