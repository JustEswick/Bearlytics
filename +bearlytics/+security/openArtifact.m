function plaintext = openArtifact(sealed, key, expectedHeaderBytes)
%OPENARTIFACT Descifra y verifica la etiqueta de un artefacto AES-256-GCM.
%   INPUTS: struct producido por bearlytics.security.sealArtifact y la clave
%   uint8 de 32 bytes correspondiente y expectedHeaderBytes (uint8 UTF-8)
%   con la cabecera esperada, serializada de forma determinista desde una
%   allowlist/configuración aprobada que incluya modelId y modelVersion.
%   Nunca derivar expectedHeaderBytes de sealed.headerBytes: ese campo viaja
%   con el artefacto y no es una fuente de confianza. Tras descifrar y
%   decodificar el payload, el llamador debe comprobar que la cabecera
%   decodificada coincide con los bytes AAD esperados.
%   OUTPUT: bytes uint8 autenticados. Formatos o etiquetas inválidos fallan.

validateattributes(key, {'uint8'}, {'vector', 'numel', 32}, mfilename, 'key');
required = {'version', 'algorithm', 'nonce', 'headerBytes', 'ciphertextAndTag'};
if ~isstruct(sealed) || ~isscalar(sealed) || ~all(isfield(sealed, required)) || ...
        sealed.version ~= uint8(2) || sealed.algorithm ~= "AES-256-GCM" || ...
        ~isa(sealed.nonce, 'uint8') || numel(sealed.nonce) ~= 12 || ...
        ~isa(sealed.headerBytes, 'uint8') || isempty(sealed.headerBytes) || ...
        ~isvector(sealed.headerBytes) || ...
        ~isa(sealed.ciphertextAndTag, 'uint8') || numel(sealed.ciphertextAndTag) < 16
    error('bearlytics:security:sealedFormat', 'Formato de artefacto cifrado inválido.');
end
validateattributes(expectedHeaderBytes, {'uint8'}, {'vector', 'nonempty'}, ...
    mfilename, 'expectedHeaderBytes');
if ~isequal(sealed.headerBytes(:), expectedHeaderBytes(:))
    error('bearlytics:security:contextMismatch', ...
        'La cabecera esperada no coincide con la del artefacto.');
end

cipher = javax.crypto.Cipher.getInstance('AES/GCM/NoPadding');
secretKey = javax.crypto.spec.SecretKeySpec(typecast(key(:), 'int8'), 'AES');
parameters = javax.crypto.spec.GCMParameterSpec(128, typecast(sealed.nonce(:), 'int8'));
cipher.init(javax.crypto.Cipher.DECRYPT_MODE, secretKey, parameters);
cipher.updateAAD(typecast(expectedHeaderBytes(:), 'int8'));
try
    plaintext = typecast(cipher.doFinal(typecast(sealed.ciphertextAndTag(:), 'int8')), 'uint8');
catch
    error('bearlytics:security:authenticationFailed', ...
        'No se pudo autenticar el artefacto; clave incorrecta o contenido alterado.');
end
plaintext = plaintext(:);
end
