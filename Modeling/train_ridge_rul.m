function results = train_ridge_rul(windowSnapshots, evaluateTest, preprocessRoot)
%TRAIN_RIDGE_RUL Regresión ridge de RUL bajo el protocolo LOBO-TRAJ.
%   1) Selección de lambda: para cada valor de la rejilla y cada uno de los 6
%      folds de Learning_set (leave-one-bearing-out), ajusta ridge con los 5
%      rodamientos de train y evalúa la trayectoria del rodamiento de
%      validación. Se elige el lambda con mayor score PHM 2012 medio entre
%      rodamientos; en caso de empate, el más regularizado.
%   2) Opcional (evaluateTest = true): reajusta el escalador y el modelo con
%      los 6 rodamientos de Learning_set y evalúa UNA vez los 11 de
%      Full_Test_Set. El test no interviene en ninguna decisión.
%
%   INPUTS:
%       windowSnapshots - ventana usada en run_preprocess (por defecto 31).
%       evaluateTest    - false por defecto. Ponerlo en true solo al final.
%       preprocessRoot  - carpeta de salidas de PreProcess (por defecto
%                         results/preprocess).
%   OUTPUT:
%       results - struct con grid (score medio por lambda), validation
%                 (6 filas, lambda elegido), validationSummary, alpha
%                 elegido, test (11 filas o vacía) y testSummary.
%   SALIDAS en results/ (se reescriben al repetir):
%       modeling_ridge_rul_grid.csv, modeling_ridge_rul_validation.csv,
%       modeling_ridge_rul_validation_predictions.csv,
%       modeling_ridge_rul_validation_trajectories.png,
%       modeling_ridge_rul_summary.csv y, si se evalúa el test,
%       modeling_ridge_rul_test.csv, modeling_ridge_rul_test_predictions.csv y
%       modeling_ridge_rul_test_trajectories.png.
%   SUPUESTOS: lambda = alpha * nTrain, para que la misma alpha sea
%   comparable entre folds de distinto tamaño y en el reajuste final. No hay
%   aleatoriedad (solución cerrada), así que no requiere rng.
%   Ejemplo desde la raíz: addpath('Modeling'); train_ridge_rul;

arguments
    windowSnapshots (1, 1) double {mustBeInteger, mustBePositive} = 31
    evaluateTest (1, 1) logical = false
    preprocessRoot (1, 1) string = ""
end
repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(repoRoot);
outputDir = fullfile(repoRoot, 'results');
if preprocessRoot == ""
    preprocessRoot = string(fullfile(repoRoot, 'results', 'preprocess'));
end

protocol = "LOBO-TRAJ";
modelName = "ridge_rul";
learningBearings = ["Bearing1_1"; "Bearing1_2"; "Bearing2_1"; ...
    "Bearing2_2"; "Bearing3_1"; "Bearing3_2"];
alphaGrid = 10 .^ (-4:0.5:3)';

% Se cargan los 6 folds una sola vez; cada uno trae su propio escalador de train.
folds = cell(numel(learningBearings), 1);
for k = 1:numel(learningBearings)
    folds{k} = loadFold(learningBearings(k), windowSnapshots, preprocessRoot);
end
predictorNames = folds{1}.predictorNames;

% Rejilla: score, RMSE y MAE por (alpha, rodamiento de validación).
nAlpha = numel(alphaGrid);
nFold = numel(folds);
scores = zeros(nAlpha, nFold);
rmses = zeros(nAlpha, nFold);
maes = zeros(nAlpha, nFold);
for k = 1:nFold
    fold = folds{k};
    for a = 1:nAlpha
        model = fitRidgeRul(fold.train, predictorNames, alphaGrid(a) * height(fold.train));
        perBearing = bearlytics.evaluation.rulMetrics(fold.validation.bearing, ...
            predictRidgeRul(model, fold.validation), fold.validation.rulSeconds);
        scores(a, k) = perBearing.score;
        rmses(a, k) = perBearing.rmse;
        maes(a, k) = perBearing.mae;
    end
end
grid = table(alphaGrid, mean(scores, 2), mean(rmses, 2), mean(maes, 2), ...
    'VariableNames', {'alpha', 'meanScore', 'meanRmse', 'meanMae'});
writetable(grid, fullfile(outputDir, 'modeling_ridge_rul_grid.csv'));
bestScore = max(grid.meanScore);
bestIndex = find(grid.meanScore == bestScore, 1, 'last');
alpha = alphaGrid(bestIndex);

% Métricas y predicciones fuera de fold con el alpha elegido.
rows = cell(nFold, 1);
predictionRows = cell(nFold, 1);
for k = 1:nFold
    fold = folds{k};
    lambda = alpha * height(fold.train);
    model = fitRidgeRul(fold.train, predictorNames, lambda);
    rulPred = predictRidgeRul(model, fold.validation);
    perBearing = bearlytics.evaluation.rulMetrics(fold.validation.bearing, ...
        rulPred, fold.validation.rulSeconds);
    if height(perBearing) ~= 1 || perBearing.bearing ~= learningBearings(k)
        error('train_ridge_rul:validationIdentity', ...
            'El fold de %s no evaluó exactamente ese rodamiento.', learningBearings(k));
    end
    rows{k} = table(protocol, modelName, perBearing.bearing, alpha, lambda, ...
        perBearing.nEvaluated, perBearing.score, perBearing.rmse, perBearing.mae, ...
        'VariableNames', {'protocol', 'model', 'validationBearing', 'alpha', ...
        'lambda', 'nEvaluated', 'score', 'rmse', 'mae'});
    predictionRows{k} = table(fold.validation.bearing, fold.validation.snapshotIndex, ...
        fold.validation.rulSeconds, rulPred, ...
        'VariableNames', {'bearing', 'snapshotIndex', 'rulSeconds', 'rulPredSeconds'});
end
validation = vertcat(rows{:});
validationPredictions = vertcat(predictionRows{:});
validationSummary = struct('nBearings', height(validation), ...
    'nEvaluated', sum(validation.nEvaluated), 'score', mean(validation.score), ...
    'rmse', mean(validation.rmse), 'mae', mean(validation.mae));
writetable(validation, fullfile(outputDir, 'modeling_ridge_rul_validation.csv'));
writetable(validationPredictions, ...
    fullfile(outputDir, 'modeling_ridge_rul_validation_predictions.csv'));
plotTrajectories(validationPredictions, ...
    fullfile(outputDir, 'modeling_ridge_rul_validation_trajectories.png'), ...
    sprintf('Ridge (alpha = %g): validación fuera de fold', alpha));
fprintf('Alpha elegido por validación: %g (rejilla 1e-4 a 1e3).\n', alpha);
fprintf('Validación LOBO-TRAJ (%d rodamientos, promedio entre rodamientos):\n', ...
    validationSummary.nBearings);
fprintf('  score PHM 2012 (0-1): %.4f | RMSE: %.1f s | MAE: %.1f s\n', ...
    validationSummary.score, validationSummary.rmse, validationSummary.mae);

test = table();
testSummary = struct();
if evaluateTest
    [learningTable, testTable] = finalTrainingTables(folds{1}, predictorNames, learningBearings);
    lambda = alpha * height(learningTable);
    model = fitRidgeRul(learningTable, predictorNames, lambda);
    rulPred = predictRidgeRul(model, testTable);
    [testPerBearing, testSummary] = bearlytics.evaluation.rulMetrics( ...
        testTable.bearing, rulPred, testTable.rulSeconds);
    test = [table(repmat(protocol, height(testPerBearing), 1), ...
        repmat(modelName, height(testPerBearing), 1), ...
        repmat(alpha, height(testPerBearing), 1), ...
        'VariableNames', {'protocol', 'model', 'alpha'}), testPerBearing];
    testPredictions = table(testTable.bearing, testTable.snapshotIndex, ...
        testTable.rulSeconds, rulPred, ...
        'VariableNames', {'bearing', 'snapshotIndex', 'rulSeconds', 'rulPredSeconds'});
    writetable(test, fullfile(outputDir, 'modeling_ridge_rul_test.csv'));
    writetable(testPredictions, fullfile(outputDir, 'modeling_ridge_rul_test_predictions.csv'));
    plotTrajectories(testPredictions, ...
        fullfile(outputDir, 'modeling_ridge_rul_test_trajectories.png'), ...
        sprintf('Ridge (alpha = %g): Full\\_Test\\_Set, evaluado una vez', alpha));
    fprintf('Test LOBO-TRAJ (%d rodamientos de Full_Test_Set, evaluado una vez):\n', ...
        testSummary.nBearings);
    fprintf('  score PHM 2012 (0-1): %.4f | RMSE: %.1f s | MAE: %.1f s\n', ...
        testSummary.score, testSummary.rmse, testSummary.mae);
else
    fprintf('Test no evaluado (evaluateTest = false).\n');
end

summaryRows = table(protocol, modelName, "validation", alpha, ...
    validationSummary.nBearings, validationSummary.nEvaluated, ...
    validationSummary.score, validationSummary.rmse, validationSummary.mae, ...
    'VariableNames', {'protocol', 'model', 'split', 'alpha', 'nBearings', ...
    'nEvaluated', 'score', 'rmse', 'mae'});
if evaluateTest
    summaryRows = [summaryRows; table(protocol, modelName, "test", alpha, ...
        testSummary.nBearings, testSummary.nEvaluated, testSummary.score, ...
        testSummary.rmse, testSummary.mae, 'VariableNames', summaryRows.Properties.VariableNames)];
end
writetable(summaryRows, fullfile(outputDir, 'modeling_ridge_rul_summary.csv'));
results = struct('grid', grid, 'alpha', alpha, 'validation', validation, ...
    'validationSummary', validationSummary, 'test', test, 'testSummary', testSummary);
end

function plotTrajectories(predictions, filePath, figureTitle)
% RUL real frente a predicho, en horas, un panel por rodamiento.
bearingNames = unique(predictions.bearing, 'stable');
nPanels = numel(bearingNames);
nColumns = min(4, nPanels);
nRows = ceil(nPanels / nColumns);
fig = figure('Theme', 'light', 'Visible', 'off', ...
    'Position', [100 100 300 * nColumns, 240 * nRows]);
cleanup = onCleanup(@() close(fig));
layout = tiledlayout(fig, nRows, nColumns, 'TileSpacing', 'compact');
title(layout, figureTitle);
for b = 1:nPanels
    rows = predictions.bearing == bearingNames(b);
    ax = nexttile(layout);
    plot(ax, (predictions.snapshotIndex(rows) - 1) * 10 / 3600, ...
        predictions.rulSeconds(rows) / 3600, 'k-', 'LineWidth', 1.2);
    hold(ax, 'on');
    plot(ax, (predictions.snapshotIndex(rows) - 1) * 10 / 3600, ...
        predictions.rulPredSeconds(rows) / 3600, '-', 'Color', [0.85 0.33 0.10]);
    hold(ax, 'off');
    title(ax, bearingNames(b), 'Interpreter', 'none');
    xlabel(ax, 'Tiempo (h)');
    ylabel(ax, 'RUL (h)');
    grid(ax, 'on');
end
legend(nexttile(layout, 1), {'Real', 'Predicho'}, 'Location', 'northeast');
exportgraphics(fig, filePath, 'Resolution', 150);
end
