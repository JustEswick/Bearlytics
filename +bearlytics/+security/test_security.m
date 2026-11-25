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
plaintext = uint8([0 1 2 3 127 128 255]);
sealed = bearlytics.security.sealArtifact(plaintext, key);
verifyEqual(testCase, bearlytics.security.openArtifact(sealed, key), plaintext(:));
verifyNotEqual(testCase, sealed.nonce, zeros(12, 1, 'uint8'));
end

function testArtifactTamperingFailsAuthentication(testCase)
key = uint8(0:31);
sealed = bearlytics.security.sealArtifact(uint8('model bytes'), key);
sealed.ciphertextAndTag(1) = bitxor(sealed.ciphertextAndTag(1), uint8(1));
verifyError(testCase, @() bearlytics.security.openArtifact(sealed, key), ...
    'bearlytics:security:authenticationFailed');
end

function testWrongKeyFailsAuthentication(testCase)
sealed = bearlytics.security.sealArtifact(uint8([1 2 3]), uint8(0:31));
verifyError(testCase, @() bearlytics.security.openArtifact(sealed, uint8(1:32)), ...
    'bearlytics:security:authenticationFailed');
end

function testRejectsInvalidKeyAndEnvelope(testCase)
verifyError(testCase, @() bearlytics.security.sealArtifact(uint8(1), uint8(1:16)), ...
    'MATLAB:sealArtifact:incorrectNumel');
sealed = bearlytics.security.sealArtifact(uint8(1), uint8(0:31));
sealed.version = uint8(2);
verifyError(testCase, @() bearlytics.security.openArtifact(sealed, uint8(0:31)), ...
    'bearlytics:security:sealedFormat');
end

function testRbacAllowsOnlyExplicitPermissions(testCase)
verifyTrue(testCase, bearlytics.security.authorize("viewer", "predictions:read"));
verifyFalse(testCase, bearlytics.security.authorize("viewer", "predictions:run"));
verifyTrue(testCase, bearlytics.security.authorize("analyst", "predictions:run"));
verifyFalse(testCase, bearlytics.security.authorize("analyst", "models:publish"));
verifyTrue(testCase, bearlytics.security.authorize("model_maintainer", "models:publish"));
verifyFalse(testCase, bearlytics.security.authorize("unknown", "users:manage"));
verifyFalse(testCase, bearlytics.security.authorize("security_admin", "models:publish"));
end

function testRbacRejectsMalformedRequests(testCase)
verifyFalse(testCase, bearlytics.security.authorize(["viewer", "analyst"], "predictions:read"));
verifyFalse(testCase, bearlytics.security.authorize("viewer", ""));
verifyFalse(testCase, bearlytics.security.authorize("viewer", "admin:*"));
end
