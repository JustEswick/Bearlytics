function [score, snapshotScores] = phm2012Score(rulPred, rulTrue)
%PHM2012SCORE Puntuación asimétrica del IEEE PHM 2012 sobre pares (predicho, real).
%   Definición del challenge (Nectoux et al., 2012), con el error en porcentaje:
%       Er = 100 * (rulTrue - rulPred) ./ rulTrue
%       A  = exp(-log(0.5) * Er / 5)    si Er <= 0   (sobreestimación)
%       A  = exp( log(0.5) * Er / 20)   si Er >  0   (subestimación)
%       score = mean(A), en [0, 1]; 1 equivale a una predicción perfecta.
%   La sobreestimación se penaliza más: A = 0.5 con -5 % de error y también
%   con +20 %. La puntuación se expresa en la escala oficial [0, 1], no en 0-100.
%
%   INPUTS:
%       rulPred - vector de RUL predicho. No se recorta: un valor negativo o
%                 mayor que el real se puntúa tal cual.
%       rulTrue - vector de RUL real, estrictamente positivo, misma longitud.
%   OUTPUTS:
%       score          - promedio de A (escalar en [0, 1]).
%       snapshotScores - vector columna con A para cada par.
%   SUPUESTOS: ambos vectores usan la misma unidad (p. ej. segundos). Con
%   rulTrue = 0 el error relativo no está definido, por eso se rechaza; el
%   filtrado de esas filas lo hace rulMetrics.

validateattributes(rulPred, {'numeric'}, {'vector', 'real', 'finite'}, ...
    'phm2012Score', 'rulPred');
validateattributes(rulTrue, {'numeric'}, {'vector', 'real', 'finite'}, ...
    'phm2012Score', 'rulTrue');
rulPred = double(rulPred(:));
rulTrue = double(rulTrue(:));
if numel(rulPred) ~= numel(rulTrue)
    error('bearlytics:phm2012Score:size', ...
        'rulPred y rulTrue deben tener la misma longitud.');
end
if any(rulTrue <= 0)
    error('bearlytics:phm2012Score:nonPositiveTrue', ...
        'rulTrue debe ser estrictamente positivo; filtre las filas con RUL = 0.');
end

errorPercent = 100 * (rulTrue - rulPred) ./ rulTrue;
snapshotScores = zeros(size(errorPercent));
over = errorPercent <= 0;
snapshotScores(over) = exp(-log(0.5) * errorPercent(over) / 5);
snapshotScores(~over) = exp(log(0.5) * errorPercent(~over) / 20);
score = mean(snapshotScores);
end
