function tests = pruebas_seguridad_integracion
%PRUEBAS_SEGURIDAD_INTEGRACION Verifica el contrato local de seguridad y del modelo.
tests = functiontests(localfunctions);
end

function testPublishedArtifactRoundTrip(testCase)
securityFunction = which('bearlytics.security.openArtifact');
assert(~isempty(securityFunction), 'Agregue la raíz de Bearlytics al path de MATLAB.');
repoRoot = fileparts(fileparts(fileparts(securityFunction)));
artifactFile = fullfile(repoRoot, 'results', 'modeling_ridge_rul_model.json');
artifactText = fileread(artifactFile);
model = bearlytics.model.decodeModelArtifact(utf8Bytes(artifactText));
[payload, header] = bearlytics.model.encodeModelArtifact(model);
expected = expectedHeader("1.0.0");
verifyEqual(testCase, header, expected);

% Clave pública de prueba, exclusiva para datos del repositorio.
key = uint8(0:31);
sealed = bearlytics.security.sealArtifact(payload, key, header);
verifyEqual(testCase, sealed.version, uint8(2));
verifyEqual(testCase, sealed.algorithm, "AES-256-GCM");
verifyNumElements(testCase, sealed.nonce, 12);
verifyNumElements(testCase, sealed.ciphertextAndTag, numel(payload) + 16);
verifyEqual(testCase, sort(fieldnames(sealed)), ...
    sort({'version'; 'algorithm'; 'nonce'; 'headerBytes'; 'ciphertextAndTag'}));

plaintext = bearlytics.security.openArtifact(sealed, key, expected);
verifyEqual(testCase, plaintext, payload);
decoded = bearlytics.model.decodeModelArtifact(plaintext);
[~, actualHeader] = bearlytics.model.encodeModelArtifact(decoded);
verifyEqual(testCase, actualHeader, expected);
sample = array2table(decoded.scaler.center, 'VariableNames', cellstr(decoded.predictorNames));
verifyEqual(testCase, bearlytics.model.predictRulFromArtifact(decoded, sample), ...
    model.model.intercept, 'AbsTol', 1e-10);
fprintf('Integración modelo: JSON publicado, sobre v2, cabecera aprobada e inferencia de referencia.\n');
end

function testUnapprovedModelVersionIsDenied(testCase)
key = uint8(0:31);
header = expectedHeader("1.0.0");
sealed = bearlytics.security.sealArtifact(utf8Bytes("datos de prueba"), key, header);
verifyError(testCase, @() bearlytics.security.openArtifact(sealed, key, expectedHeader("2.0.0")), ...
    'bearlytics:security:contextMismatch');
end

function testCompleteRoleActionMatrix(testCase)
roles = ["viewer", "analyst", "model_maintainer", "security_admin"];
actions = ["predictions:read", "predictions:run", "models:publish", "users:manage", "policies:manage"];
expected = logical([1 0 0 0 0; 1 1 0 0 0; 1 1 1 0 0; 0 0 0 1 1]);
for r = 1:numel(roles)
    principal = struct('authenticated', true, 'subject', "qa-user", 'role', roles(r));
    for a = 1:numel(actions)
        label = roles(r) + " / " + actions(a);
        verifyEqual(testCase, bearlytics.security.isActionAllowed(roles(r), actions(a)), expected(r, a), label);
        verifyEqual(testCase, bearlytics.security.authorizePrincipal(principal, actions(a)), expected(r, a), label);
    end
end
fprintf('RBAC: 20 combinaciones de rol y acción, verificadas por ambas funciones.\n');
end

function testUnauthenticatedAndServerRolesDenied(testCase)
principal = struct('authenticated', false, 'subject', "qa-user", 'role', "model_maintainer");
verifyFalse(testCase, bearlytics.security.authorizePrincipal(principal, "models:publish"));
principal.authenticated = true;
for role = ["Author", "User"]
    principal.role = role;
    verifyFalse(testCase, bearlytics.security.authorizePrincipal(principal, "predictions:read"));
end
end

function testPrincipalCharacterRoleMatchesStringRole(testCase)
principal = struct('authenticated', true, 'subject', 'qa-user', 'role', "viewer");
expected = bearlytics.security.authorizePrincipal(principal, "predictions:read");
verifyTrue(testCase, expected);
principal.role = 'viewer';
verifyEqual(testCase, bearlytics.security.authorizePrincipal(principal, "predictions:read"), expected, ...
    'El validador de principal acepta el rol como char o string.');
end

function header = expectedHeader(modelVersion)
% Los valores de la política de prueba son independientes del sobre.
policy = struct('schemaVersion', 1, 'modelId', "bearlytics-ridge-rul", ...
    'modelVersion', modelVersion, 'modelType', "ridge_rul");
header = utf8Bytes(jsonencode(policy));
end

function bytes = utf8Bytes(value)
bytes = uint8(unicode2native(char(value), 'UTF-8'));
bytes = bytes(:);
end
