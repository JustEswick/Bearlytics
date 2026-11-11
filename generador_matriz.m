% Matriz de correlacion de Spearman de las ocho caracteristicas.


nombreRodamiento = "Bearing3_2";
carpetaScript = fileparts(mfilename('fullpath'));
archivoCSV = fullfile(carpetaScript, 'eda_uni_features.csv');
guardarResultados = true;
carpetaResultados = fullfile(carpetaScript, 'results');

if ~isfile(archivoCSV)
    error('Bearlytics:ArchivoNoEncontrado', ...
        'No se encontro el CSV: %s', archivoCSV);
end

datos = readtable(archivoCSV, 'TextType', 'string', ...
    'VariableNamingRule', 'preserve');
columnasNecesarias = {'bearing', 'rmsH', 'rmsV', 'kurtosisH', 'kurtosisV', 'crestFactorH', 'crestFactorV', 'skewnessH', 'skewnessV'};
faltantes = setdiff(columnasNecesarias, datos.Properties.VariableNames);
if ~isempty(faltantes)
    error('Bearlytics:ColumnasFaltantes', ...
        'Faltan columnas: %s', strjoin(faltantes, ', '));
end

rodamiento = datos(string(datos.bearing) == nombreRodamiento, :);
if isempty(rodamiento)
    error('Bearlytics:RodamientoNoEncontrado', ...
        'No se encontraron datos de %s.', nombreRodamiento);
end
columnasNumericas = {'rmsH', 'rmsV', 'kurtosisH', 'kurtosisV', 'crestFactorH', 'crestFactorV', 'skewnessH', 'skewnessV'};
for k = 1:numel(columnasNumericas)
    if ~isnumeric(rodamiento.(columnasNumericas{k}))
        error('Bearlytics:ColumnaNoNumerica', ...
            'La columna %s debe ser numerica.', columnasNumericas{k});
    end
end
if guardarResultados && ~isfolder(carpetaResultados)
    mkdir(carpetaResultados);
end
fprintf('Rodamiento: %s | Snapshots seleccionados: %d\n', ...
    nombreRodamiento, height(rodamiento));

% Spearman calculado con funciones basicas de MATLAB; sin toolbox.
columnas = columnasNumericas;
X = rodamiento{:, columnas};

% Pandas omite faltantes por pareja. Se conserva ese criterio aqui.
% Un valor infinito se trata como faltante; se informa si ocurre.
infinito = isinf(X);
if any(infinito(:))
    warning('Bearlytics:Infinitos', ...
        '%d valores infinitos se trataran como faltantes.', nnz(infinito));
    X(infinito) = NaN;
end
matriz = spearmanPorParejas(X);

% Redondear solo para mostrar: el CSV conserva los coeficientes completos.
tablaMatriz = array2table(matriz, 'VariableNames', columnas, ...
    'RowNames', columnas);
disp(array2table(round(matriz, 2), 'VariableNames', columnas, ...
    'RowNames', columnas));

fig = figure('Color', 'w', 'Position', [100 100 1000 800]);
ax = axes(fig, 'Position', [0.15 0.23 0.70 0.68]);
img = imagesc(ax, matriz, [-1 1]);
% Las correlaciones indefinidas quedan como celdas grises, no como ceros.
img.AlphaData = ~isnan(matriz);
ax.Color = [0.90 0.90 0.90];
axis(ax, 'image');
ax.XTick = 1:numel(columnas);
ax.YTick = 1:numel(columnas);
ax.XTickLabel = columnas;
ax.YTickLabel = columnas;
ax.TickLabelInterpreter = 'none';
ax.XTickLabelRotation = 90;
ax.FontSize = 11;

% Paleta divergente: azul negativo, blanco en cero y rojo positivo.
% Es una aproximacion visual; no reproduce exactamente coolwarm.
mapa = interp1([0 0.5 1], ...
    [0.23 0.30 0.75; 1 1 1; 0.71 0.02 0.15], linspace(0, 1, 257));
colormap(ax, mapa);
colorbar(ax);
title(ax, sprintf('Correlacion de Spearman - %s', nombreRodamiento), ...
    'Interpreter', 'none');
for fila = 1:numel(columnas)
    for columna = 1:numel(columnas)
        valor = matriz(fila, columna);
        colorTexto = [0 0 0];
        if isnan(valor)
            etiqueta = 'NaN';
        else
            etiqueta = sprintf('%.2f', valor);
            if abs(valor) > 0.65
                colorTexto = [1 1 1];
            end
        end
        text(ax, columna, fila, etiqueta, ...
            'HorizontalAlignment', 'center', 'Color', colorTexto, ...
            'FontSize', 10, 'Interpreter', 'none');
    end
end

if guardarResultados
    archivoFigura = fullfile(carpetaResultados, ...
        sprintf('eda_multi_%s_spearman.png', nombreRodamiento));
    archivoMatriz = fullfile(carpetaResultados, ...
        sprintf('eda_multi_%s_spearman.csv', nombreRodamiento));
    exportgraphics(fig, archivoFigura, 'Resolution', 150);
    writetable(tablaMatriz, archivoMatriz, 'WriteRowNames', true);
    fprintf('Figura guardada: %s\n', archivoFigura);
    fprintf('Matriz guardada: %s\n', archivoMatriz);
end
fprintf('Finalizado: %s.m\n', mfilename);

% Funciones locales. Mantenerlas al final del archivo.
function R = spearmanPorParejas(X)
    % Cada pareja utiliza solo las filas validas en esas dos columnas.
    % Los rangos se recalculan despues de seleccionar dichas filas.
    % Esto conserva el criterio pairwise del script original en Pandas.
    numeroVariables = size(X, 2);
    R = NaN(numeroVariables, numeroVariables);
    for i = 1:numeroVariables
        for j = i:numeroVariables
            validas = ~isnan(X(:, i)) & ~isnan(X(:, j));
            if nnz(validas) < 2
                continue;
            end
            rangoX = rangosConEmpates(X(validas, i));
            rangoY = rangosConEmpates(X(validas, j));
            centradoX = rangoX - mean(rangoX);
            centradoY = rangoY - mean(rangoY);
            normaX = sqrt(sum(centradoX.^2));
            normaY = sqrt(sum(centradoY.^2));
            % Una columna constante tiene correlacion indefinida (NaN).
            if normaX == 0 || normaY == 0
                continue;
            end
            rho = sum((centradoX / normaX) .* (centradoY / normaY));
            % Evitar pequenos desbordamientos por redondeo numerico.
            rho = max(-1, min(1, rho));
            if i == j
                rho = 1;
            end
            R(i, j) = rho;
            R(j, i) = rho;
        end
    end
end

function rangos = rangosConEmpates(valores)
    % Los valores empatados reciben el promedio de sus posiciones.
    % Ejemplo: [10; 20; 20; 30] -> [1; 2.5; 2.5; 4].
    valores = valores(:);
    [ordenados, orden] = sort(valores);
    n = numel(ordenados);
    rangos = zeros(n, 1);
    inicio = 1;
    while inicio <= n
        fin = inicio;
        while fin < n && ordenados(fin + 1) == ordenados(inicio)
            fin = fin + 1;
        end
        rangos(orden(inicio:fin)) = (inicio + fin) / 2;
        inicio = fin + 1;
    end
end
