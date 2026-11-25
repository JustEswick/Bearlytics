function features = loadBearingFeatures(folder, names, progress)
%LOADBEARINGFEATURES Lee capturas consecutivas de un rodamiento sin escribir datos.
%   FOLDER y NAMES provienen de un selector de archivos de una sola carpeta.
%   PROGRESS recibe (procesadas, total) y devuelve true para cancelar.
arguments
    folder (1, 1) string
    names (:, 1) string
    progress (1, 1) function_handle = @(~, ~) false
end

limit = 3000;
count = numel(names);
if count < 1 || count > limit
    error('bearlytics:app:snapshotCount', 'Selecciona entre 1 y 3000 capturas.');
end
indices = zeros(count, 1);
for k = 1:count
    token = regexp(char(names(k)), '^acc_([0-9]{5})\.csv$', 'tokens', 'once');
    if isempty(token)
        error('bearlytics:app:snapshotName', ...
            'El archivo %d debe tener el formato acc_00001.csv.', k);
    end
    indices(k) = str2double(token{1});
end
[indices, order] = sort(indices);
if ~isequal(indices, (1:count)')
    error('bearlytics:app:snapshotSequence', ...
        'Selecciona una secuencia sin huecos ni duplicados que empiece en acc_00001.csv.');
end
names = names(order);
values = zeros(count, 8);
if progress(0, count)
    error('bearlytics:app:cancelled', 'Análisis cancelado.');
end
for k = 1:count
    path = fullfile(folder, names(k));
    file = dir(path);
    if isempty(file) || file.isdir || file.bytes > 2 * 1024^2
        error('bearlytics:app:snapshotRead', 'No se puede leer %s como captura válida.', names(k));
    end
    try
        [h, v] = bearlytics.loadAccSnapshot(path);
        horizontal = bearlytics.computeTimeFeatures(h);
        vertical = bearlytics.computeTimeFeatures(v);
    catch
        error('bearlytics:app:snapshotRead', ...
            '%s debe contener 2560 filas, seis columnas y señales de vibración válidas.', names(k));
    end
    values(k, :) = [horizontal.rms, vertical.rms, horizontal.kurtosis, vertical.kurtosis, ...
        horizontal.crestFactor, vertical.crestFactor, horizontal.skewness, vertical.skewness];
    if progress(k, count)
        error('bearlytics:app:cancelled', 'Análisis cancelado.');
    end
end
features = array2table(values, 'VariableNames', {'rmsH', 'rmsV', ...
    'kurtosisH', 'kurtosisV', 'crestFactorH', 'crestFactorV', 'skewnessH', 'skewnessV'});
end
