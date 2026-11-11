% Kurtosis H frente a crest factor H, y RMS H frente a kurtosis H.


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
columnasNecesarias = {'bearing', 'snapshotIndex', 'elapsedHours', 'kurtosisH', 'crestFactorH', 'rmsH'};
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
columnasNumericas = {'snapshotIndex', 'elapsedHours', 'kurtosisH', 'crestFactorH', 'rmsH'};
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

comparaciones = {
    'kurtosisH', 'crestFactorH', 'Kurtosis H', 'Crest factor H';
    'rmsH', 'kurtosisH', 'RMS H - unidades originales', 'Kurtosis H'
};

for i = 1:size(comparaciones, 1)
    variableX = comparaciones{i, 1};
    variableY = comparaciones{i, 2};
    etiquetaX = comparaciones{i, 3};
    etiquetaY = comparaciones{i, 4};

    fig = figure('Color', 'w', 'Position', [100 100 800 500]);
    ax = axes(fig);
    scatter(ax, rodamiento.(variableX), rodamiento.(variableY), ...
        12, rodamiento.elapsedHours, 'filled', ...
        'MarkerFaceAlpha', 0.6, 'MarkerEdgeAlpha', 0.6);
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
            sprintf('eda_multi_%s_%s_%s.png', ...
                nombreRodamiento, variableX, variableY));
        exportgraphics(fig, archivoFigura, 'Resolution', 150);
        fprintf('Figura guardada: %s\n', archivoFigura);
    end
end
fprintf('Finalizado: diagramdispercion.m\n');
