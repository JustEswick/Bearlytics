function healthIndex = computeHealthIndex(historyTable, referenceSnapshots)
%COMPUTEHEALTHINDEX Índice de salud (HI) causal y relativo de UN rodamiento.
%   HI(i) = max( log(rmsHMean(i) / refH(i)), log(rmsVMean(i) / refV(i)) )
%   donde rmsHMean/rmsVMean son las medias retrospectivas de RMS que calcula
%   bearlytics.computeCausalHistory y refH/refV es la media de esas columnas
%   en los primeros referenceSnapshots snapshots del rodamiento. Mientras no
%   se han observado esos snapshots, la referencia usa los disponibles
%   (media expansiva), así que el HI de una fila nunca depende del futuro.
%
%   Sigue la recomendación de EDA/Multi: priorizar RMS H/V y medir el cambio
%   relativo frente a una referencia inicial propia de cada rodamiento, en
%   lugar de un umbral absoluto común a condiciones de operación distintas.
%   HI = 0 significa "igual que al inicio"; HI = log(2) ≈ 0,69, el doble de RMS
%   en el sensor que más ha cambiado.
%
%   INPUTS:
%       historyTable       - tabla de UN rodamiento ordenada por snapshot, con
%                            rmsHMean y rmsVMean SIN escalar (positivos).
%       referenceSnapshots - snapshots de la referencia inicial (por defecto
%                            60, es decir, 10 min a 10 s por snapshot).
%   OUTPUT:
%       healthIndex - vector columna (adimensional), una fila por snapshot.

arguments
    historyTable table
    referenceSnapshots (1, 1) double {mustBeInteger, mustBePositive} = 60
end
required = {'rmsHMean', 'rmsVMean'};
if isempty(historyTable) || ~all(ismember(required, historyTable.Properties.VariableNames))
    error('bearlytics:computeHealthIndex:schema', ...
        'Se requiere una tabla no vacía con rmsHMean y rmsVMean sin escalar.');
end
rms = double(historyTable{:, required});
validateattributes(rms, {'double'}, {'2d', 'real', 'finite', 'positive'}, ...
    mfilename, 'rmsHMean/rmsVMean');

n = size(rms, 1);
count = min((1:n)', referenceSnapshots);
cumulative = cumsum(rms, 1);
reference = cumulative(count, :) ./ count;
healthIndex = max(log(rms ./ reference), [], 2);
end
