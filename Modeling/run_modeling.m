function comparison = run_modeling(windowSnapshots, evaluateTest)
%RUN_MODELING Punto de entrada de Modeling: baseline, ridge y HI por etapas, comparados.
%   Ejecuta train_baseline_mean, train_ridge_rul y train_health_index_rul con el mismo protocolo
%   (LOBO-TRAJ) y escribe una tabla comparativa con el promedio entre
%   rodamientos de cada modelo y split.
%
%   INPUTS:
%       windowSnapshots - ventana usada en run_preprocess (por defecto 31).
%       evaluateTest    - false por defecto. En true evalúa UNA vez
%                         Full_Test_Set con los tres modelos; hacerlo solo con la
%                         configuración cerrada.
%   OUTPUT:
%       comparison - tabla con model, split, nBearings, nEvaluated, score,
%                    rmse y mae. También en results/modeling_comparison.csv.
%   REQUISITOS: los 6 folds de PreProcess (ver Modeling/README.md).
%   Ejemplo desde la raíz: addpath('Modeling'); run_modeling;

arguments
    windowSnapshots (1, 1) double {mustBeInteger, mustBePositive} = 31
    evaluateTest (1, 1) logical = false
end
repoRoot = fileparts(fileparts(mfilename('fullpath')));
fprintf('--- Baseline: media de RUL de train ---\n');
baseline = train_baseline_mean(windowSnapshots, evaluateTest);
fprintf('--- Ridge sobre los 32 predictores ---\n');
ridge = train_ridge_rul(windowSnapshots, evaluateTest);
fprintf('--- Índice de salud por etapas ---\n');
healthStage = train_health_index_rul(windowSnapshots, evaluateTest);

comparison = [summaryRow("mean_rul_train", "validation", baseline.validationSummary); ...
    summaryRow("ridge_rul", "validation", ridge.validationSummary); ...
    summaryRow("hi_stage_rul", "validation", healthStage.validationSummary)];
if evaluateTest
    comparison = [comparison; ...
        summaryRow("mean_rul_train", "test", baseline.testSummary); ...
        summaryRow("ridge_rul", "test", ridge.testSummary); ...
        summaryRow("hi_stage_rul", "test", healthStage.testSummary)];
end
writetable(comparison, fullfile(repoRoot, 'results', 'modeling_comparison.csv'));
fprintf('--- Comparación (promedio entre rodamientos) ---\n');
disp(comparison);
end

function row = summaryRow(modelName, splitName, summary)
row = table(modelName, splitName, summary.nBearings, summary.nEvaluated, ...
    summary.score, summary.rmse, summary.mae, ...
    'VariableNames', {'model', 'split', 'nBearings', 'nEvaluated', 'score', 'rmse', 'mae'});
end
