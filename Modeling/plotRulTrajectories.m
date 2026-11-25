function plotRulTrajectories(predictions, filePath, figureTitle)
%PLOTRULTRAJECTORIES RUL real frente a predicha, en horas, un panel por rodamiento.
%   INPUTS:
%       predictions - tabla con bearing, snapshotIndex, rulSeconds y
%                     rulPredSeconds (una fila por snapshot).
%       filePath    - ruta del PNG de salida.
%       figureTitle - título general de la figura.
%   SALIDA: escribe el PNG a 150 dpi; la figura no se muestra.
bearingNames = unique(predictions.bearing, 'stable');
nPanels = numel(bearingNames);
nColumns = min(4, nPanels);
nRows = ceil(nPanels / nColumns);
fig = figure('Theme', 'light', 'Visible', 'off', ...
    'Position', [100 100 300 * nColumns, 240 * nRows]);
cleanup = onCleanup(@() close(fig));
layout = tiledlayout(fig, nRows, nColumns, 'TileSpacing', 'compact');
title(layout, figureTitle);
for b = 1:nPanels
    rows = predictions.bearing == bearingNames(b);
    ax = nexttile(layout);
    plot(ax, (predictions.snapshotIndex(rows) - 1) * 10 / 3600, ...
        predictions.rulSeconds(rows) / 3600, 'k-', 'LineWidth', 1.2);
    hold(ax, 'on');
    plot(ax, (predictions.snapshotIndex(rows) - 1) * 10 / 3600, ...
        predictions.rulPredSeconds(rows) / 3600, '-', 'Color', [0.85 0.33 0.10]);
    hold(ax, 'off');
    title(ax, bearingNames(b), 'Interpreter', 'none');
    xlabel(ax, 'Tiempo (h)');
    ylabel(ax, 'RUL (h)');
    grid(ax, 'on');
end
legend(nexttile(layout, 1), {'Real', 'Predicho'}, 'Location', 'northeast');
exportgraphics(fig, filePath, 'Resolution', 150);
end
