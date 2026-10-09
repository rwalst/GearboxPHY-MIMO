%EXPORT_DBF_DAC_CURVES  Kurven MIT DAC-Quantisierung (digitales Beamforming)
%   aus QuantizedMimoMI in Gearbox-Datenordner uebersetzen, je DAC-Stufe
%   ein Ordner.
%
%   Aufruf: in GearboxPHY-MIMO/ einfach
%       setupGearboxPath; export_dbf_dac_curves
%
%   QUELLEN (QuantizedMimoMI/qam/results/), soweit vorhanden:
%     bf_ideal_dac<k>[_common]      runQamSweepBfIdealDac      (LOS)
%     bf_rayleigh_dac<k>[_common]   runQamSweepBfRayleighDac   (Rayleigh)
%   ERGEBNIS (data/):
%     SE_data_bfideal_fixedB_dac<k>[_common]
%     SE_data_bf_fixedB_dac<k>[_common]
%   Aufbau wie die Ordner aus export_mimo_comparison_curves: Gasts uebrige
%   Kurven aus SE_data, QAM 1x1 und NxN aus demselben Lauf, SNR auf
%   Gesamtleistung, sourceB (ADC) und sourceBdac (DAC). LOS behaelt das
%   Raster der Quelle, Rayleigh wird auf -15:2:25 dB ausgeduennt -- beides
%   wie bei den Ordnern ohne DAC, damit der Vergleich nur den DAC misst.
%
%   Fehlende Quellen werden uebersprungen: der Export laeuft schon nach dem
%   LOS-Lauf und spaeter noch einmal nach dem Rayleigh-Lauf.
mimoRoot = fullfile(gearboxphy.paths.root(), '..', 'QuantizedMimoMI');
addpath(mimoRoot); setupPath;
baseDir = gearboxphy.paths.dataDir('SE_data');
resRoot = fullfile(mimoRoot, 'qam', 'results');

nDone = 0;
for k = 0:3
    for suffix = ["" "_common"]
        J = struct( ...
          'src',     {fullfile(resRoot, sprintf('bf_ideal_dac%d%s', k, suffix)), ...
                      fullfile(resRoot, sprintf('bf_rayleigh_dac%d%s', k, suffix))}, ...
          'name',    {sprintf("SE_data_bfideal_fixedB_dac%d%s", k, suffix), ...
                      sprintf("SE_data_bf_fixedB_dac%d%s", k, suffix)}, ...
          'pattern', {'mi_bfideal_Nt*_Nr*_M*_B*.mat', 'mi_bf_Nt*_Nr*_M*_B*.mat'}, ...
          'grid',    {[], -15:2:25});
        for j = 1:numel(J)
            if ~isfolder(J(j).src) || isempty(dir(fullfile(J(j).src, J(j).pattern)))
                continue
            end
            fprintf('\n################ %s ################\n', J(j).name);
            o = struct('pattern', J(j).pattern, 'variant', "fixedB", 'K', 0, ...
                       'baseDir', baseDir, 'sisoFrom1x1', true);
            if ~isempty(J(j).grid), o.snrGrid = J(j).grid; end
            exportToGearboxSEData(J(j).src, gearboxphy.paths.dataDir(J(j).name), o);
            nDone = nDone + 1;
        end
    end
end
if nDone == 0
    fprintf(['export_dbf_dac_curves: keine Quellen in %s gefunden. Erst ' ...
             'runQamSweepBfIdealDac (und spaeter runQamSweepBfRayleighDac) ausfuehren.\n'], resRoot);
else
    fprintf('\nexport_dbf_dac_curves: %d Ordner geschrieben.\n', nDone);
end
