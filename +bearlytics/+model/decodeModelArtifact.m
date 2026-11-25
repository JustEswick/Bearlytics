function artifact = decodeModelArtifact(payload)
%DECODEMODELARTIFACT Reconstruye y valida un artefacto de modelo desde bytes.
%   INPUT:
%       payload - uint8 con el JSON UTF-8 de encodeModelArtifact (ya
%                 descifrado y autenticado si venía sellado).
%   OUTPUT:
%       artifact - struct con:
%           header.schemaVersion (1), header.modelId, header.modelVersion,
%           header.modelType ("ridge_rul")
%           predictorNames  (string p x 1, orden de las columnas)
%           windowSnapshots (ventana de historia causal)
%           scaler.center, scaler.scale (1 x p, ajustados con Learning_set)
%           model.intercept (s), model.coefficients (p x 1), model.alpha,
%           model.lambda
%           training (rodamientos, filas, commit de origen, fecha UTC)
%           metrics  (score PHM 2012, RMSE y MAE de validación y test)
%   Falla de forma cerrada ante cualquier campo ausente, tipo inesperado,
%   dimensiones incoherentes o valores no finitos.

validateattributes(payload, {'uint8'}, {'vector', 'nonempty'}, mfilename, 'payload');
try
    artifact = jsondecode(native2unicode(payload(:)', 'UTF-8'));
catch
    error('bearlytics:model:format', 'El artefacto no es JSON UTF-8 válido.');
end
required = {'header', 'predictorNames', 'windowSnapshots', 'scaler', ...
    'model', 'training', 'metrics'};
if ~isstruct(artifact) || ~isscalar(artifact) || ~all(isfield(artifact, required))
    error('bearlytics:model:format', 'Faltan campos de primer nivel en el artefacto.');
end
header = artifact.header;
if ~isstruct(header) || ~all(isfield(header, {'schemaVersion', 'modelId', ...
        'modelVersion', 'modelType'})) || ~isequal(header.schemaVersion, 1) || ...
        string(header.modelType) ~= "ridge_rul"
    error('bearlytics:model:version', 'Versión de esquema o tipo de modelo no soportados.');
end
artifact.header.modelId = string(header.modelId);
artifact.header.modelVersion = string(header.modelVersion);
artifact.header.modelType = string(header.modelType);

% jsondecode convierte vectores de un elemento en escalares: se normalizan.
artifact.predictorNames = string(artifact.predictorNames(:));
p = numel(artifact.predictorNames);
if p == 0 || numel(unique(artifact.predictorNames)) ~= p
    error('bearlytics:model:predictors', 'predictorNames vacío o con repetidos.');
end
if ~isstruct(artifact.scaler) || ~all(isfield(artifact.scaler, {'center', 'scale'})) || ...
        ~isstruct(artifact.model) || ...
        ~all(isfield(artifact.model, {'intercept', 'coefficients', 'alpha', 'lambda'}))
    error('bearlytics:model:format', 'Faltan campos del escalador o del modelo.');
end
artifact.scaler.center = double(artifact.scaler.center(:)');
artifact.scaler.scale = double(artifact.scaler.scale(:)');
artifact.model.coefficients = double(artifact.model.coefficients(:));
validateattributes(artifact.scaler.center, {'double'}, {'numel', p, 'finite', 'real'}, ...
    mfilename, 'scaler.center');
validateattributes(artifact.scaler.scale, {'double'}, {'numel', p, 'finite', 'positive'}, ...
    mfilename, 'scaler.scale');
validateattributes(artifact.model.coefficients, {'double'}, {'numel', p, 'finite', 'real'}, ...
    mfilename, 'model.coefficients');
validateattributes(artifact.model.intercept, {'double'}, {'scalar', 'finite', 'real'}, ...
    mfilename, 'model.intercept');
validateattributes(artifact.windowSnapshots, {'double'}, ...
    {'scalar', 'integer', 'positive'}, mfilename, 'windowSnapshots');
end
