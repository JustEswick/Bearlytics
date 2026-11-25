function prediction = predictBearing(principal, artifact, folder, names, progress)
%PREDICTBEARING Ejecuta inferencia autorizada para la secuencia de un rodamiento.
%   Devuelve RUL en segundos, tiempo nominal en horas e índice de salud.
arguments
    principal
    artifact
    folder (1, 1) string
    names (:, 1) string
    progress (1, 1) function_handle = @(~, ~) false
end
if ~bearlytics.security.authorizePrincipal(principal, "predictions:run") || ...
        ~bearlytics.security.authorizePrincipal(principal, "predictions:read")
    error('bearlytics:app:denied', 'Sin permiso para ejecutar una predicción.');
end
if isempty(artifact)
    error('bearlytics:app:modelUnavailable', 'No se pudo cargar el modelo aprobado.');
end
features = bearlytics.app.loadBearingFeatures(folder, names, progress);
history = bearlytics.computeCausalHistory(features, artifact.windowSnapshots);
rulSeconds = bearlytics.model.predictRulFromArtifact(artifact, history);
if any(~isfinite(rulSeconds))
    error('bearlytics:app:invalidPrediction', 'No se pudo calcular una estimación válida.');
end
prediction = struct('timeHours', (0:height(history)-1)' * 10 / 3600, ...
    'rulSeconds', rulSeconds, 'healthIndex', bearlytics.computeHealthIndex(history, 60), ...
    'modelHeader', artifact.header);
end
