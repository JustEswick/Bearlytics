function [payload, header] = encodeModelArtifact(artifact)
%ENCODEMODELARTIFACT Serializa un artefacto de modelo a bytes UTF-8 (JSON).
%   INPUTS:
%       artifact - struct con el esquema de bearlytics.model.decodeModelArtifact
%                  (header, predictorNames, windowSnapshots, scaler, model,
%                  training, metrics). Se valida antes de serializar.
%   OUTPUTS:
%       payload - uint8 columna: JSON UTF-8 del artefacto completo. Es lo que
%                 se cifra con bearlytics.security.sealArtifact.
%       header  - uint8 columna: JSON UTF-8 solo de artifact.header
%                 (schemaVersion, modelId, modelVersion, modelType). Pensado
%                 para autenticarse como AAD en AES-GCM; al abrir, el header
%                 del payload debe coincidir con este.
%   SUPUESTOS: JSON en lugar de MAT para que el formato sea legible, estable
%   entre versiones de MATLAB y no ejecute código al cargarse. No cifra ni
%   firma: eso corresponde a +bearlytics/+security.

if ~isstruct(artifact) || ~isscalar(artifact) || ~isfield(artifact, 'header')
    error('bearlytics:model:format', 'El artefacto debe ser un struct escalar con header.');
end
payload = uint8(unicode2native(jsonencode(artifact), 'UTF-8'))';
% Validar con el mismo decodificador garantiza que encode/decode son inversos.
bearlytics.model.decodeModelArtifact(payload);
header = uint8(unicode2native(jsonencode(artifact.header), 'UTF-8'))';
end
