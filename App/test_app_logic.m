function tests = test_app_logic
%TEST_APP_LOGIC Comprueba autorización, modelo y entradas de la app.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
testCase.TestData.root = root;
testCase.TestData.originalPath = path;
addpath(root);
end

function teardownOnce(testCase)
path(testCase.TestData.originalPath);
end

function testFemtoReference(testCase)
folder = string(getenv('BEARLYTICS_TEST_BEARING_DIR'));
testCase.assumeTrue(isfolder(folder), 'Configura BEARLYTICS_TEST_BEARING_DIR con Bearing1_3.');
artifact = bearlytics.app.loadApprovedModel();
names = compose("acc_%05d.csv", (200:-1:1)');
prediction = bearlytics.app.predictBearing(principal("analyst"), artifact, folder, names);
expectedFile = fullfile(testCase.TestData.root, 'results', 'modeling_ridge_rul_test_predictions.csv');
published = readtable(expectedFile, 'TextType', 'string');
expected = sortrows(published(published.bearing == "Bearing1_3" & published.snapshotIndex <= 200, :), 'snapshotIndex');
testCase.verifyEqual(prediction.rulSeconds, expected.rulPredSeconds, 'AbsTol', 1e-6);
testCase.verifyEqual(prediction.healthIndex(end), 0.117, 'AbsTol', 0.001);
fprintf('Referencia FEMTO: 200 filas, max dif %.4g s, RUL %.2f h, HI %.3f\n', ...
    max(abs(prediction.rulSeconds - expected.rulPredSeconds)), ...
    prediction.rulSeconds(end)/3600, prediction.healthIndex(end));
end

function testApprovedHeaderAndVersion(testCase)
artifact = bearlytics.app.loadApprovedModel();
[payload, header] = bearlytics.model.encodeModelArtifact(artifact);
key = uint8(0:31);
sealed = bearlytics.security.sealArtifact(payload, key, header);
testCase.verifyEqual(bearlytics.app.loadApprovedModel(sealed, key).header, artifact.header);
version = artifact;
version.header.modelVersion = "2.0.0";
[otherPayload, otherHeader] = bearlytics.model.encodeModelArtifact(version);
other = bearlytics.security.sealArtifact(otherPayload, key, otherHeader);
testCase.verifyError(@() bearlytics.app.loadApprovedModel(other, key), ...
    'bearlytics:security:contextMismatch');
end

function testRejectsWrongKey(testCase)
artifact = bearlytics.app.loadApprovedModel();
[payload, header] = bearlytics.model.encodeModelArtifact(artifact);
sealed = bearlytics.security.sealArtifact(payload, uint8(0:31), header);
testCase.verifyError(@() bearlytics.app.loadApprovedModel(sealed, uint8(1:32)), ...
    'bearlytics:security:authenticationFailed');
end

function testDeniesBeforeReadingFiles(testCase)
viewer = principal("viewer");
anonymous = principal("analyst");
anonymous.authenticated = false;
unknown = principal("desconocido");
for account = [viewer, anonymous, unknown]
    testCase.verifyError(@() bearlytics.app.predictBearing(account, [], "", "acc_00001.csv"), ...
        'bearlytics:app:denied');
end
end

function testAnalystRequiresApprovedModel(testCase)
testCase.verifyError(@() bearlytics.app.predictBearing(principal("analyst"), [], "", "acc_00001.csv"), ...
    'bearlytics:app:modelUnavailable');
end

function testRejectsInvalidSnapshotNamesAndSequence(testCase)
testCase.verifyError(@() bearlytics.app.loadBearingFeatures("", ["acc_00001.csv"; "acc_00003.csv"]), ...
    'bearlytics:app:snapshotSequence');
testCase.verifyError(@() bearlytics.app.loadBearingFeatures("", ["acc_00001.csv"; "acc_00001.csv"]), ...
    'bearlytics:app:snapshotSequence');
testCase.verifyError(@() bearlytics.app.loadBearingFeatures("", "temp_00001.csv"), ...
    'bearlytics:app:snapshotName');
end

function testRejectsWrongShape(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
writematrix(ones(2, 6), fullfile(fixture.Folder, 'acc_00001.csv'));
testCase.verifyError(@() bearlytics.app.loadBearingFeatures(fixture.Folder, "acc_00001.csv"), ...
    'bearlytics:app:snapshotRead');
end

function testRejectsExcessSnapshots(testCase)
testCase.verifyError(@() bearlytics.app.loadBearingFeatures("", compose("acc_%05d.csv", (1:3001)')), ...
    'bearlytics:app:snapshotCount');
end

function testCanCancelBeforeReading(testCase)
testCase.verifyError(@() bearlytics.app.loadBearingFeatures("", "acc_00001.csv", @(~, ~) true), ...
    'bearlytics:app:cancelled');
end

function account = principal(role)
account = struct('authenticated', true, 'subject', "cuenta-de-prueba", 'role', role);
end
