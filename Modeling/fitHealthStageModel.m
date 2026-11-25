function model = fitHealthStageModel(trainTable, params)
%FITHEALTHSTAGEMODEL Ajusta un modelo de RUL por etapas de salud con el HI.
%   Modelo de dos etapas (división en etapas de salud; Lei et al., 2018):
%     - Etapa sana (antes del FPT): la RUL no se puede inferir de la
%       vibración, así que se predice una constante healthyRulSeconds.
%     - Etapa de degradación (desde el FPT): RUL = degradationSeconds menos
%       el tiempo transcurrido desde el FPT, con suelo en 0.
%   Ambas constantes son cuantiles (params.quantile) de train: la RUL de las
%   filas sanas y la RUL en el FPT de cada rodamiento de train. Un cuantil
%   bajo es prudente: el score PHM 2012 castiga más sobreestimar.
%
%   INPUTS:
%       trainTable - filas de train con bearing, snapshotIndex, rulSeconds,
%                    rmsHMean y rmsVMean SIN escalar.
%       params     - struct con threshold, persistence, referenceSnapshots,
%                    quantile (en (0, 1)) y snapshotIntervalSeconds.
%   OUTPUT:
%       model - struct con los parámetros, healthyRulSeconds,
%               degradationSeconds y nDetected (rodamientos de train en los
%               que se detectó el FPT).
%   SUPUESTOS: solo usa train. Si ningún rodamiento de train alcanza el FPT,
%   degradationSeconds = healthyRulSeconds (el modelo queda constante).

arguments
    trainTable table
    params (1, 1) struct
end
required = {'bearing', 'snapshotIndex', 'rulSeconds', 'rmsHMean', 'rmsVMean'};
if ~all(ismember(required, trainTable.Properties.VariableNames))
    error('bearlytics:fitHealthStageModel:schema', ...
        'trainTable debe contener bearing, snapshotIndex, rulSeconds, rmsHMean y rmsVMean.');
end
validateattributes(params.quantile, {'double'}, {'scalar', '>', 0, '<', 1}, ...
    mfilename, 'params.quantile');

bearingNames = unique(string(trainTable.bearing));
healthyRul = cell(numel(bearingNames), 1);
rulAtFpt = nan(numel(bearingNames), 1);
for b = 1:numel(bearingNames)
    trace = sortrows(trainTable(string(trainTable.bearing) == bearingNames(b), :), 'snapshotIndex');
    hi = bearlytics.computeHealthIndex(trace, params.referenceSnapshots);
    fpt = detectFirstPredictingTime(hi, params.threshold, params.persistence);
    if isnan(fpt)
        healthyRul{b} = trace.rulSeconds;
    else
        healthyRul{b} = trace.rulSeconds(1:fpt - 1);
        rulAtFpt(b) = trace.rulSeconds(fpt);
    end
end
healthyRul = vertcat(healthyRul{:});
if isempty(healthyRul)
    healthyRul = trainTable.rulSeconds;
end
healthyRulSeconds = quantile(healthyRul, params.quantile);
detected = ~isnan(rulAtFpt);
if any(detected)
    degradationSeconds = quantile(rulAtFpt(detected), params.quantile);
else
    degradationSeconds = healthyRulSeconds;
end
model = params;
model.healthyRulSeconds = healthyRulSeconds;
model.degradationSeconds = degradationSeconds;
model.nDetected = nnz(detected);
end
