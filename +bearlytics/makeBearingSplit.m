function manifest = makeBearingSplit(modelTable, validationBearing)
%MAKEBEARINGSPLIT Asigna rodamientos completos a train/validation/test.
%   INPUTS: tabla validada por prepareRulTable y un rodamiento Learning_set.
%   OUTPUT: manifiesto con identidad, partición, condición, split y conteo.
%   SUPUESTOS: validación leave-one-bearing-out; el resto de Learning_set
%   entrena y Full_Test_Set se reserva para test. No hay reparto aleatorio.

arguments
    modelTable table
    validationBearing (1, 1) string = "Bearing1_2"
end
required = {'bearing', 'partition', 'condition', 'snapshotIndex'};
if isempty(modelTable) || ~all(ismember(required, modelTable.Properties.VariableNames))
    error('bearlytics:makeBearingSplit:schema', 'Faltan columnas de identidad.');
end
bearingNames = unique(string(modelTable.bearing));
n = numel(bearingNames);
partition = strings(n, 1);
condition = zeros(n, 1);
split = strings(n, 1);
nSnapshots = zeros(n, 1);
% Una iteración por rodamiento conserva su identidad en una sola fila.
for b = 1:n
    rows = string(modelTable.bearing) == bearingNames(b);
    partitions = unique(string(modelTable.partition(rows)));
    conditions = unique(modelTable.condition(rows));
    if numel(partitions) ~= 1 || numel(conditions) ~= 1
        error('bearlytics:makeBearingSplit:identity', ...
            'Una identidad aparece en varias particiones/condiciones.');
    end
    partition(b) = partitions;
    condition(b) = conditions;
    nSnapshots(b) = nnz(rows);
    if partitions == "Full_Test_Set"
        split(b) = "test";
    elseif partitions == "Learning_set"
        split(b) = "train";
    else
        error('bearlytics:makeBearingSplit:partition', ...
            'Test_set y particiones desconocidas están excluidos.');
    end
end
validationRow = bearingNames == validationBearing;
if nnz(validationRow) ~= 1 || partition(validationRow) ~= "Learning_set"
    error('bearlytics:makeBearingSplit:validation', ...
        'La validación debe ser un rodamiento existente de Learning_set.');
end
split(validationRow) = "validation";
if ~any(split == "train") || ~any(split == "test")
    error('bearlytics:makeBearingSplit:emptySplit', ...
        'Se requiere al menos un rodamiento de entrenamiento y otro de test.');
end
if ~all(ismember(condition(split ~= "train"), condition(split == "train")))
    error('bearlytics:makeBearingSplit:unseenCondition', ...
        'Hay condiciones de validación/test ausentes en entrenamiento.');
end
manifest = table(bearingNames, partition, condition, split, nSnapshots, ...
    'VariableNames', {'bearing', 'partition', 'condition', 'split', 'nSnapshots'});
end
