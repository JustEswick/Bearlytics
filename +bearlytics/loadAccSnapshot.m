%LOADACCSNAPSHOT Carga un snapshot de aceleración del dataset FEMTO.
%   Lee un fichero acc_*.csv de 2560 filas y 6 columnas y devuelve las
%   señales de los canales horizontal (columna 5) y vertical (columna 6).
%
%   INPUTS:
%       csvPath - ruta (char o string) al snapshot acc_*.csv
%
%   OUTPUTS:
%       signalH - vector columna double 2560x1 (aceleración horizontal)
%       signalV - vector columna double 2560x1 (aceleración vertical)
%
%   ASSUMPTIONS:
%       El delimitador es ',' o ';' y se detecta en la primera línea.
%       El fichero no tiene cabecera y sus columnas son numéricas.
%       El fichero se abre en modo solo lectura y no se modifica.

function [signalH, signalV] = loadAccSnapshot(csvPath)

arguments
    csvPath {mustBeTextScalar}
end

csvPath = string(csvPath);

expectedRows = 2560;
expectedColumns = 6;
horizontalColumn = 5;
verticalColumn = 6;

if ~isfile(csvPath)
    error('bearlytics:loadAccSnapshot:fileNotFound', ...
        'No existe el fichero: %s', csvPath);
end

fid = fopen(csvPath, 'r');
if fid == -1
    error('bearlytics:loadAccSnapshot:openFailed', ...
        'No se pudo abrir el fichero: %s', csvPath);
end
firstLine = fgetl(fid);
fclose(fid);

if ~ischar(firstLine) || isempty(firstLine)
    error('bearlytics:loadAccSnapshot:emptyFile', ...
        'El fichero está vacío o no se pudo leer su primera línea: %s', csvPath);
end

commaCount = count(firstLine, ',');
semicolonCount = count(firstLine, ';');

if commaCount > semicolonCount
    delimiter = ',';
elseif semicolonCount > commaCount
    delimiter = ';';
else
    error('bearlytics:loadAccSnapshot:unknownDelimiter', ...
        'No se pudo detectar el delimitador ('','' o '';'') en: %s', csvPath);
end

try
    snapshotTable = readtable(csvPath, ...
        'ReadVariableNames', false, ...
        'Delimiter', delimiter);
catch readError
    error('bearlytics:loadAccSnapshot:readFailed', ...
        'No se pudo leer el fichero %s: %s', csvPath, readError.message);
end

[numRows, numColumns] = size(snapshotTable);
if numRows ~= expectedRows || numColumns ~= expectedColumns
    error('bearlytics:loadAccSnapshot:invalidShape', ...
        'Se esperaba un snapshot de %dx%d y se obtuvo %dx%d: %s', ...
        expectedRows, expectedColumns, numRows, numColumns, csvPath);
end

signalH = snapshotTable{:, horizontalColumn};
signalV = snapshotTable{:, verticalColumn};

if ~isnumeric(signalH) || ~isnumeric(signalV)
    error('bearlytics:loadAccSnapshot:nonNumeric', ...
        'Las columnas 5 y 6 deben ser numéricas: %s', csvPath);
end

signalH = double(signalH(:));
signalV = double(signalV(:));

if any(~isfinite(signalH)) || any(~isfinite(signalV))
    error('bearlytics:loadAccSnapshot:nonFinite', ...
        'Las señales de las columnas 5 y 6 contienen NaN o Inf: %s', csvPath);
end
