function tests = test_preprocess
%TEST_PREPROCESS Pruebas sin dataset para etiquetas, causalidad y separación.
%   Ejecutar desde raíz: results = runtests('PreProcess/test_preprocess.m');
%   assertSuccess(results). No abre, modifica ni necesita el dataset FEMTO.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
repoRoot = fileparts(fileparts(mfilename('fullpath')));
testCase.TestData.originalPath = path;
addpath(repoRoot);
end

function teardownOnce(testCase)
path(testCase.TestData.originalPath);
end

function testLabelsAndPredictors(testCase)
[actual, names] = bearlytics.prepareRulTable(makeFixture(), 3);
rows = actual.bearing == "Bearing1_1";
verifyEqual(testCase, actual.rulSeconds(rows), [30; 20; 10; 0]);
verifyEqual(testCase, actual.historyCount(rows), [1; 2; 3; 3]);
verifyEqual(testCase, numel(names), 32);
verifyFalse(testCase, any(ismember(names, ...
    {'rulSeconds', 'bearing', 'condition', 'snapshotIndex', 'elapsedHours', 'partition'})));
end

function testFutureDoesNotChangePast(testCase)
input = makeFixture();
[before, names] = bearlytics.prepareRulTable(input, 3);
input.rmsH(input.bearing == "Bearing1_1" & input.snapshotIndex == 4) = 1e5;
after = bearlytics.prepareRulTable(input, 3);
past = before.bearing == "Bearing1_1" & before.snapshotIndex < 4;
verifyEqual(testCase, before{past, names}, after{past, names});
end

function testWindowDoesNotCrossBearings(testCase)
actual = bearlytics.prepareRulTable(makeFixture(), 3);
firstRows = actual.snapshotIndex == 1;
verifyEqual(testCase, actual.rmsHMean(firstRows), actual.rmsH(firstRows));
verifyEqual(testCase, actual.rmsHStd(firstRows), zeros(nnz(firstRows), 1));
verifyEqual(testCase, actual.rmsHSlopePerSecond(firstRows), zeros(nnz(firstRows), 1));
end

function testKnownTrailingTrend(testCase)
actual = bearlytics.prepareRulTable(makeFixture(), 3);
rows = actual.bearing == "Bearing1_1";
verifyEqual(testCase, actual.rmsHMean(rows), [1; 1.5; 2; 3], 'AbsTol', 1e-12);
verifyEqual(testCase, actual.rmsHSlopePerSecond(rows), [0; 0.1; 0.1; 0.1], ...
    'AbsTol', 1e-12);
end

function testRejectsMissingOrDuplicateSnapshots(testCase)
input = makeFixture();
verifyError(testCase, @() bearlytics.prepareRulTable(input([1, 3:end], :), 3), ...
    'bearlytics:prepareRulTable:sequence');
input.snapshotIndex(2) = input.snapshotIndex(1);
verifyError(testCase, @() bearlytics.prepareRulTable(input, 3), ...
    'bearlytics:prepareRulTable:sequence');
end

function testRejectsTruncatedPartition(testCase)
input = makeFixture();
input.partition(input.bearing == "Bearing1_3") = "Test_set";
verifyError(testCase, @() bearlytics.prepareRulTable(input, 3), ...
    'bearlytics:prepareRulTable:partition');
end

function testRejectsIdentityAcrossPartitions(testCase)
input = makeFixture();
input.partition(1) = "Full_Test_Set";
verifyError(testCase, @() bearlytics.prepareRulTable(input, 3), ...
    'bearlytics:prepareRulTable:identity');
end

function testRejectsBrokenCadence(testCase)
input = makeFixture();
input.elapsedHours(2) = 15 / 3600;
verifyError(testCase, @() bearlytics.prepareRulTable(input, 3), ...
    'bearlytics:prepareRulTable:time');
end

function testSplitAndTrainOnlyScaling(testCase)
[data, names] = bearlytics.prepareRulTable(makeFixture(), 3);
manifest = bearlytics.makeBearingSplit(data, "Bearing1_2");
verifyEqual(testCase, manifest.split, ["train"; "validation"; "test"]);
train = data.bearing == "Bearing1_1";
scaler = bearlytics.fitFeatureScaler(double(data{train, names}));
verifyEqual(testCase, scaler.center(1), 2.5);
scaled = bearlytics.applyFeatureScaler(double(data{train, names}), scaler);
verifyEqual(testCase, mean(scaled, 1), zeros(1, numel(names)), 'AbsTol', 1e-12);
% Un test extremo debe permanecer extremo, sin reajustar el escalador.
external = double(data{~train, names});
external(:, 1) = 1e6;
scaledExternal = bearlytics.applyFeatureScaler(external, scaler);
verifyGreaterThan(testCase, min(scaledExternal(:, 1)), 1e5);
verifyError(testCase, @() bearlytics.makeBearingSplit(data, "Bearing1_3"), ...
    'bearlytics:makeBearingSplit:validation');
end

function testConstantPredictors(testCase)
scaler = bearlytics.fitFeatureScaler([1, 2; 1, 4]);
verifyEqual(testCase, scaler.scale(1), 1);
verifyTrue(testCase, scaler.constantColumns(1));
actual = bearlytics.applyFeatureScaler([9, 3], scaler);
verifyEqual(testCase, actual(1), 8);
end

function input = makeFixture()
% Datos sintéticos, solo para contratos matemáticos; no resultados FEMTO.
partition = repelem(["Learning_set"; "Learning_set"; "Full_Test_Set"], 4);
bearing = repelem(["Bearing1_1"; "Bearing1_2"; "Bearing1_3"], 4);
condition = ones(12, 1);
snapshotIndex = repmat((1:4)', 3, 1);
elapsedHours = (snapshotIndex - 1) * 10 / 3600;
rmsH = (1:12)';
rmsV = rmsH + 1;
kurtosisH = 3 * ones(12, 1);
kurtosisV = kurtosisH;
crestFactorH = 2 * ones(12, 1);
crestFactorV = crestFactorH;
skewnessH = zeros(12, 1);
skewnessV = skewnessH;
input = table(partition, bearing, condition, snapshotIndex, elapsedHours, ...
    rmsH, rmsV, kurtosisH, kurtosisV, crestFactorH, crestFactorV, skewnessH, skewnessV);
end
