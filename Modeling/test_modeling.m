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
