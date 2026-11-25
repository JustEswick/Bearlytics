function run_eda_multi()
%RUN_EDA_MULTI Reproduce las correlaciones y el PCA de Learning_set.
%   Sin entradas. Escribe figuras y tablas en results/eda_multi.
%   Supone que EDA/Uni produjo la tabla de características por snapshot.

scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(fileparts(scriptDir));
input = readtable(fullfile(repoRoot, 'results', 'eda_uni_features.csv'), ...
    'TextType', 'string');
learning = sortrows(input(input.partition == "Learning_set", :), ...
    {'bearing', 'snapshotIndex'});
bearings = unique(learning.bearing);
expected = ["Bearing1_1"; "Bearing1_2"; "Bearing2_1"; "Bearing2_2"; ...
    "Bearing3_1"; "Bearing3_2"];
assert(isequal(bearings, expected), 'La cobertura de Learning_set es inesperada.');
for bearingName = bearings'
    exportBearingResults(scriptDir, bearingName);
end

features = ["rmsH", "rmsV", "kurtosisH", "kurtosisV", ...
    "crestFactorH", "crestFactorV", "skewnessH", "skewnessV"];
values = learning{:, features};
validateattributes(values, {'numeric'}, {'finite', 'real', 'nonempty'});
scales = std(values, 0, 1);
assert(all(scales > 0), 'El PCA requiere variación en cada característica.');
standardized = (values - mean(values, 1)) ./ scales;
[~, singularValues, loadings] = svd(standardized, 'econ');
scores = standardized * loadings;
variance = diag(singularValues) .^ 2;
explained = 100 * variance / sum(variance);
if sum(loadings(1:2, 1)) < 0
    loadings(:, 1) = -loadings(:, 1);
    scores(:, 1) = -scores(:, 1);
end
outputDir = fullfile(repoRoot, 'results', 'eda_multi');
loadingsTable = array2table(loadings, 'VariableNames', "PC" + (1:numel(features)));
loadingsTable = addvars(loadingsTable, features', 'Before', 1, 'NewVariableNames', 'feature');
writetable(loadingsTable, fullfile(outputDir, 'pca_loadings.csv'));
writetable(table((1:numel(explained))', explained, ...
    'VariableNames', {'component', 'explainedPercent'}), ...
    fullfile(outputDir, 'pca_explained.csv'));

condition = zeros(size(bearings));
pc1TimeRho = zeros(size(bearings));
earlyRmsH = zeros(size(bearings));
lateRmsH = zeros(size(bearings));
fig = figure('Theme', 'light', 'Visible', 'off', 'Position', [100 100 1050 650]);
cleanup = onCleanup(@() close(fig));
layout = tiledlayout(fig, 2, 3, 'TileSpacing', 'compact');
for k = 1:numel(bearings)
    rows = learning.bearing == bearings(k);
    trace = learning(rows, :);
    condition(k) = trace.condition(1);
    segmentSize = max(1, floor(height(trace) / 10));
    earlyRmsH(k) = median(trace.rmsH(1:segmentSize));
    lateRmsH(k) = median(trace.rmsH(end-segmentSize+1:end));
    pc1Rank = rankWithTies(scores(rows, 1));
    assert(all(diff(trace.elapsedHours) > 0), 'El tiempo debe crecer por rodamiento.');
    correlation = corrcoef((1:height(trace))', pc1Rank);
    pc1TimeRho(k) = correlation(1, 2);
    ax = nexttile(layout);
    plot(ax, trace.elapsedHours, scores(rows, 1));
    title(ax, bearings(k), 'Interpreter', 'none');
    xlabel(ax, 'Tiempo transcurrido (h)');
    ylabel(ax, 'PC1 (adimensional)');
    grid(ax, 'on');
end
summary = table(bearings, condition, earlyRmsH, lateRmsH, pc1TimeRho, ...
    'VariableNames', {'bearing', 'condition', 'earlyRmsH', 'lateRmsH', 'pc1TimeRho'});
writetable(summary, fullfile(outputDir, 'bearing_summary.csv'));
exportgraphics(fig, fullfile(outputDir, 'pca_pc1_trajectories.png'), 'Resolution', 150);
disp(summary);
disp(loadingsTable(:, 1:3));
fprintf('PC1 y PC2 explican %.2f y %.2f por ciento.\n', explained(1:2));
end

function ranks = rankWithTies(values)
% Asigna a cada empate la media de sus posiciones en el orden ascendente.
[sorted, order] = sort(values);
[~, ~, groups] = unique(sorted);
ranks = zeros(size(values));
groupRanks = accumarray(groups, (1:numel(values))', [], @mean);
ranks(order) = groupRanks(groups);
end

function exportBearingResults(scriptDir, bearingName)
% Conserva todas las matrices y las figuras necesarias para el cierre.
exportSpearmanFigure = bearingName == "Bearing1_1";
run(fullfile(scriptDir, 'generador_matriz.m'));
if bearingName == "Bearing2_1"
    run(fullfile(scriptDir, 'dispercion.m'));
end
end
