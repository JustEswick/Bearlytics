%COMPUTETIMEFEATURES Calcula features univariadas de una señal de vibración.
%   Centra la señal y calcula RMS, kurtosis, crest factor y skewness.
%
%   INPUTS:
%       signal - vector numérico (fila o columna) con las muestras
%
%   OUTPUTS:
%       features - struct con los campos:
%           rms         - raíz de la media cuadrática de la señal centrada
%           kurtosis    - kurtosis de la señal centrada
%           crestFactor - max(abs(x)) / rms
%           skewness    - skewness de la señal centrada
%
%   ASSUMPTIONS:
%       La señal no es constante ni nula. Se rechazan las entradas vacías,
%       no vectoriales o con NaN/Inf. Si el RMS es cero o alguna feature no
%       es finita se lanza un error. La señal de entrada no se modifica.

function features = computeTimeFeatures(signal)

arguments
    signal {mustBeNumeric, mustBeReal}
end

if isempty(signal)
    error('bearlytics:computeTimeFeatures:emptyInput', ...
        'La señal está vacía: se requiere al menos una muestra.');
end

if ~isvector(signal)
    error('bearlytics:computeTimeFeatures:notVector', ...
        'La señal debe ser un vector numérico (fila o columna).');
end

signal = double(signal(:));

if any(~isfinite(signal))
    error('bearlytics:computeTimeFeatures:nonFiniteInput', ...
        'La señal contiene NaN o Inf.');
end

% Una señal constante tiene RMS cero tras centrar; se detecta antes de
% centrar para evitar que los residuos de coma flotante la oculten.
if max(signal) == min(signal)
    error('bearlytics:computeTimeFeatures:zeroRms', ...
        'El RMS es cero: la señal es constante (valor %g).', signal(1));
end

x = signal - mean(signal);

rmsValue = sqrt(mean(x .^ 2));
if rmsValue == 0
    error('bearlytics:computeTimeFeatures:zeroRms', ...
        'El RMS es cero: la señal es constante o nula.');
end

kurtosisValue = kurtosis(x);
skewnessValue = skewness(x);
crestFactor = max(abs(x)) / rmsValue;

if ~isfinite(rmsValue) || ~isfinite(kurtosisValue) || ...
        ~isfinite(crestFactor) || ~isfinite(skewnessValue)
    error('bearlytics:computeTimeFeatures:nonFiniteFeature', ...
        'Alguna feature calculada no es finita.');
end

features = struct( ...
    'rms', rmsValue, ...
    'kurtosis', kurtosisValue, ...
    'crestFactor', crestFactor, ...
    'skewness', skewnessValue);
