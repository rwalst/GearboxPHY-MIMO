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
%     bf_los_digital_ideal,
%     bf_los_digital_dac<k>[_common] runQamSweepBfLosDigitalDac (LOS, ein ADC
%                                   JE Empfangsantenne)
%   ERGEBNIS (data/):
%     SE_data_bfideal_fixedB_dac<k>[_common]   LOS, EIN ADC hinter dem Kombinierer
%     SE_data_bf_fixedB_dac<k>[_common]        Rayleigh
%     SE_data_bflosd_fixedB                    LOS, ADC je Antenne, idealer DAC
%     SE_data_bflosd_fixedB_dac<k>[_common]    LOS, ADC je Antenne
%   Aufbau wie die Ordner aus export_mimo_comparison_curves: Gasts uebrige
%   Kurven aus SE_data, QAM 1x1 und NxN aus demselben Lauf, SNR auf
%   Gesamtleistung, sourceB (ADC) und sourceBdac (DAC). LOS behaelt das
%   Raster der Quelle, Rayleigh wird auf -15:2:25 dB ausgeduennt -- beides
%   wie bei den Ordnern ohne DAC, damit der Vergleich nur den DAC misst.
%
%   DECKELUNG AN DER IDEAL-DAC-KURVE (Entscheidung E4, docs/MIMO_TODO.md):
%   jede DAC-Kurve wird punktweise auf die Kurve MIT idealem DAC derselben
%   (M, N) begrenzt. Quantisierung darf nicht helfen -- ohne die Deckelung
%   liegt die DAC-Kurve stellenweise DARUEBER, weil der Rundungsfehler die
%   Stroeme zufaellig dekorreliert und damit ein Stueck Multiplexgewinn
%   vortaeuscht, das ein Empfaenger mit angepasstem Filter nicht heben kann.
%   Gemessen im Fall bflosd/dac2: 247 von 1056 Punkten lagen darueber, bis
%   0,0209 bit; bei Rayleigh und M >= 64, N >= 4 bis 0,10 bit.
%
%   Jede gedeckelte Datei traegt dacCapRef, dacCapPoints, dacCapMaxBit und
%   dacCapUncovered -- die Deckelung ist damit im Ergebnis nachlesbar und
%   nicht nur hier beschrieben. Fehlt der Referenzordner, wird NICHT still
%   ungedeckelt geschrieben, sondern mit export:noDacCapRef gewarnt.
%   Gerechnet wird sie in +gearboxphy/+data/capDacCurvesAgainstIdeal.m
%   (dort auch die Herleitung), geprueft von tests/+unit/DacCapTest.m.
%
%   Fehlende Quellen werden uebersprungen: der Export laeuft schon nach dem
%   LOS-Lauf und spaeter noch einmal nach dem Rayleigh-Lauf.
mimoRoot = fullfile(gearboxphy.paths.root(), '..', 'QuantizedMimoMI');
addpath(mimoRoot); setupPath;
baseDir = gearboxphy.paths.dataDir('SE_data');
resRoot = fullfile(mimoRoot, 'qam', 'results');

nDone = 0;
% LOS mit einem ADC je Empfangsantenne, IDEALER DAC: die Referenz, gegen die
% die DAC-Stufen desselben Empfaengermodells gemessen werden.
srcI = fullfile(resRoot, 'bf_los_digital_ideal');
if isfolder(srcI) && ~isempty(dir(fullfile(srcI, 'mi_bflosd_Nt*_Nr*_M*_B*.mat')))
    fprintf('\n################ SE_data_bflosd_fixedB ################\n');
    o = struct('pattern', 'mi_bflosd_Nt*_Nr*_M*_B*.mat', 'variant', "fixedB", 'K', 0, ...
               'baseDir', baseDir, 'sisoFrom1x1', true);
    exportToGearboxSEData(srcI, gearboxphy.paths.dataDir("SE_data_bflosd_fixedB"), o);
    nDone = nDone + 1;
end
for k = 0:3
    for suffix = ["" "_common"]
        J = struct( ...
          'src',     {fullfile(resRoot, sprintf('bf_ideal_dac%d%s', k, suffix)), ...
                      fullfile(resRoot, sprintf('bf_rayleigh_dac%d%s', k, suffix)), ...
                      fullfile(resRoot, sprintf('bf_los_digital_dac%d%s', k, suffix))}, ...
          'name',    {sprintf("SE_data_bfideal_fixedB_dac%d%s", k, suffix), ...
                      sprintf("SE_data_bf_fixedB_dac%d%s", k, suffix), ...
                      sprintf("SE_data_bflosd_fixedB_dac%d%s", k, suffix)}, ...
          'pattern', {'mi_bfideal_Nt*_Nr*_M*_B*.mat', 'mi_bf_Nt*_Nr*_M*_B*.mat', 'mi_bflosd_Nt*_Nr*_M*_B*.mat'}, ...
          'grid',    {[], -15:2:25, []}, ...
          'ref',     {"SE_data_bfideal_fixedB", "SE_data_bf_fixedB", "SE_data_bflosd_fixedB"});
        for j = 1:numel(J)
            if ~isfolder(J(j).src) || isempty(dir(fullfile(J(j).src, J(j).pattern)))
                continue
            end
            fprintf('\n################ %s ################\n', J(j).name);
            o = struct('pattern', J(j).pattern, 'variant', "fixedB", 'K', 0, ...
                       'baseDir', baseDir, 'sisoFrom1x1', true);
            if ~isempty(J(j).grid), o.snrGrid = J(j).grid; end
            dst = gearboxphy.paths.dataDir(J(j).name);
            exportToGearboxSEData(J(j).src, dst, o);
            gearboxphy.data.capDacCurvesAgainstIdeal(dst, gearboxphy.paths.dataDir(J(j).ref), J(j).name, J(j).ref);
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

