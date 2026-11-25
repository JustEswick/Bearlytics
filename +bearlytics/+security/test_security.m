function tests = test_security
%TEST_SECURITY Contratos de cifrado autenticado y política RBAC fail-closed.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
testCase.TestData.originalPath = path;
addpath(repoRoot);
end

function teardownOnce(testCase)
path(testCase.TestData.originalPath);
end

function testArtifactRoundTrip(testCase)
key = uint8(0:31);
header = uint8('{"schemaVersion":1,"modelId":"test","modelVersion":"1.0.0","modelType":"ridge"}');
plaintext = uint8([0 1 2 3 127 128 255]);
sealed = bearlytics.security.sealArtifact(plaintext, key, header);
verifyEqual(testCase, bearlytics.security.openArtifact(sealed, key, header), plaintext(:));
verifyNotEqual(testCase, sealed.nonce, zeros(12, 1, 'uint8'));
end

function testArtifactTamperingFailsAuthentication(testCase)
key = uint8(0:31);
header = uint8('{"schemaVersion":1,"modelId":"test","modelVersion":"1.0.0","modelType":"ridge"}');
sealed = bearlytics.security.sealArtifact(uint8('model bytes'), key, header);
verifyError(testCase, @() bearlytics.security.openArtifact(sealed, key, uint8('different-header')),...
    'bearlytics:security:contextMismatch');
sealed.ciphertextAndTag(1) = bitxor(sealed.ciphertextAndTag(1), uint8(1));
verifyError(testCase, @() bearlytics.security.openArtifact(sealed, key, header), ...
    'bearlytics:security:authenticationFailed');
end

function testWrongKeyFailsAuthentication(testCase)
header = uint8('{"schemaVersion":1,"modelId":"test","modelVersion":"1.0.0","modelType":"ridge"}');
sealed = bearlytics.security.sealArtifact(uint8([1 2 3]), uint8(0:31), header);
verifyError(testCase, @() bearlytics.security.openArtifact(sealed, uint8(1:32), header), ...
    'bearlytics:security:authenticationFailed');
end

function testRejectsInvalidKeyAndEnvelope(testCase)
verifyError(testCase, @() bearlytics.security.sealArtifact(uint8(1), uint8(1:16)), ...
    'MATLAB:sealArtifact:incorrectNumel');
header = uint8('{"schemaVersion":1,"modelId":"test","modelVersion":"1.0.0","modelType":"ridge"}');
sealed = bearlytics.security.sealArtifact(uint8(1), uint8(0:31), header);
sealed.version = uint8(3);
verifyError(testCase, @() bearlytics.security.openArtifact(sealed, uint8(0:31), header), ...
    'bearlytics:security:sealedFormat');
end

function testRbacAllowsOnlyExplicitPermissions(testCase)
verifyTrue(testCase, bearlytics.security.isActionAllowed("viewer", "predictions:read"));
verifyFalse(testCase, bearlytics.security.isActionAllowed("viewer", "predictions:run"));
verifyTrue(testCase, bearlytics.security.isActionAllowed("analyst", "predictions:run"));
verifyFalse(testCase, bearlytics.security.isActionAllowed("analyst", "models:publish"));
verifyTrue(testCase, bearlytics.security.isActionAllowed("model_maintainer", "models:publish"));
verifyFalse(testCase, bearlytics.security.isActionAllowed("unknown", "users:manage"));
verifyFalse(testCase, bearlytics.security.isActionAllowed("security_admin", "models:publish"));
end

function testRbacRejectsMalformedRequests(testCase)
verifyFalse(testCase, bearlytics.security.isActionAllowed(["viewer", "analyst"], "predictions:read"));
verifyFalse(testCase, bearlytics.security.isActionAllowed("viewer", ""));
verifyFalse(testCase, bearlytics.security.isActionAllowed("viewer", "admin:*"));
end
