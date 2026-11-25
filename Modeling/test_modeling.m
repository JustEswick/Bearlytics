function tests = test_modeling
%TEST_MODELING Pruebas sin dataset de evaluación PHM 2012, baseline y loadFold.
%   Ejecutar desde la raíz: results = runtests('Modeling/test_modeling.m');
%   assertSuccess(results). Usa datos sintéticos con valores calculados a mano;
%   no necesita el dataset FEMTO ni las salidas reales de PreProcess.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
repoRoot = fileparts(fileparts(mfilename('fullpath')));
testCase.TestData.originalPath = path;
addpath(repoRoot);
addpath(fullfile(repoRoot, 'Modeling'));
end

function teardownOnce(testCase)
path(testCase.TestData.originalPath);
end

%% Score PHM 2012

function testPerfectPredictionScoresOne(testCase)
actual = bearlytics.evaluation.phm2012Score([10; 20; 30], [10; 20; 30]);
verifyEqual(testCase, actual, 1, 'AbsTol', 1e-12);
end

function testFivePercentOverestimationScoresHalf(testCase)
% Er = 100*(100-105)/100 = -5 -> A = 0.5
actual = bearlytics.evaluation.phm2012Score(105, 100);
verifyEqual(testCase, actual, 0.5, 'AbsTol', 1e-12);
end

function testTwentyPercentUnderestimationScoresHalf(testCase)
% Er = 100*(100-80)/100 = 20 -> A = 0.5
actual = bearlytics.evaluation.phm2012Score(80, 100);
verifyEqual(testCase, actual, 0.5, 'AbsTol', 1e-12);
end

function testOverestimationIsPenalizedMoreThanUnderestimation(testCase)
% +-10 % de error: sobreestimar da 2^-2 = 0.25; subestimar da 2^-0.5.
over = bearlytics.evaluation.phm2012Score(110, 100);
under = bearlytics.evaluation.phm2012Score(90, 100);
verifyEqual(testCase, over, 0.25, 'AbsTol', 1e-12);
verifyEqual(testCase, under, 2 ^ -0.5, 'AbsTol', 1e-12);
verifyLessThan(testCase, over, under);
end

function testScoreIsMeanOfSnapshotScores(testCase)
[score, perSnapshot] = bearlytics.evaluation.phm2012Score([105; 80], [100; 100]);
verifyEqual(testCase, perSnapshot, [0.5; 0.5], 'AbsTol', 1e-12);
verifyEqual(testCase, score, 0.5, 'AbsTol', 1e-12);
end

function testPredictionsAreNotClipped(testCase)
% Una predicción negativa o enorme sigue siendo un score válido en [0, 1].
% -50 da Er = 150 % (A = 2^-7.5 ~ 0.0055) y 1e9 da A = 0: el promedio es ~0.0028.
actual = bearlytics.evaluation.phm2012Score([-50; 1e9], [100; 100]);
verifyGreaterThanOrEqual(testCase, actual, 0);
verifyEqual(testCase, actual, 2 ^ -7.5 / 2, 'AbsTol', 1e-12);
end

function testScoreRejectsInvalidInputs(testCase)
verifyError(testCase, @() bearlytics.evaluation.phm2012Score([1; 2], 1), ...
    'bearlytics:phm2012Score:size');
verifyError(testCase, @() bearlytics.evaluation.phm2012Score(1, 0), ...
    'bearlytics:phm2012Score:nonPositiveTrue');
end

%% Métricas por rodamiento (LOBO-TRAJ)

function testRulMetricsExcludesZeroRulAndAveragesBearings(testCase)
bearing = ["A"; "A"; "A"; "B"; "B"];
rulTrue = [10; 20; 0; 100; 50];
rulPred = [10; 20; 5; 105; 50];
[perBearing, summary] = bearlytics.evaluation.rulMetrics(bearing, rulPred, rulTrue);
verifyEqual(testCase, perBearing.bearing, ["A"; "B"]);
verifyEqual(testCase, perBearing.nEvaluated, [2; 2]);
% A: aciertos exactos. B: Er = -5 % (A = 0.5) y 0 % (A = 1) -> 0.75.
verifyEqual(testCase, perBearing.score, [1; 0.75], 'AbsTol', 1e-12);
verifyEqual(testCase, perBearing.rmse, [0; sqrt(25 / 2)], 'AbsTol', 1e-12);
verifyEqual(testCase, perBearing.mae, [0; 2.5], 'AbsTol', 1e-12);
verifyEqual(testCase, summary.nExcluded, 1);
verifyEqual(testCase, summary.nEvaluated, 4);
verifyEqual(testCase, summary.score, 0.875, 'AbsTol', 1e-12);
verifyEqual(testCase, summary.mae, 1.25, 'AbsTol', 1e-12);
end

function testRulMetricsRejectsBadInput(testCase)
verifyError(testCase, @() bearlytics.evaluation.rulMetrics(["A"; "B"], [1; 2; 3], [1; 2; 3]), ...
    'bearlytics:rulMetrics:size');
verifyError(testCase, @() bearlytics.evaluation.rulMetrics("A", 1, -1), ...
    'bearlytics:rulMetrics:negativeTrue');
verifyError(testCase, @() bearlytics.evaluation.rulMetrics("A", 1, 0), ...
    'bearlytics:rulMetrics:empty');
end

%% Baseline de media

function testMeanBaselineUsesTrainMean(testCase)
trainTable = table(["T"; "T"; "T"; "T"], [30; 20; 10; 0], ...
    'VariableNames', {'bearing', 'rulSeconds'});
evalTable = table(["V"; "V"; "V"], [20; 10; 0], ...
    'VariableNames', {'bearing', 'rulSeconds'});
[perBearing, summary, constantSeconds] = meanRulBaseline(trainTable, evalTable);
verifyEqual(testCase, constantSeconds, 15);
% Filas evaluadas: RUL 20 (Er = +25 %) y 10 (Er = -50 %); la de RUL 0 se excluye.
expectedScore = (2 ^ -1.25 + 2 ^ -10) / 2;
verifyEqual(testCase, perBearing.score, expectedScore, 'AbsTol', 1e-12);
verifyEqual(testCase, perBearing.rmse, 5, 'AbsTol', 1e-12);
verifyEqual(testCase, perBearing.mae, 5, 'AbsTol', 1e-12);
verifyEqual(testCase, summary.nExcluded, 1);
end

%% Ridge

function testRidgeWithoutPenaltyRecoversLinearRelation(testCase)
% y = 100 + 30*x1 - 20*x2 exacto: con lambda = 0 se recupera sin error.
x1 = [-1; 0; 1; 2; -2; 0.5];
x2 = [1; -1; 0; 0.5; 2; -0.5];
trainTable = table(x1, x2, 100 + 30 * x1 - 20 * x2, ...
    'VariableNames', {'x1', 'x2', 'rulSeconds'});
model = fitRidgeRul(trainTable, ["x1"; "x2"], 0);
verifyEqual(testCase, model.intercept, 100, 'AbsTol', 1e-9);
verifyEqual(testCase, model.coefficients, [30; -20], 'AbsTol', 1e-9);
evalTable = table(3, 1, 'VariableNames', {'x1', 'x2'});
verifyEqual(testCase, predictRidgeRul(model, evalTable), 170, 'AbsTol', 1e-9);
end

function testRidgeDoesNotPenalizeIntercept(testCase)
% Con lambda enorme los coeficientes tienden a 0 y la predicción a la media
% de train (que es lo que hace el baseline), no a 0.
x1 = [-1; 0; 1; 2];
trainTable = table(x1, [10; 20; 30; 60], 'VariableNames', {'x1', 'rulSeconds'});
model = fitRidgeRul(trainTable, "x1", 1e12);
verifyEqual(testCase, model.coefficients, 0, 'AbsTol', 1e-8);
verifyEqual(testCase, model.intercept, 30, 'AbsTol', 1e-6);
end

function testRidgeShrinksCoefficients(testCase)
% Con columna centrada de norma S, beta = S*b/(S+lambda): S = 2, lambda = 2 -> mitad.
x1 = [-1; 0; 1];
trainTable = table(x1, 50 + 10 * x1, 'VariableNames', {'x1', 'rulSeconds'});
model = fitRidgeRul(trainTable, "x1", 2);
verifyEqual(testCase, model.coefficients, 5, 'AbsTol', 1e-12);
verifyEqual(testCase, model.intercept, 50, 'AbsTol', 1e-12);
end

function testRidgeRejectsMissingPredictor(testCase)
trainTable = table([1; 2], [3; 4], 'VariableNames', {'x1', 'rulSeconds'});
verifyError(testCase, @() fitRidgeRul(trainTable, ["x1"; "x2"], 1), ...
    'bearlytics:fitRidgeRul:schema');
model = fitRidgeRul(trainTable, "x1", 1);
verifyError(testCase, @() predictRidgeRul(model, table([1; 2], 'VariableNames', {'x2'})), ...
    'bearlytics:predictRidgeRul:schema');
end

%% Artefacto de modelo

function testArtifactRoundTripPreservesPredictions(testCase)
artifact = makeArtifact();
[payload, header] = bearlytics.model.encodeModelArtifact(artifact);
decoded = bearlytics.model.decodeModelArtifact(payload);
verifyEqual(testCase, decoded.predictorNames, ["a"; "b"]);
verifyEqual(testCase, decoded.header.modelId, "test-model");
features = table([2; 4], [1; -1], 'VariableNames', {'a', 'b'});
verifyEqual(testCase, bearlytics.model.predictRulFromArtifact(decoded, features), ...
    bearlytics.model.predictRulFromArtifact(artifact, features), 'AbsTol', 1e-12);
% La cabecera (AAD prevista para el sprint 2) es exactamente el JSON del header.
verifyEqual(testCase, jsondecode(native2unicode(header', 'UTF-8')), ...
    jsondecode(jsonencode(artifact.header)));
end

function testArtifactPredictionAppliesScalerThenModel(testCase)
% a escalada = (2-1)/2 = 0.5; b escalada = (1-0)/1 = 1
% RUL = 100 + 10*0.5 - 20*1 = 85
features = table(2, 1, 'VariableNames', {'a', 'b'});
verifyEqual(testCase, bearlytics.model.predictRulFromArtifact(makeArtifact(), features), ...
    85, 'AbsTol', 1e-12);
end

function testArtifactRejectsUnsupportedOrInconsistentContent(testCase)
bad = makeArtifact();
bad.header.schemaVersion = 2;
verifyError(testCase, @() bearlytics.model.encodeModelArtifact(bad), 'bearlytics:model:version');
bad = makeArtifact();
bad.model.coefficients = [1; 2; 3];
verifyError(testCase, @() bearlytics.model.encodeModelArtifact(bad), ...
    'MATLAB:decodeModelArtifact:incorrectNumel');
bad = makeArtifact();
bad.scaler.scale = [0, 1];
verifyError(testCase, @() bearlytics.model.encodeModelArtifact(bad), ...
    'MATLAB:decodeModelArtifact:expectedPositive');
verifyError(testCase, @() bearlytics.model.decodeModelArtifact(uint8('no es json')'), ...
    'bearlytics:model:format');
end

function testArtifactRejectsMissingPredictorColumn(testCase)
verifyError(testCase, @() bearlytics.model.predictRulFromArtifact(makeArtifact(), ...
    table(1, 'VariableNames', {'a'})), 'bearlytics:model:schema');
end

%% Índice de salud y modelo por etapas

function testHealthIndexIsRelativeToInitialReference(testCase)
% RMS H constante 1 y después 4; RMS V constante: HI = 0 y luego log(4).
trace = table([1; 1; 1; 4; 4], [2; 2; 2; 2; 2], 'VariableNames', {'rmsHMean', 'rmsVMean'});
hi = bearlytics.computeHealthIndex(trace, 3);
verifyEqual(testCase, hi, [0; 0; 0; log(4); log(4)], 'AbsTol', 1e-12);
% La escala absoluta no importa: multiplicar el RMS no cambia el HI.
scaled = trace;
scaled{:, :} = 7 * scaled{:, :};
verifyEqual(testCase, bearlytics.computeHealthIndex(scaled, 3), hi, 'AbsTol', 1e-12);
end

function testHealthIndexIsCausal(testCase)
% Referencia expansiva: el HI de un prefijo es el mismo que en la serie completa.
trace = table([2; 1; 3; 5; 8; 6], [1; 1; 2; 1; 3; 2], 'VariableNames', {'rmsHMean', 'rmsVMean'});
full = bearlytics.computeHealthIndex(trace, 4);
verifyEqual(testCase, full(1), 0, 'AbsTol', 1e-12);
for k = 1:height(trace)
    verifyEqual(testCase, bearlytics.computeHealthIndex(trace(1:k, :), 4), full(1:k), 'AbsTol', 1e-12);
end
verifyError(testCase, @() bearlytics.computeHealthIndex(table([1; 0], [1; 1], ...
    'VariableNames', {'rmsHMean', 'rmsVMean'}), 2), 'MATLAB:computeHealthIndex:expectedPositive');
end

function testFirstPredictingTimeRequiresPersistence(testCase)
hi = [0; 1; 0; 1; 1; 1];
verifyEqual(testCase, detectFirstPredictingTime(hi, 0.5, 1), 2);
verifyEqual(testCase, detectFirstPredictingTime(hi, 0.5, 3), 6);
verifyTrue(testCase, isnan(detectFirstPredictingTime(hi, 2, 1)));
end

function testHealthStageModelFitAndPredictByHand(testCase)
% Ver valores esperados en el comentario de makeHealthStageTrain.
trainTable = makeHealthStageTrain();
params = struct('threshold', 0.7, 'persistence', 2, 'referenceSnapshots', 3, ...
    'quantile', 0.5, 'snapshotIntervalSeconds', 10);
model = fitHealthStageModel(trainTable, params);
verifyEqual(testCase, model.healthyRulSeconds, 40, 'AbsTol', 1e-12);
verifyEqual(testCase, model.degradationSeconds, 20, 'AbsTol', 1e-12);
verifyEqual(testCase, model.nDetected, 1);

% Rodamiento A desordenado: la salida se alinea con las filas de entrada.
evalTable = trainTable(trainTable.bearing == "A", :);
order = [10; 3; 8; 1; 5; 9; 2; 7; 4; 6];
[rulPred, ~, fpt] = predictHealthStageModel(model, evalTable(order, :));
expected = [40; 40; 40; 40; 40; 40; 40; 20; 10; 0];
verifyEqual(testCase, rulPred, expected(order), 'AbsTol', 1e-12);
verifyEqual(testCase, fpt, 8 * ones(10, 1));
end

%% loadFold

function testLoadFoldAcceptsValidFold(testCase)
root = newFoldRoot(testCase);
writeFold(root, makeFoldData());
fold = loadFold("Bearing1_2", 3, root);
verifyEqual(testCase, fold.predictorNames, ["p1"; "p2"]);
verifyEqual(testCase, height(fold.train), 7);
verifyEqual(testCase, height(fold.validation), 4);
verifyEqual(testCase, height(fold.test), 4);
verifyEqual(testCase, unique(fold.validation.bearing), "Bearing1_2");
end

function testLoadFoldRejectsMissingFile(testCase)
root = newFoldRoot(testCase);
writeFold(root, makeFoldData());
delete(fullfile(root, 'Bearing1_2_w3', 'test.csv'));
verifyError(testCase, @() loadFold("Bearing1_2", 3, root), ...
    'bearlytics:loadFold:missingFile');
end

function testLoadFoldRejectsBearingInTwoSplits(testCase)
root = newFoldRoot(testCase);
data = makeFoldData();
data.test.bearing(:) = "Bearing1_1";   % mismo rodamiento que en train
writeFold(root, data);
verifyError(testCase, @() loadFold("Bearing1_2", 3, root), ...
    'bearlytics:loadFold:leakage');
end

function testLoadFoldRejectsIncoherentRul(testCase)
root = newFoldRoot(testCase);
data = makeFoldData();
data.train.rulSeconds(2) = 5;
writeFold(root, data);
verifyError(testCase, @() loadFold("Bearing1_2", 3, root), ...
    'bearlytics:loadFold:rul');
end

function testLoadFoldRejectsMetadataAsPredictor(testCase)
root = newFoldRoot(testCase);
data = makeFoldData();
data.predictors.predictor(2) = "rulSeconds";
writeFold(root, data);
verifyError(testCase, @() loadFold("Bearing1_2", 3, root), ...
    'bearlytics:loadFold:predictorLeak');
end

function testLoadFoldRejectsUnknownFold(testCase)
root = newFoldRoot(testCase);
writeFold(root, makeFoldData());
% La carpeta es Bearing1_2_w3; pedir otro rodamiento no la encuentra.
verifyError(testCase, @() loadFold("Bearing2_1", 3, root), ...
    'bearlytics:loadFold:missingFile');
end

function testLoadFoldRejectsWrongValidationIdentity(testCase)
root = newFoldRoot(testCase);
data = makeFoldData();
data.validation.bearing(:) = "Bearing1_9";   % no es el rodamiento del fold
writeFold(root, data);
verifyError(testCase, @() loadFold("Bearing1_2", 3, root), ...
    'bearlytics:loadFold:validationIdentity');
end

%% Fixtures sintéticos (solo contratos; no son resultados FEMTO)

function trainTable = makeHealthStageTrain()
% A: 10 snapshots, RMS H pasa de 1 a 4 en el 7.º -> HI = log(4) > 0,7 desde
%    el 7.º; con persistencia 2 el FPT es el 8.º. Filas sanas: RUL 90..30;
%    RUL en el FPT = 20.
% B: 6 snapshots sin cambio -> sin FPT; filas sanas: RUL 50..0.
% Mediana de las 13 RUL sanas = 40; mediana de las RUL en el FPT = 20.
bearing = [repmat("A", 10, 1); repmat("B", 6, 1)];
snapshotIndex = [(1:10)'; (1:6)'];
rulSeconds = [(10 - (1:10)') * 10; (6 - (1:6)') * 10];
rmsHMean = [ones(6, 1); 4 * ones(4, 1); ones(6, 1)];
rmsVMean = ones(16, 1);
trainTable = table(bearing, snapshotIndex, rulSeconds, rmsHMean, rmsVMean);
end

function artifact = makeArtifact()
% Artefacto mínimo con 2 predictores y valores elegidos para calcular a mano.
artifact = struct();
artifact.header = struct('schemaVersion', 1, 'modelId', "test-model", ...
    'modelVersion', "0.0.1", 'modelType', "ridge_rul");
artifact.predictorNames = ["a"; "b"];
artifact.windowSnapshots = 3;
artifact.scaler = struct('center', [1, 0], 'scale', [2, 1]);
artifact.model = struct('intercept', 100, 'coefficients', [10; -20], ...
    'alpha', 1, 'lambda', 4);
artifact.training = struct('partition', "Learning_set", 'sourceCommit', "test");
artifact.metrics = struct('validation', struct('score', 0.5));
end

function root = newFoldRoot(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
root = fixture.Folder;
end

function data = makeFoldData()
data.train = [makeSplitTable("Learning_set", "Bearing1_1", 1, 4, "train"); ...
    makeSplitTable("Learning_set", "Bearing2_1", 2, 3, "train")];
data.validation = makeSplitTable("Learning_set", "Bearing1_2", 1, 4, "validation");
data.test = makeSplitTable("Full_Test_Set", "Bearing1_3", 1, 4, "test");
data.manifest = table(["Bearing1_1"; "Bearing2_1"; "Bearing1_2"; "Bearing1_3"], ...
    ["Learning_set"; "Learning_set"; "Learning_set"; "Full_Test_Set"], ...
    [1; 2; 1; 1], ["train"; "train"; "validation"; "test"], [4; 3; 4; 4], ...
    'VariableNames', {'bearing', 'partition', 'condition', 'split', 'nSnapshots'});
data.predictors = table(["p1"; "p2"], 'VariableNames', {'predictor'});
end

function tbl = makeSplitTable(partition, bearing, condition, n, splitName)
snapshotIndex = (1:n)';
rulSeconds = (n - snapshotIndex) * 10;
partition = repmat(partition, n, 1);
bearing = repmat(bearing, n, 1);
condition = repmat(condition, n, 1);
split = repmat(splitName, n, 1);
p1 = snapshotIndex / n;
p2 = -snapshotIndex / n;
tbl = table(partition, bearing, condition, snapshotIndex, rulSeconds, split, p1, p2);
end

function writeFold(root, data)
directory = fullfile(root, 'Bearing1_2_w3');
mkdir(directory);
writetable(data.train, fullfile(directory, 'train.csv'));
writetable(data.validation, fullfile(directory, 'validation.csv'));
writetable(data.test, fullfile(directory, 'test.csv'));
writetable(data.manifest, fullfile(directory, 'split_manifest.csv'));
writetable(data.predictors, fullfile(directory, 'predictors.csv'));
end
