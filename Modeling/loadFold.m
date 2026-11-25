function fold = loadFold(validationBearing, windowSnapshots, preprocessRoot)
%LOADFOLD Lee y valida un fold generado por PreProcess/run_preprocess.m.
%   INPUTS:
%       validationBearing - rodamiento de validación del fold (p. ej. "Bearing1_2").
%       windowSnapshots   - ventana usada en run_preprocess (por defecto 31).
%       preprocessRoot    - carpeta con las salidas (por defecto
%                           results/preprocess en la raíz del repo).
%   OUTPUT:
%       fold - struct con train, validation y test (tablas con predictores ya
%              escalados), predictorNames (string columna), manifest,
%              directory, validationBearing y windowSnapshots.
%   SUPUESTOS: la carpeta <validationBearing>_w<windowSnapshots> contiene
%   train.csv, validation.csv, test.csv, split_manifest.csv y predictors.csv.
%   Se rechaza el fold si falta algo, si un predictor es metadato o etiqueta,
%   si un rodamiento aparece en más de un split, si el RUL no es (N-i)*10 s o
%   si hay valores no finitos. Los únicos inputs admisibles de un modelo son
%   las columnas de predictorNames.

arguments
    validationBearing (1, 1) string
    windowSnapshots (1, 1) double {mustBeInteger, mustBePositive} = 31
    preprocessRoot (1, 1) string = ""
end
if preprocessRoot == ""
    repoRoot = fileparts(fileparts(mfilename('fullpath')));
    preprocessRoot = string(fullfile(repoRoot, 'results', 'preprocess'));
end
directory = string(fullfile(preprocessRoot, ...
    sprintf('%s_w%d', validationBearing, windowSnapshots)));

requiredFiles = ["train.csv", "validation.csv", "test.csv", ...
    "split_manifest.csv", "predictors.csv"];
for k = 1:numel(requiredFiles)
    if ~isfile(fullfile(directory, requiredFiles(k)))
        error('bearlytics:loadFold:missingFile', ...
            ['Falta %s. Ejecute run_preprocess("%s", %d) desde la raíz ' ...
            'del repo antes de modelar.'], ...
            fullfile(directory, requiredFiles(k)), validationBearing, windowSnapshots);
    end
end

% Lista autorizada de inputs; los metadatos y la etiqueta nunca lo son.
predictorTable = readtable(fullfile(directory, "predictors.csv"), 'TextType', 'string');
if ~ismember('predictor', predictorTable.Properties.VariableNames) || ...
        isempty(predictorTable) || any(ismissing(predictorTable.predictor))
    error('bearlytics:loadFold:predictors', 'predictors.csv no es válido.');
end
predictorNames = predictorTable.predictor(:);
if numel(unique(predictorNames)) ~= numel(predictorNames)
    error('bearlytics:loadFold:predictors', 'predictors.csv tiene nombres repetidos.');
end
reservedNames = ["rulSeconds", "bearing", "partition", "condition", ...
    "snapshotIndex", "elapsedHours", "split", "historyCount"];
if any(ismember(predictorNames, reservedNames))
    error('bearlytics:loadFold:predictorLeak', ...
        'Un predictor coincide con un metadato o con la etiqueta (RUL).');
end

splitNames = ["train", "validation", "test"];
allowedPartitions = struct('train', "Learning_set", ...
    'validation', "Learning_set", 'test', "Full_Test_Set");
data = struct();
for k = 1:numel(splitNames)
    splitName = splitNames(k);
    tbl = readtable(fullfile(directory, splitName + ".csv"), 'TextType', 'string');
    data.(splitName) = checkSplitTable(tbl, splitName, predictorNames, ...
        allowedPartitions.(splitName));
end

% Un rodamiento solo puede pertenecer a un split (evita fuga de identidad).
trainBearings = unique(data.train.bearing);
validationBearings = unique(data.validation.bearing);
testBearings = unique(data.test.bearing);
if ~isempty(intersect(trainBearings, validationBearings)) || ...
        ~isempty(intersect(trainBearings, testBearings)) || ...
        ~isempty(intersect(validationBearings, testBearings))
    error('bearlytics:loadFold:leakage', ...
        'Un rodamiento aparece en más de un split del fold.');
end
if ~isscalar(validationBearings) || validationBearings ~= validationBearing
    error('bearlytics:loadFold:validationIdentity', ...
        'validation.csv debe contener exactamente el rodamiento %s.', validationBearing);
end

% El manifiesto debe describir los mismos rodamientos y conteos.
manifest = readtable(fullfile(directory, "split_manifest.csv"), 'TextType', 'string');
manifestColumns = {'bearing', 'partition', 'condition', 'split', 'nSnapshots'};
if ~all(ismember(manifestColumns, manifest.Properties.VariableNames))
    error('bearlytics:loadFold:manifest', 'split_manifest.csv no tiene el esquema esperado.');
end
for k = 1:numel(splitNames)
    splitName = splitNames(k);
    inSplit = manifest.split == splitName;
    actualBearings = unique(data.(splitName).bearing);
    if ~isequal(sort(manifest.bearing(inSplit)), sort(actualBearings))
        error('bearlytics:loadFold:manifest', ...
            'El manifiesto no coincide con %s.csv.', splitName);
    end
    for b = 1:numel(actualBearings)
        manifestRow = inSplit & manifest.bearing == actualBearings(b);
        if manifest.nSnapshots(manifestRow) ~= nnz(data.(splitName).bearing == actualBearings(b))
            error('bearlytics:loadFold:manifest', ...
                'El conteo de %s no coincide con %s.csv.', actualBearings(b), splitName);
        end
    end
end

fold = struct('train', data.train, 'validation', data.validation, ...
    'test', data.test, 'predictorNames', predictorNames, 'manifest', manifest, ...
    'directory', directory, 'validationBearing', validationBearing, ...
    'windowSnapshots', windowSnapshots);
end

function tbl = checkSplitTable(tbl, splitName, predictorNames, allowedPartition)
%CHECKSPLITTABLE Valida esquema, identidad, finitud y coherencia del RUL.
metadataNames = ["partition"; "bearing"; "condition"; "snapshotIndex"; ...
    "rulSeconds"; "split"];
required = [metadataNames; predictorNames(:)];
if isempty(tbl) || ~all(ismember(required, string(tbl.Properties.VariableNames)))
    error('bearlytics:loadFold:schema', ...
        '%s.csv no tiene el esquema esperado o está vacío.', splitName);
end
tbl.bearing = string(tbl.bearing);
tbl.partition = string(tbl.partition);
tbl.split = string(tbl.split);
if any(tbl.split ~= splitName)
    error('bearlytics:loadFold:splitLabel', ...
        'La columna split de %s.csv contiene otro valor.', splitName);
end
if any(tbl.partition ~= allowedPartition)
    error('bearlytics:loadFold:partition', ...
        '%s.csv debe contener solo filas de %s.', splitName, allowedPartition);
end
numericNames = [metadataNames(3:5); predictorNames(:)];
values = tbl{:, cellstr(numericNames)};
if ~isnumeric(values) || any(~isfinite(values), 'all')
    error('bearlytics:loadFold:nonFinite', ...
        '%s.csv contiene valores no numéricos, NaN o Inf.', splitName);
end

tbl = sortrows(tbl, {'bearing', 'snapshotIndex'});
bearingNames = unique(tbl.bearing, 'stable');
dt = 10;
for b = 1:numel(bearingNames)
    rows = tbl.bearing == bearingNames(b);
    n = nnz(rows);
    index = tbl.snapshotIndex(rows);
    expectedRul = (n - (1:n)') * dt;
    if ~isequal(index(:), (1:n)') || ...
            max(abs(tbl.rulSeconds(rows) - expectedRul)) > 1e-9
        error('bearlytics:loadFold:rul', ...
            '%s: índices o RUL incoherentes con (N-i)*10 s en %s.csv.', ...
            bearingNames(b), splitName);
    end
end
end
