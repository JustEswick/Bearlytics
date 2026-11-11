% RMS horizontal frente a RMS vertical.


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
columnasNecesarias = {'bearing', 'snapshotIndex', 'elapsedHours', 'rmsH', 'rmsV'};
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
rodamiento = sortrows(rodamiento, 'snapshotIndex');
columnasNumericas = {'snapshotIndex', 'elapsedHours', 'rmsH', 'rmsV'};
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

% Cada punto es un snapshot; su color representa el tiempo.
fig = figure('Color', 'w', 'Position', [100 100 800 500]);
ax = axes(fig);
scatter(ax, rodamiento.rmsH, rodamiento.rmsV, 12, ...
    rodamiento.elapsedHours, 'filled', ...
    'MarkerFaceAlpha', 0.6, 'MarkerEdgeAlpha', 0.6);
etiquetaX = 'RMS horizontal - unidades originales';
etiquetaY = 'RMS vertical - unidades originales';
xlabel(ax, etiquetaX, 'Interpreter', 'none');
ylabel(ax, etiquetaY, 'Interpreter', 'none');
title(ax, sprintf('%s: %s frente a %s', ...
    nombreRodamiento, etiquetaX, etiquetaY), 'Interpreter', 'none');
colormap(ax, parula(256));
barra = colorbar(ax);
barra.Label.String = 'Tiempo transcurrido (h)';
grid(ax, 'on');
ax.GridAlpha = 0.25;
ax.FontSize = 11;
box(ax, 'on');

if guardarResultados
    archivoFigura = fullfile(carpetaResultados, ...
        sprintf('eda_multi_%s_rmsH_rmsV.png', nombreRodamiento));
    exportgraphics(fig, archivoFigura, 'Resolution', 150);
    fprintf('Figura guardada: %s\n', archivoFigura);
end
fprintf('Finalizado: dispercion.m\n');
