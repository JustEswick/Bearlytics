function rulPred = predictRulFromArtifact(artifact, featureTable)
%PREDICTRULFROMARTIFACT Predice RUL (segundos) con un artefacto de modelo.
%   INPUTS:
%       artifact     - struct de bearlytics.model.decodeModelArtifact.
%       featureTable - tabla con las columnas artifact.predictorNames SIN
%                      escalar (las 8 features H/V y su historia causal en
%                      artifact.windowSnapshots snapshots, como en
%                      features_unscaled.csv de PreProcess).
%   OUTPUT:
%       rulPred - vector columna de RUL predicho en segundos. NO se recorta.
%   SUPUESTOS: aplica el escalador del artefacto (ajustado con Learning_set)
%   y después el modelo ridge. No calcula features ni comprueba permisos:
%   quien llame debe haber autorizado la acción (sprint 2) y calculado las
%   features con las funciones de +bearlytics.

arguments
    artifact (1, 1) struct
    featureTable table
end
names = artifact.predictorNames(:);
if ~all(ismember(names, string(featureTable.Properties.VariableNames)))
    error('bearlytics:model:schema', ...
        'featureTable no contiene todos los predictores del artefacto.');
end
X = double(featureTable{:, cellstr(names)});
scaled = bearlytics.applyFeatureScaler(X, artifact.scaler);
rulPred = artifact.model.intercept + scaled * artifact.model.coefficients;
end
