function rulPred = predictRidgeRul(model, evalTable)
%PREDICTRIDGERUL Predice RUL (segundos) con un modelo de fitRidgeRul.
%   INPUTS:
%       model     - struct devuelto por fitRidgeRul.
%       evalTable - tabla con las columnas model.predictorNames, escaladas
%                   con el MISMO scaler que se usó para entrenar.
%   OUTPUT:
%       rulPred - vector columna de RUL predicho en segundos. NO se recorta:
%                 puede ser negativo o superar el horizonte observado; el
%                 score PHM 2012 penaliza esos errores tal cual.

arguments
    model (1, 1) struct
    evalTable table
end
if ~all(isfield(model, {'intercept', 'coefficients', 'predictorNames'}))
    error('bearlytics:predictRidgeRul:model', 'El modelo no tiene el formato esperado.');
end
if ~all(ismember(model.predictorNames, string(evalTable.Properties.VariableNames)))
    error('bearlytics:predictRidgeRul:schema', ...
        'evalTable no contiene todos los predictores del modelo.');
end
X = double(evalTable{:, cellstr(model.predictorNames)});
validateattributes(X, {'double'}, {'2d', 'real', 'finite'}, ...
    'predictRidgeRul', 'predictores');
rulPred = model.intercept + X * model.coefficients;
end
