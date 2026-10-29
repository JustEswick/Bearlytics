%TEST_EDA_UNI Pruebas de carga de snapshots y features univariadas.
%   Ejecutar desde la raíz del repositorio con:
%       matlab -batch "run('EDA/Uni/test_eda_uni.m')"
%
%   El script recorre los casos de prueba y termina imprimiendo "TODO OK"
%   si todos pasan. Si algún caso falla, lanza un error con el detalle.

uniDir = fileparts(mfilename('fullpath'));
edaDir = fileparts(uniDir);
repoRoot = fileparts(edaDir);

pathEntries = strsplit(path, pathsep);
if ~any(strcmpi(pathEntries, repoRoot))
    addpath(repoRoot);
end

datasetDir = fullfile(repoRoot, '10. FEMTO Bearing');
if ~isfolder(datasetDir)
    error('testEdaUni:datasetMissing', ...
        'No se encuentra el dataset FEMTO en: %s', datasetDir);
end

commaCsvPath = fullfile(datasetDir, 'Learning_set', 'Bearing1_1', 'acc_00001.csv');
semicolonCsvPath = fullfile(datasetDir, 'Full_Test_Set', 'Bearing1_4', 'acc_00001.csv');
temperatureCsvPath = fullfile(datasetDir, 'Learning_set', 'Bearing1_1', 'temp_00001.csv');

fprintf('== Pruebas EDA univariada ==\n');

% Caso 1: seno de amplitud unidad con 10 ciclos exactos a 100 Hz.
fprintf('Caso 1: seno de amplitud 1 -> RMS, crest factor, kurtosis y skewness.\n');
t = (0:2559)' / 25600;
xSine = sin(2 * pi * 100 * t);
sineFeatures = bearlytics.computeTimeFeatures(xSine);
assertClose(sineFeatures.rms, 1 / sqrt(2), 1e-6, 'RMS del seno');
assertClose(sineFeatures.crestFactor, sqrt(2), 1e-6, 'crest factor del seno');
assertClose(sineFeatures.kurtosis, 1.5, 1e-3, 'kurtosis del seno');
assertClose(sineFeatures.skewness, 0, 1e-3, 'skewness del seno');
rowFeatures = bearlytics.computeTimeFeatures(xSine');
assertClose(rowFeatures.rms, sineFeatures.rms, 1e-12, 'RMS con vector fila');

% Caso 1b: el offset de continua no debe alterar las features (centrado).
fprintf('Caso 1b: seno con offset de continua -> centrado.\n');
xOffset = 5 + xSine;
offsetFeatures = bearlytics.computeTimeFeatures(xOffset);
assertClose(offsetFeatures.rms, 1 / sqrt(2), 1e-6, 'RMS del seno con offset');
assertClose(offsetFeatures.crestFactor, sqrt(2), 1e-6, ...
    'crest factor del seno con offset');

% Caso 2: ruido gaussiano reproducible.
fprintf('Caso 2: ruido gaussiano (rng 42) -> kurtosis y skewness.\n');
rng(42, 'twister');
xNoise = randn(2560, 1);
noiseFeatures = bearlytics.computeTimeFeatures(xNoise);
% Tolerancias de ~2 sigma para N=2560 (sigma_kurtosis ~ 0.097,
% sigma_skewness ~ 0.048).
assertClose(noiseFeatures.kurtosis, 3, 0.2, 'kurtosis del ruido');
assertClose(noiseFeatures.skewness, 0, 0.1, 'skewness del ruido');

% Caso 3: snapshot real con delimitador coma.
fprintf('Caso 3: snapshot real con delimitador coma.\n');
[signalH, signalV] = bearlytics.loadAccSnapshot(commaCsvPath);
assertSignal(signalH, 2560, 'signalH (coma)');
assertSignal(signalV, 2560, 'signalV (coma)');
assertClose(signalH(1), 0.552, 1e-12, 'primer valor de H (coma)');
assertClose(signalV(1), -0.146, 1e-12, 'primer valor de V (coma)');

% Caso 4: snapshot real con delimitador punto y coma.
fprintf('Caso 4: snapshot real con delimitador punto y coma.\n');
[signalH, signalV] = bearlytics.loadAccSnapshot(semicolonCsvPath);
assertSignal(signalH, 2560, 'signalH (punto y coma)');
assertSignal(signalV, 2560, 'signalV (punto y coma)');
assertClose(signalH(1), 0.065, 1e-12, 'primer valor de H (punto y coma)');
assertClose(signalV(1), -0.058, 1e-12, 'primer valor de V (punto y coma)');

% Caso 5: un fichero de temperatura no es un snapshot de aceleración.
fprintf('Caso 5: temp_00001.csv rechazado por no ser 2560x6.\n');
assertError(@() bearlytics.loadAccSnapshot(temperatureCsvPath), ...
    'bearlytics:loadAccSnapshot:invalidShape', ...
    'carga de temp_00001.csv');

% Caso 6: una señal constante no tiene RMS utilizable.
fprintf('Caso 6: señales constantes -> error explícito por RMS cero.\n');
assertError(@() bearlytics.computeTimeFeatures(ones(2560, 1)), ...
    'bearlytics:computeTimeFeatures:zeroRms', ...
    'features de una señal constante (1)');
assertError(@() bearlytics.computeTimeFeatures(repmat(0.1, 2560, 1)), ...
    'bearlytics:computeTimeFeatures:zeroRms', ...
    'features de una señal constante (0.1)');

% Caso 7: entradas vacías o con valores no finitos.
fprintf('Caso 7: entradas vacías o no finitas -> error.\n');
assertError(@() bearlytics.computeTimeFeatures([]), ...
    'bearlytics:computeTimeFeatures:emptyInput', ...
    'features de una señal vacía');
assertError(@() bearlytics.computeTimeFeatures([1; NaN; 3]), ...
    'bearlytics:computeTimeFeatures:nonFiniteInput', ...
    'features de una señal con NaN');
assertError(@() bearlytics.computeTimeFeatures([1; Inf; 3]), ...
    'bearlytics:computeTimeFeatures:nonFiniteInput', ...
    'features de una señal con Inf');

fprintf('TODO OK\n');

function assertClose(actual, expected, tolerance, label)
    if ~isnumeric(actual) || ~isscalar(actual) || ~isfinite(actual)
        error('testEdaUni:invalidValue', '%s: el valor no es un escalar finito.', label);
    end
    if abs(actual - expected) > tolerance
        error('testEdaUni:tolerance', ...
            '%s: esperado %.12g, obtenido %.12g (tolerancia %.3g).', ...
            label, expected, actual, tolerance);
    end
end

function assertSignal(signal, expectedLength, label)
    if ~isa(signal, 'double')
        error('testEdaUni:notDouble', '%s: se esperaba un vector double.', label);
    end
    if ~iscolumn(signal)
        error('testEdaUni:notColumn', '%s: se esperaba un vector columna.', label);
    end
    if numel(signal) ~= expectedLength
        error('testEdaUni:length', '%s: se esperaban %d muestras y hay %d.', ...
            label, expectedLength, numel(signal));
    end
    if any(~isfinite(signal))
        error('testEdaUni:nonFinite', '%s: contiene NaN o Inf.', label);
    end
end

function assertError(fn, expectedIdentifier, label)
    didError = false;
    actualIdentifier = '';
    actualMessage = '';
    try
        fn();
    catch err
        didError = true;
        actualIdentifier = err.identifier;
        actualMessage = err.message;
    end
    if ~didError
        error('testEdaUni:expectedError', ...
            '%s: se esperaba el error "%s" y no se produjo.', ...
            label, expectedIdentifier);
    end
    if ~strcmp(actualIdentifier, expectedIdentifier)
        error('testEdaUni:wrongError', ...
            '%s: se esperaba el identificador "%s", pero se obtuvo "%s" (%s).', ...
            label, expectedIdentifier, actualIdentifier, actualMessage);
    end
end
