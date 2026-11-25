function sealed = sealArtifact(plaintext, key, headerBytes)
%SEALARTIFACT Cifra bytes y autentica la cabecera del modelo con AES-256-GCM.
%   INPUTS: plaintext (uint8), key (uint8, 32 bytes) suministrada desde un
%   gestor de secretos por quien llama y headerBytes (uint8 UTF-8) con la
%   cabecera versionada del modelo serializada de forma determinista.
%   OUTPUT: sobre v2 con nonce, cabecera autenticada y ciphertext/tag.
%   SUPUESTOS: Java JCE disponible en MATLAB. El nonce se genera con
%   SecureRandom; el llamador debe evitar reutilizar claves y persistir la
%   struct completa. Al abrir se debe suministrar la cabecera esperada.
%   Esta función cifra datos, no autentica usuarios ni obtiene claves de KMS.

validateattributes(plaintext, {'uint8'}, {'vector'}, mfilename, 'plaintext');
validateattributes(key, {'uint8'}, {'vector', 'numel', 32}, mfilename, 'key');
validateattributes(headerBytes, {'uint8'}, {'vector', 'nonempty'}, mfilename, 'headerBytes');

random = java.security.SecureRandom();
nonceBytes = zeros(12, 1, 'int8');
random.nextBytes(nonceBytes);
nonce = typecast(nonceBytes, 'uint8');
cipher = javax.crypto.Cipher.getInstance('AES/GCM/NoPadding');
secretKey = javax.crypto.spec.SecretKeySpec(typecast(key(:), 'int8'), 'AES');
parameters = javax.crypto.spec.GCMParameterSpec(128, typecast(nonce(:), 'int8'));
cipher.init(javax.crypto.Cipher.ENCRYPT_MODE, secretKey, parameters);
cipher.updateAAD(typecast(headerBytes(:), 'int8'));
ciphertextAndTag = typecast(cipher.doFinal(typecast(plaintext(:), 'int8')), 'uint8');

sealed = struct('version', uint8(2), 'algorithm', "AES-256-GCM", ...
    'nonce', nonce(:), 'headerBytes', headerBytes(:), ...
    'ciphertextAndTag', ciphertextAndTag(:));
end
