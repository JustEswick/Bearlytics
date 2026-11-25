function fpt = detectFirstPredictingTime(healthIndex, threshold, persistence)
%DETECTFIRSTPREDICTINGTIME Primer snapshot en que se declara la degradación.
%   El FPT (first predicting time; Lei et al., 2018) es el primer índice i en
%   que el HI ha superado threshold durante persistence snapshots seguidos
%   (i incluido). Solo usa snapshots hasta i, así que es causal; exigir
%   persistencia evita que un pico aislado dispare la detección.
%
%   INPUTS:
%       healthIndex - vector del HI de UN rodamiento, en orden temporal.
%       threshold   - umbral del HI (escalar finito).
%       persistence - snapshots consecutivos por encima del umbral (>= 1).
%   OUTPUT:
%       fpt - índice (1-based) del snapshot de detección, o NaN si el HI
%             nunca cumple la condición en la secuencia observada.

arguments
    healthIndex (:, 1) double {mustBeReal, mustBeFinite}
    threshold (1, 1) double {mustBeReal, mustBeFinite}
    persistence (1, 1) double {mustBeInteger, mustBePositive}
end
above = double(healthIndex > threshold);
runLength = movsum(above, [persistence - 1, 0], 'Endpoints', 'shrink');
fpt = find(runLength >= persistence, 1);
if isempty(fpt)
    fpt = NaN;
end
end
