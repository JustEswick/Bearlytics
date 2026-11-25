function [learningTable, testTable, scaler] = finalTrainingTables(fold, predictorNames, learningBearings)
%FINALTRAININGTABLES Tablas del entrenamiento final con los 6 de Learning_set.
%   PreProcess siempre aparta un rodamiento de validación; para el modelo
%   final se reajusta el escalador con los 6 rodamientos de Learning_set a
%   partir de features_unscaled.csv del fold y se aplica a Full_Test_Set.
%
%   INPUTS:
%       fold             - struct de loadFold (se usa directory y test).
%       predictorNames   - string con la lista autorizada de predictores.
%       learningBearings - string con los 6 rodamientos de Learning_set.
%   OUTPUTS:
%       learningTable - filas de Learning_set con predictores escalados.
%       testTable     - filas de Full_Test_Set escaladas con el MISMO scaler,
%                       ordenadas por rodamiento e índice.
%       scaler        - struct de bearlytics.fitFeatureScaler (center, scale,
%                       constantColumns) ajustado solo con Learning_set.
%   SUPUESTOS: features_unscaled.csv contiene todas las particiones sin
%   escalar (salida de run_preprocess). No modifica PreProcess.

unscaledPath = fullfile(fold.directory, "features_unscaled.csv");
if ~isfile(unscaledPath)
    error('bearlytics:finalTrainingTables:unscaledMissing', 'Falta %s.', unscaledPath);
end
unscaled = readtable(unscaledPath, 'TextType', 'string');
learningTable = unscaled(unscaled.partition == "Learning_set", :);
testTable = unscaled(unscaled.partition == "Full_Test_Set", :);
if ~isequal(sort(unique(learningTable.bearing)), sort(learningBearings(:)))
    error('bearlytics:finalTrainingTables:learningSet', ...
        'features_unscaled.csv no reúne exactamente los 6 rodamientos de Learning_set.');
end
if ~isequal(sort(unique(testTable.bearing)), sort(unique(fold.test.bearing))) || ...
        height(testTable) ~= height(fold.test)
    error('bearlytics:finalTrainingTables:testSet', ...
        'Full_Test_Set de features_unscaled.csv no coincide con test.csv del fold.');
end
names = cellstr(predictorNames);
scaler = bearlytics.fitFeatureScaler(double(learningTable{:, names}));
learningTable{:, names} = bearlytics.applyFeatureScaler(double(learningTable{:, names}), scaler);
testTable{:, names} = bearlytics.applyFeatureScaler(double(testTable{:, names}), scaler);
testTable = sortrows(testTable, {'bearing', 'snapshotIndex'});
end
