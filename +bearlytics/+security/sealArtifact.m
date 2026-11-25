function sealed = sealArtifact(plaintext, key)
%SEALARTIFACT Cifra bytes con AES-256-GCM y nonce aleatorio de 96 bits.
%   INPUTS: plaintext (uint8) y key (uint8, 32 bytes), suministrada desde
%   un gestor de secretos por quien llama. No almacena ni deriva claves.
%   OUTPUT: struct versionado con nonce y ciphertext (incluye tag GCM).
%   SUPUESTOS: Java JCE disponible en MATLAB. El nonce se genera con
%   SecureRandom; el llamador debe evitar reutilizar claves y persistir la
%   struct completa. Esta función cifra datos, no autentica usuarios.

validateattributes(plaintext, {'uint8'}, {'vector'}, mfilename, 'plaintext');
validateattributes(key, {'uint8'}, {'vector', 'numel', 32}, mfilename, 'key');

nonce = typecast(java.security.SecureRandom().generateSeed(12), 'uint8');
cipher = javax.crypto.Cipher.getInstance('AES/GCM/NoPadding');
secretKey = javax.crypto.spec.SecretKeySpec(typecast(key(:), 'int8'), 'AES');
parameters = javax.crypto.spec.GCMParameterSpec(128, typecast(nonce(:), 'int8'));
cipher.init(javax.crypto.Cipher.ENCRYPT_MODE, secretKey, parameters);
ciphertextAndTag = typecast(cipher.doFinal(typecast(plaintext(:), 'int8')), 'uint8');

sealed = struct('version', uint8(1), 'algorithm', "AES-256-GCM", ...
    'nonce', nonce(:), 'ciphertextAndTag', ciphertextAndTag(:));
end
