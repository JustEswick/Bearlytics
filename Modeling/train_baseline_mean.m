function results = train_baseline_mean(windowSnapshots, evaluateTest, preprocessRoot)
%TRAIN_BASELINE_MEAN Baseline de media de RUL de train bajo el protocolo LOBO-TRAJ.
%   Para cada uno de los 6 rodamientos de Learning_set como validación, predice
%   siempre la media de rulSeconds de los otros 5 (train) y evalúa la
%   trayectoria de validación con el score PHM 2012, RMSE y MAE.
%   Opcionalmente (evaluateTest = true) ajusta la constante con los 6 rodamientos
%   de Learning_set y evalúa UNA vez los 11 de Full_Test_Set.
%
%   INPUTS:
%       windowSnapshots - ventana usada en run_preprocess (por defecto 31).
%       evaluateTest    - false por defecto. Ponerlo en true solo al final: el
%                         test se evalúa una única vez y no guía decisiones.
%       preprocessRoot  - carpeta de salidas de PreProcess (por defecto
%                         results/preprocess).
%   OUTPUT:
%       results - struct con validation (tabla, 6 filas), validationSummary,
%                 test (tabla de 11 filas o vacía) y testSummary.
%   SALIDAS en results/: modeling_baseline_mean_rul_validation.csv,
%       modeling_baseline_mean_rul_summary.csv y, si se evalúa,
%       modeling_baseline_mean_rul_test.csv. Repetir la ejecución las reescribe.
%   REQUISITOS: los 6 folds generados con run_preprocess (uno por rodamiento de
%   Learning_set). El baseline no usa aleatoriedad, así que no requiere rng.
%   Ejemplo desde la raíz: addpath('Modeling'); train_baseline_mean;

arguments
    windowSnapshots (1, 1) double {mustBeInteger, mustBePositive} = 31
    evaluateTest (1, 1) logical = false
    preprocessRoot (1, 1) string = ""
end
repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(repoRoot);
outputDir = fullfile(repoRoot, 'results');
if ~isfolder(outputDir)
    error('train_baseline_mean:outputMissing', 'Falta la carpeta results/ en la raíz del repo.');
end

protocol = "LOBO-TRAJ";
modelName = "mean_rul_train";
learningBearings = ["Bearing1_1"; "Bearing1_2"; "Bearing2_1"; ...
    "Bearing2_2"; "Bearing3_1"; "Bearing3_2"];

% Validación: un fold por rodamiento de Learning_set (leave-one-bearing-out).
rows = cell(numel(learningBearings), 1);
for k = 1:numel(learningBearings)
    fold = loadFold(learningBearings(k), windowSnapshots, preprocessRoot);
    [perBearing, ~, constantSeconds] = meanRulBaseline(fold.train, fold.validation);
    if height(perBearing) ~= 1 || perBearing.bearing ~= learningBearings(k)
        error('train_baseline_mean:validationIdentity', ...
            'El fold de %s no evaluó exactamente ese rodamiento.', learningBearings(k));
    end
    rows{k} = table(protocol, modelName, perBearing.bearing, constantSeconds, ...
        perBearing.nEvaluated, perBearing.score, perBearing.rmse, perBearing.mae, ...
        'VariableNames', {'protocol', 'model', 'validationBearing', ...
        'constantSeconds', 'nEvaluated', 'score', 'rmse', 'mae'});
end
validation = vertcat(rows{:});
validationSummary = struct('nBearings', height(validation), ...
    'nEvaluated', sum(validation.nEvaluated), 'score', mean(validation.score), ...
    'rmse', mean(validation.rmse), 'mae', mean(validation.mae));
writetable(validation, fullfile(outputDir, 'modeling_baseline_mean_rul_validation.csv'));
fprintf('Validación LOBO-TRAJ (%d rodamientos, promedio entre rodamientos):\n', ...
    validationSummary.nBearings);
fprintf('  score PHM 2012 (0-1): %.4f | RMSE: %.1f s | MAE: %.1f s\n', ...
    validationSummary.score, validationSummary.rmse, validationSummary.mae);

test = table();
testSummary = struct();
if evaluateTest
    % Modelo final: la constante usa los 6 rodamientos de Learning_set.
    % train + validation de cualquier fold reúne exactamente esos 6.
    allLearning = [fold.train; fold.validation];
    if ~isequal(sort(unique(allLearning.bearing)), sort(learningBearings))
        error('train_baseline_mean:learningSet', ...
            'train + validation no reúnen los 6 rodamientos de Learning_set.');
    end
    [testPerBearing, testMetrics, finalConstant] = meanRulBaseline(allLearning, fold.test);
    test = [table(repmat(protocol, height(testPerBearing), 1), ...
        repmat(modelName, height(testPerBearing), 1), ...
        repmat(finalConstant, height(testPerBearing), 1), ...
        'VariableNames', {'protocol', 'model', 'constantSeconds'}), testPerBearing];
    testSummary = testMetrics;
    writetable(test, fullfile(outputDir, 'modeling_baseline_mean_rul_test.csv'));
    fprintf('Test LOBO-TRAJ (%d rodamientos de Full_Test_Set, evaluado una vez):\n', ...
        testSummary.nBearings);
    fprintf('  score PHM 2012 (0-1): %.4f | RMSE: %.1f s | MAE: %.1f s\n', ...
        testSummary.score, testSummary.rmse, testSummary.mae);
else
    fprintf('Test no evaluado (evaluateTest = false).\n');
end

summaryRows = table(protocol, modelName, "validation", ...
    validationSummary.nBearings, validationSummary.nEvaluated, ...
    validationSummary.score, validationSummary.rmse, validationSummary.mae, ...
    'VariableNames', {'protocol', 'model', 'split', 'nBearings', 'nEvaluated', ...
    'score', 'rmse', 'mae'});
if evaluateTest
    summaryRows = [summaryRows; table(protocol, modelName, "test", ...
        testSummary.nBearings, testSummary.nEvaluated, testSummary.score, ...
        testSummary.rmse, testSummary.mae, 'VariableNames', summaryRows.Properties.VariableNames)];
end
writetable(summaryRows, fullfile(outputDir, 'modeling_baseline_mean_rul_summary.csv'));
results = struct('validation', validation, 'validationSummary', validationSummary, ...
    'test', test, 'testSummary', testSummary);
end
