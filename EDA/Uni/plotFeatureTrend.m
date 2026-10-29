%PLOTFEATURETREND Representa la tendencia temporal de una feature por sensor.
%   Genera una figura con las curvas de los sensores horizontal (H) y
%   vertical (V) a lo largo del tiempo y la exporta a un fichero PNG.
%
%   INPUTS:
%       outPath       - ruta completa del PNG de salida (char o string)
%       bearingName   - nombre del rodamiento (p. ej. 'Bearing1_1')
%       partitionName - partición del dataset ('Learning_set' o 'Full_Test_Set')
%       condition     - condición de operación (1, 2 o 3)
%       tHours        - vector con el tiempo transcurrido en horas
%       valuesH       - vector con la feature del sensor horizontal (H)
%       valuesV       - vector con la feature del sensor vertical (V)
%       featureLabel  - etiqueta legible de la feature para el eje Y
%
%   OUTPUTS:
%       Ninguno. Escribe la figura en outPath y la cierra al terminar.
%
%   ASSUMPTIONS:
%       tHours, valuesH y valuesV tienen la misma longitud, son vectores no
%       vacíos y contienen solo valores finitos. El directorio de salida
%       existe o se crea en esta función. Los datos de entrada no se modifican.

function plotFeatureTrend(outPath, bearingName, partitionName, condition, ...
    tHours, valuesH, valuesV, featureLabel)

arguments
    outPath {mustBeTextScalar}
    bearingName {mustBeTextScalar}
    partitionName {mustBeTextScalar}
    condition (1, 1) double {mustBeReal, mustBeFinite}
    tHours {mustBeNumeric, mustBeReal}
    valuesH {mustBeNumeric, mustBeReal}
    valuesV {mustBeNumeric, mustBeReal}
    featureLabel {mustBeTextScalar}
end

validateattributes(tHours, {'numeric'}, ...
    {'vector', 'nonempty', 'finite'}, mfilename, 'tHours');
validateattributes(valuesH, {'numeric'}, ...
    {'vector', 'nonempty', 'finite'}, mfilename, 'valuesH');
validateattributes(valuesV, {'numeric'}, ...
    {'vector', 'nonempty', 'finite'}, mfilename, 'valuesV');

if numel(tHours) ~= numel(valuesH) || numel(tHours) ~= numel(valuesV)
    error('plotFeatureTrend:lengthMismatch', ...
        'tHours, valuesH y valuesV deben tener la misma longitud (%d, %d y %d).', ...
        numel(tHours), numel(valuesH), numel(valuesV));
end

outDir = fileparts(outPath);
if ~isempty(outDir) && ~isfolder(outDir)
    mkdir(outDir);
end

fig = figure('Visible', 'off');
plot(tHours(:), valuesH(:), '-', ...
    'Color', [0.0000, 0.4470, 0.7410], 'LineWidth', 1.0);
hold on;
plot(tHours(:), valuesV(:), '--', ...
    'Color', [0.8500, 0.3250, 0.0980], 'LineWidth', 1.0);
hold off;
grid on;
xlabel('Tiempo (h)');
ylabel(featureLabel);
title(sprintf('%s - %s (%s, condición %d)', ...
    bearingName, featureLabel, partitionName, condition), ...
    'Interpreter', 'none');
legend({'H', 'V'}, 'Location', 'best');

exportgraphics(fig, outPath, 'Resolution', 150);
close(fig);
