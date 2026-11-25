function plaintext = openArtifact(sealed, key)
%OPENARTIFACT Descifra y verifica la etiqueta de un artefacto AES-256-GCM.
%   INPUTS: struct producido por bearlytics.security.sealArtifact y la clave
%   uint8 de 32 bytes correspondiente. OUTPUT: bytes uint8 autenticados.
%   Cualquier versión, esquema o etiqueta inválidos fallan de forma cerrada.

validateattributes(key, {'uint8'}, {'vector', 'numel', 32}, mfilename, 'key');
required = {'version', 'algorithm', 'nonce', 'ciphertextAndTag'};
if ~isstruct(sealed) || ~isscalar(sealed) || ~all(isfield(sealed, required)) || ...
        sealed.version ~= uint8(1) || sealed.algorithm ~= "AES-256-GCM" || ...
        ~isa(sealed.nonce, 'uint8') || numel(sealed.nonce) ~= 12 || ...
        ~isa(sealed.ciphertextAndTag, 'uint8') || numel(sealed.ciphertextAndTag) < 16
    error('bearlytics:security:sealedFormat', 'Formato de artefacto cifrado inválido.');
end

cipher = javax.crypto.Cipher.getInstance('AES/GCM/NoPadding');
secretKey = javax.crypto.spec.SecretKeySpec(typecast(key(:), 'int8'), 'AES');
parameters = javax.crypto.spec.GCMParameterSpec(128, typecast(sealed.nonce(:), 'int8'));
cipher.init(javax.crypto.Cipher.DECRYPT_MODE, secretKey, parameters);
try
    plaintext = typecast(cipher.doFinal(typecast(sealed.ciphertextAndTag(:), 'int8')), 'uint8');
catch
    error('bearlytics:security:authenticationFailed', ...
        'No se pudo autenticar el artefacto; clave incorrecta o contenido alterado.');
end
plaintext = plaintext(:);
end
