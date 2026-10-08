%EXPORT_ANALOG_BF_CURVES  Fall 2 der Analog-BF-Studie: die Kurven aus
%   QuantizedMimoMI/qam/results/bf_analog (runQamSweepBfAnalog) in
%   Gearbox-Datenordner uebersetzen.
%
%   Aufruf: in GearboxPHY-MIMO/ einfach
%       setupGearboxPath; export_analog_bf_curves
%
%   ERGEBNIS: data/SE_data_abf_fixedB (K = 0, Rayleigh) und, soweit
%   gerechnet, SE_data_abf_fixedB_K3, _K30, _KInf. Aufbau wie die Ordner
%   aus export_mimo_comparison_curves: Gasts uebrige Kurven aus SE_data,
%   QAM 1x1 und NxN aus demselben Lauf, SNR auf Gesamtleistung, sourceB.
%   SNR-Raster -15:2:25 wie alle Rayleigh-Varianten des BF/MUX-Vergleichs.
%
%   _KInf ist die Kontrolle: reines LOS, die Kurve muss die von
%   SE_data_bfideal_fixedB sein (bis auf Raster und Interpolation).
mimoRoot = fullfile(gearboxphy.paths.root(), '..', 'QuantizedMimoMI');
addpath(mimoRoot); setupPath;
src = fullfile(mimoRoot, 'qam', 'results', 'bf_analog');
assert(isfolder(src), 'export_analog_bf_curves:noSource', ...
    '%s fehlt - erst runQamSweepBfAnalog (QuantizedMimoMI/qam/sweep) ausfuehren.', src);
baseDir = gearboxphy.paths.dataDir('SE_data');

for K = [0 3 30 Inf]
    if K == 0, name = "SE_data_abf_fixedB"; else, name = sprintf("SE_data_abf_fixedB_K%g", K); end
    if isempty(dir(fullfile(src, sprintf('mi_bfanalog_*_K%g.mat', K))))
        fprintf('K = %g: keine Quelldateien, uebersprungen.\n', K);
        continue
    end
    fprintf('\n################ %s ################\n', name);
    o = struct('pattern', 'mi_bfanalog_Nt*_Nr*_M*_B*_K*.mat', 'variant', "fixedB", 'K', K, ...
               'baseDir', baseDir, 'sisoFrom1x1', true, 'snrGrid', -15:2:25);
    exportToGearboxSEData(src, gearboxphy.paths.dataDir(name), o);
end
