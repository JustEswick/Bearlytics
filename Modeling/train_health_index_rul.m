function results = train_health_index_rul(windowSnapshots, evaluateTest, preprocessRoot)
%TRAIN_HEALTH_INDEX_RUL Modelo de RUL por etapas de salud con HI relativo (LOBO-TRAJ).
%   1) Selección: rejilla de threshold x persistence x quantile evaluada con
%      los 6 folds leave-one-bearing-out de Learning_set. Se elige la
%      combinación con mayor score PHM 2012 medio entre rodamientos de
%      validación. Full_Test_Set no interviene.
%   2) Opcional (evaluateTest = true): ajusta con los 6 rodamientos de
%      Learning_set y evalúa UNA vez los 11 de Full_Test_Set.
%
%   INPUTS:
%       windowSnapshots - ventana usada en run_preprocess (por defecto 31).
%       evaluateTest    - false por defecto.
%       preprocessRoot  - carpeta de salidas de PreProcess (por defecto
%                         results/preprocess).
%   OUTPUT:
%       results - struct con grid, params elegidos, validation (6 filas),
%                 validationSummary, test (11 filas o vacía) y testSummary.
%   SALIDAS en results/ (se reescriben al repetir):
%       modeling_hi_stage_grid.csv, modeling_hi_stage_validation.csv,
%       modeling_hi_stage_validation_predictions.csv,
%       modeling_hi_stage_validation_trajectories.png,
%       modeling_hi_stage_validation_health_index.png,
%       modeling_hi_stage_summary.csv y, si se evalúa el test,
%       modeling_hi_stage_test.csv, modeling_hi_stage_test_predictions.csv y
%       modeling_hi_stage_test_trajectories.png.
%   SUPUESTOS: usa rmsHMean/rmsVMean SIN escalar de features_unscaled.csv
%   (el HI es relativo a cada rodamiento y no necesita escalador). La
%   referencia inicial se fija en 60 snapshots (10 min) y no se ajusta. Sin
%   aleatoriedad: no requiere rng.
%   Ejemplo desde la raíz: addpath('Modeling'); train_health_index_rul;

arguments
    windowSnapshots (1, 1) double {mustBeInteger, mustBePositive} = 31
    evaluateTest (1, 1) logical = false
    preprocessRoot (1, 1) string = ""
end
repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(repoRoot);
outputDir = fullfile(repoRoot, 'results');

protocol = "LOBO-TRAJ";
modelName = "hi_stage_rul";
learningBearings = ["Bearing1_1"; "Bearing1_2"; "Bearing2_1"; ...
    "Bearing2_2"; "Bearing3_1"; "Bearing3_2"];
[thresholds, persistences, quantiles] = ndgrid([0.3, 0.5, 0.7, 1.0], [1, 30, 60], [0.1, 0.25, 0.5]);
candidates = [thresholds(:), persistences(:), quantiles(:)];
baseParams = struct('referenceSnapshots', 60, 'snapshotIntervalSeconds', 10);

% Cada fold aporta sus filas sin escalar y su asignación train/validation.
nFold = numel(learningBearings);
folds = cell(nFold, 1);
for k = 1:nFold
    fold = loadFold(learningBearings(k), windowSnapshots, preprocessRoot);
    unscaled = readtable(fullfile(fold.directory, "features_unscaled.csv"), 'TextType', 'string');
    folds{k} = struct('train', unscaled(unscaled.split == "train", :), ...
        'validation', unscaled(unscaled.split == "validation", :), ...
        'learning', unscaled(unscaled.partition == "Learning_set", :), ...
        'test', unscaled(unscaled.partition == "Full_Test_Set", :));
    if ~isequal(unique(folds{k}.validation.bearing), learningBearings(k))
        error('train_health_index_rul:validationIdentity', ...
            'El fold de %s no valida exactamente ese rodamiento.', learningBearings(k));
    end
end

nCandidate = size(candidates, 1);
scores = zeros(nCandidate, nFold);
rmses = zeros(nCandidate, nFold);
maes = zeros(nCandidate, nFold);
for c = 1:nCandidate
    params = candidateParams(baseParams, candidates(c, :));
    for k = 1:nFold
        model = fitHealthStageModel(folds{k}.train, params);
        rulPred = predictHealthStageModel(model, folds{k}.validation);
        perBearing = bearlytics.evaluation.rulMetrics(folds{k}.validation.bearing, ...
            rulPred, folds{k}.validation.rulSeconds);
        scores(c, k) = perBearing.score;
        rmses(c, k) = perBearing.rmse;
        maes(c, k) = perBearing.mae;
    end
end
grid = table(candidates(:, 1), candidates(:, 2), candidates(:, 3), ...
    mean(scores, 2), mean(rmses, 2), mean(maes, 2), ...
    'VariableNames', {'threshold', 'persistence', 'quantile', 'meanScore', 'meanRmse', 'meanMae'});
grid = sortrows(grid, 'meanScore', 'descend');
writetable(grid, fullfile(outputDir, 'modeling_hi_stage_grid.csv'));
params = candidateParams(baseParams, grid{1, {'threshold', 'persistence', 'quantile'}});

% Métricas y predicciones fuera de fold con la combinación elegida.
rows = cell(nFold, 1);
predictionRows = cell(nFold, 1);
for k = 1:nFold
    model = fitHealthStageModel(folds{k}.train, params);
    validationTable = sortrows(folds{k}.validation, 'snapshotIndex');
    [rulPred, healthIndex, fpt] = predictHealthStageModel(model, validationTable);
    perBearing = bearlytics.evaluation.rulMetrics(validationTable.bearing, ...
        rulPred, validationTable.rulSeconds);
    rows{k} = table(protocol, modelName, perBearing.bearing, params.threshold, ...
        params.persistence, params.quantile, model.healthyRulSeconds, ...
        model.degradationSeconds, model.nDetected, fpt(1), ...
        perBearing.nEvaluated, perBearing.score, perBearing.rmse, perBearing.mae, ...
        'VariableNames', {'protocol', 'model', 'validationBearing', 'threshold', ...
        'persistence', 'quantile', 'healthyRulSeconds', 'degradationSeconds', ...
        'nTrainDetected', 'fptSnapshot', 'nEvaluated', 'score', 'rmse', 'mae'});
    predictionRows{k} = table(validationTable.bearing, validationTable.snapshotIndex, ...
        validationTable.rulSeconds, rulPred, healthIndex, ...
        'VariableNames', {'bearing', 'snapshotIndex', 'rulSeconds', 'rulPredSeconds', 'healthIndex'});
end
validation = vertcat(rows{:});
validationPredictions = vertcat(predictionRows{:});
validationSummary = struct('nBearings', height(validation), ...
    'nEvaluated', sum(validation.nEvaluated), 'score', mean(validation.score), ...
    'rmse', mean(validation.rmse), 'mae', mean(validation.mae));
writetable(validation, fullfile(outputDir, 'modeling_hi_stage_validation.csv'));
writetable(validationPredictions, ...
    fullfile(outputDir, 'modeling_hi_stage_validation_predictions.csv'));
configText = sprintf('umbral %.1f, persistencia %d, cuantil %.2f', ...
    params.threshold, params.persistence, params.quantile);
plotRulTrajectories(validationPredictions, ...
    fullfile(outputDir, 'modeling_hi_stage_validation_trajectories.png'), ...
    "HI por etapas (" + configText + "): validación fuera de fold");
plotHealthIndex(validationPredictions, validation, params.threshold, ...
    fullfile(outputDir, 'modeling_hi_stage_validation_health_index.png'));
fprintf('Configuración elegida por validación: %s.\n', configText);
fprintf('Validación LOBO-TRAJ (%d rodamientos, promedio entre rodamientos):\n', ...
    validationSummary.nBearings);
fprintf('  score PHM 2012 (0-1): %.4f | RMSE: %.1f s | MAE: %.1f s\n', ...
    validationSummary.score, validationSummary.rmse, validationSummary.mae);

test = table();
testSummary = struct();
if evaluateTest
    model = fitHealthStageModel(folds{1}.learning, params);
    testTable = sortrows(folds{1}.test, {'bearing', 'snapshotIndex'});
    [rulPred, healthIndex] = predictHealthStageModel(model, testTable);
    [testPerBearing, testSummary] = bearlytics.evaluation.rulMetrics( ...
        testTable.bearing, rulPred, testTable.rulSeconds);
    test = [table(repmat(protocol, height(testPerBearing), 1), ...
        repmat(modelName, height(testPerBearing), 1), ...
        'VariableNames', {'protocol', 'model'}), testPerBearing];
    testPredictions = table(testTable.bearing, testTable.snapshotIndex, ...
        testTable.rulSeconds, rulPred, healthIndex, ...
        'VariableNames', {'bearing', 'snapshotIndex', 'rulSeconds', 'rulPredSeconds', 'healthIndex'});
    writetable(test, fullfile(outputDir, 'modeling_hi_stage_test.csv'));
    writetable(testPredictions, fullfile(outputDir, 'modeling_hi_stage_test_predictions.csv'));
    plotRulTrajectories(testPredictions, ...
        fullfile(outputDir, 'modeling_hi_stage_test_trajectories.png'), ...
        "HI por etapas (" + configText + "): Full\_Test\_Set");
    fprintf('Test LOBO-TRAJ (%d rodamientos de Full_Test_Set):\n', testSummary.nBearings);
    fprintf('  score PHM 2012 (0-1): %.4f | RMSE: %.1f s | MAE: %.1f s\n', ...
        testSummary.score, testSummary.rmse, testSummary.mae);
else
    fprintf('Test no evaluado (evaluateTest = false).\n');
end

summaryRows = table(protocol, modelName, "validation", validationSummary.nBearings, ...
    validationSummary.nEvaluated, validationSummary.score, validationSummary.rmse, ...
    validationSummary.mae, 'VariableNames', {'protocol', 'model', 'split', ...
    'nBearings', 'nEvaluated', 'score', 'rmse', 'mae'});
if evaluateTest
    summaryRows = [summaryRows; table(protocol, modelName, "test", testSummary.nBearings, ...
        testSummary.nEvaluated, testSummary.score, testSummary.rmse, testSummary.mae, ...
        'VariableNames', summaryRows.Properties.VariableNames)];
end
writetable(summaryRows, fullfile(outputDir, 'modeling_hi_stage_summary.csv'));
results = struct('grid', grid, 'params', params, 'validation', validation, ...
    'validationSummary', validationSummary, 'test', test, 'testSummary', testSummary);
end

function params = candidateParams(baseParams, candidate)
params = baseParams;
params.threshold = candidate(1);
params.persistence = candidate(2);
params.quantile = candidate(3);
end

function plotHealthIndex(predictions, validation, threshold, filePath)
% HI por rodamiento de validación, con el umbral y el FPT detectado.
bearingNames = unique(predictions.bearing, 'stable');
fig = figure('Theme', 'light', 'Visible', 'off', 'Position', [100 100 1050 520]);
cleanup = onCleanup(@() close(fig));
layout = tiledlayout(fig, 2, 3, 'TileSpacing', 'compact');
title(layout, 'Índice de salud (log del RMS relativo a los primeros 10 min)');
for b = 1:numel(bearingNames)
    rows = predictions.bearing == bearingNames(b);
    hours = (predictions.snapshotIndex(rows) - 1) * 10 / 3600;
    ax = nexttile(layout);
    plot(ax, hours, predictions.healthIndex(rows), 'Color', [0.00 0.45 0.74]);
    yline(ax, threshold, '--', 'Color', [0.85 0.33 0.10]);
    fpt = validation.fptSnapshot(validation.validationBearing == bearingNames(b));
    if ~isnan(fpt)
        xline(ax, (fpt - 1) * 10 / 3600, ':', 'FPT', 'Color', [0.3 0.3 0.3]);
    end
    title(ax, bearingNames(b), 'Interpreter', 'none');
    xlabel(ax, 'Tiempo (h)');
    ylabel(ax, 'HI');
    grid(ax, 'on');
end
exportgraphics(fig, filePath, 'Resolution', 150);
end
