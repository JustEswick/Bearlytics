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

function testNonceIsFreshPerSeal(testCase)
key = uint8(0:31);
header = uint8('{"schemaVersion":1,"modelId":"test","modelVersion":"1.0.0","modelType":"ridge"}');
plaintext = uint8('same');
a = bearlytics.security.sealArtifact(plaintext, key, header);
b = bearlytics.security.sealArtifact(plaintext, key, header);
verifyNumElements(testCase, a.nonce, 12);
verifyNotEqual(testCase, a.nonce, b.nonce);
verifyNotEqual(testCase, a.ciphertextAndTag, b.ciphertextAndTag);
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
verifyError(testCase, @() bearlytics.security.sealArtifact(uint8(1), uint8(0:31)), ...
    'MATLAB:minrhs');
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

function testAuthorizePrincipalEnforcesTrustedIdentityAndRole(testCase)
principal = struct('authenticated', true, 'subject', "analyst-1", 'role', "analyst");
verifyTrue(testCase, bearlytics.security.authorizePrincipal(principal, "predictions:run"));
verifyFalse(testCase, bearlytics.security.authorizePrincipal(principal, "models:publish"));

unauthenticated = principal;
unauthenticated.authenticated = false;
verifyFalse(testCase, bearlytics.security.authorizePrincipal(unauthenticated, "predictions:read"));

nonLogicalAuthentication = principal;
nonLogicalAuthentication.authenticated = 1;
verifyFalse(testCase, bearlytics.security.authorizePrincipal(nonLogicalAuthentication, "predictions:read"));

blankSubject = principal;
blankSubject.subject = "  ";
verifyFalse(testCase, bearlytics.security.authorizePrincipal(blankSubject, "predictions:read"));

missingRole = rmfield(principal, 'role');
verifyFalse(testCase, bearlytics.security.authorizePrincipal(missingRole, "predictions:read"));

unknownRole = principal;
unknownRole.role = "superuser";
verifyFalse(testCase, bearlytics.security.authorizePrincipal(unknownRole, "predictions:read"));

verifyFalse(testCase, bearlytics.security.authorizePrincipal([principal principal], "predictions:read"));
verifyFalse(testCase, bearlytics.security.authorizePrincipal("analyst", "predictions:read"));
end

function testEquivalentTextRepresentations(testCase)
verifyTrue(testCase, bearlytics.security.isActionAllowed('viewer', "predictions:read"));
verifyTrue(testCase, bearlytics.security.isActionAllowed("viewer", 'predictions:read'));
verifyFalse(testCase, bearlytics.security.isActionAllowed('viewer', 'models:publish'));

principal = struct('authenticated', true, 'subject', 'test-user', 'role', 'viewer');
verifyTrue(testCase, bearlytics.security.authorizePrincipal(principal, 'predictions:read'));
verifyFalse(testCase, bearlytics.security.authorizePrincipal(principal, 'models:publish'));
end

function testRbacRejectsNonScalarTextAndNonText(testCase)
verifyFalse(testCase, bearlytics.security.isActionAllowed(['viewer'; 'viewer'], "predictions:read"));
verifyFalse(testCase, bearlytics.security.isActionAllowed("viewer", {'predictions:read'}));
verifyFalse(testCase, bearlytics.security.isActionAllowed("viewer", string(missing)));
end
