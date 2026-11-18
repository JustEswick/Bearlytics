function run_preprocess(validationBearing, windowSnapshots, auditRaw)
%RUN_PREPROCESS Construye un fold preliminar de preprocesamiento en MATLAB.
%   INPUTS: rodamiento de validación, ventana y auditoría cruda opcional.
%   OUTPUTS: CSV y MAT en results/preprocess/<bearing>_w<window>/.
%   SUPUESTOS: el CSV del EDA/Uni representa trayectorias completas. Este
%   modo por defecto reutiliza features existentes: NO acredita auditoría cruda,
%   PCA/HI, cierre de EDA/Multi ni validación del gate de preprocesamiento.
%   Ejemplo desde raíz: addpath('PreProcess'); run_preprocess

arguments
    validationBearing (1, 1) string = "Bearing1_2"
    windowSnapshots (1, 1) double = 31
    auditRaw (1, 1) logical = false
end
repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(repoRoot);
sourcePath = fullfile(repoRoot, 'results', 'eda_uni_features.csv');
if ~isfile(sourcePath)
    error('runPreprocess:sourceMissing', 'Falta results/eda_uni_features.csv.');
end
featuresTable = readtable(sourcePath, 'TextType', 'string');
[modelTable, predictorNames] = bearlytics.prepareRulTable(featuresTable, windowSnapshots);
manifest = bearlytics.makeBearingSplit(modelTable, validationBearing);
if auditRaw
    datasetRoot = fullfile(repoRoot, '10. FEMTO Bearing');
    auditTable = bearlytics.auditRawSnapshots(datasetRoot, featuresTable);
else
    warning('runPreprocess:rawNotAudited', ...
        'Modo preliminar: no se comprobaron las señales crudas ni sus tiempos.');
end
[found, manifestRows] = ismember(modelTable.bearing, manifest.bearing);
assert(all(found), 'runPreprocess:split', 'Hay filas sin asignación.');
modelTable.split = manifest.split(manifestRows);
trainRows = modelTable.split == "train";
scaler = bearlytics.fitFeatureScaler(double(modelTable{trainRows, predictorNames}));
scaledTable = modelTable;
scaledTable{:, predictorNames} = bearlytics.applyFeatureScaler( ...
    double(modelTable{:, predictorNames}), scaler);

% Los metadatos y RUL se guardan para trazabilidad, pero los únicos inputs
% admisibles del modelo están enumerados en predictorNames/predictors.csv.
outputDir = fullfile(repoRoot, 'results', 'preprocess', ...
    sprintf('%s_w%d', validationBearing, windowSnapshots));
if ~isfolder(outputDir)
    mkdir(outputDir);
end
if ~auditRaw && isfile(fullfile(outputDir, 'raw_audit.csv'))
    error('runPreprocess:staleAudit', ...
        'Esta salida ya tiene una auditoría. Use auditRaw=true para regenerarla.');
end
writetable(manifest, fullfile(outputDir, 'split_manifest.csv'));
if auditRaw
    writetable(auditTable, fullfile(outputDir, 'raw_audit.csv'));
end
writetable(table(string(predictorNames(:)), 'VariableNames', {'predictor'}), ...
    fullfile(outputDir, 'predictors.csv'));
parameterTable = table(string(predictorNames(:)), scaler.center(:), ...
    scaler.scale(:), scaler.constantColumns(:), ...
    'VariableNames', {'predictor', 'center', 'scale', 'constantInTrain'});
writetable(parameterTable, fullfile(outputDir, 'scaler.csv'));
writetable(modelTable, fullfile(outputDir, 'features_unscaled.csv'));
splitNames = ["train", "validation", "test"];
for splitName = splitNames
    rows = scaledTable.split == splitName;
    writetable(scaledTable(rows, :), fullfile(outputDir, splitName + ".csv"));
    fprintf('%s: %d rodamientos, %d snapshots\n', splitName, ...
        nnz(manifest.split == splitName), nnz(rows));
end
config = struct('source', 'results/eda_uni_features.csv', ...
    'validationBearing', validationBearing, 'windowSnapshots', windowSnapshots, ...
    'snapshotIntervalSeconds', 10, 'rawSnapshotsAudited', auditRaw, ...
    'stage', 'preliminar: reutiliza features EDA/Uni');
save(fullfile(outputDir, 'preprocess_parameters.mat'), 'scaler', 'predictorNames', 'config');
fprintf('Predictores: %d. Ventana: %d snapshots (hasta %d s entre extremos).\n', ...
    numel(predictorNames), windowSnapshots, (windowSnapshots - 1) * 10);
fprintf('Salida: %s\n', outputDir);
fprintf('Auditoría cruda ejecutada: %d. Gate EDA/Multi y revisión aún pendientes.\n', auditRaw);
end
