function artifact = loadApprovedModel(sealed, key)
%LOADAPPROVEDMODEL Carga el JSON local fijo o un sobre ya verificado por el servidor.
%   Sin argumentos usa el modelo público de la demo. Con argumentos exige
%   que el llamador ya haya verificado la firma externa y obtenido la clave.
approved = struct('schemaVersion', 1, 'modelId', "bearlytics-ridge-rul", ...
    'modelVersion', "1.0.0", 'modelType', "ridge_rul");
expected = uint8(unicode2native(jsonencode(approved), 'UTF-8'));
if nargin == 0
    root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    modelFile = fullfile(root, 'results', 'modeling_ridge_rul_model.json');
    id = fopen(modelFile, 'rb');
    if id < 0
        error('bearlytics:app:modelUnavailable', 'No se pudo cargar el modelo aprobado.');
    end
    closeFile = onCleanup(@() fclose(id));
    payload = fread(id, 65537, '*uint8');
    if numel(payload) > 65536
        error('bearlytics:app:modelUnavailable', 'No se pudo cargar el modelo aprobado.');
    end
else
    narginchk(2, 2);
    payload = bearlytics.security.openArtifact(sealed, key, expected);
end
artifact = bearlytics.model.decodeModelArtifact(payload);
actual = uint8(unicode2native(jsonencode(artifact.header), 'UTF-8'));
if ~isequal(actual(:), expected(:))
    error('bearlytics:app:modelContext', 'El modelo no coincide con la versión aprobada.');
end
if artifact.windowSnapshots ~= 31 || numel(artifact.predictorNames) ~= 32 || ~isstruct(artifact.training) || ...
        ~isscalar(artifact.training) || ~isfield(artifact.training, 'sourceCommit') || ...
        ~ischar(artifact.training.sourceCommit) || ~isrow(artifact.training.sourceCommit) || ...
        isempty(regexp(char(artifact.training.sourceCommit), '^[a-f0-9]{40}$', 'once')) || ...
        ~isstruct(artifact.metrics) || ~isscalar(artifact.metrics) || ...
        ~all(isfield(artifact.metrics, {'validation', 'test'}))
    error('bearlytics:app:modelMetadata', 'El modelo no contiene los metadatos requeridos.');
end
for split = ["validation", "test"]
    metrics = artifact.metrics.(split);
    if ~isstruct(metrics) || ~isscalar(metrics) || ...
            ~all(isfield(metrics, {'score', 'rmseSeconds', 'maeSeconds'}))
        error('bearlytics:app:modelMetadata', 'El modelo no contiene las métricas requeridas.');
    end
    validateattributes(metrics.score, {'double'}, {'scalar', 'real', 'finite', '>=', 0, '<=', 1});
    validateattributes(metrics.rmseSeconds, {'double'}, {'scalar', 'real', 'finite', 'nonnegative'});
    validateattributes(metrics.maeSeconds, {'double'}, {'scalar', 'real', 'finite', 'nonnegative'});
end
end
