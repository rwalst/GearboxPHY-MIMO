%EXPORT_RANK1_GEOMETRY_CURVES  Die zwei neuen Rang-1-Kurvenfamilien aus
%   QuantizedMimoMI in Gearbox-Datenordner uebersetzen (studies/rank1_geometry).
%
%   Aufruf: in GearboxPHY-MIMO/ einfach
%       setupGearboxPath; export_rank1_geometry_curves
%   Vorher in QuantizedMimoMI (Branch rang1-geometrie oder spaeter main):
%       validateRank1Geometry, runQamSweepBfRank1Broadside, runQamSweepMuxRank1Angles
%
%   QUELLEN (QuantizedMimoMI/qam/results/), soweit vorhanden:
%     bf_rank1_bs_ideal, _dac0, _dac0_common   Option A, digitales BF broadside
%     rule_mux_rank1_angles                    Option B, MUX ueber 32 Richtungen
%   ERGEBNIS (data/):
%     SE_data_bfr1b_fixedB                     digitales BF, Rang 1 broadside, idealer DAC
%     SE_data_bfr1b_fixedB_dac0[_common]       dasselbe mit DAC-Stufe +0 (dort exakt),
%                                              an der Ideal-Kurve gedeckelt (E4)
%     SE_data_mux_scaledB_r1ang                MUX scaledB, Rang 1 ueber 32 Richtungen, N <= 4
%
%   NUR DIESE ORDNER. Die Exporte export_mimo_comparison_curves und
%   export_dbf_dac_curves bleiben unberuehrt -- ein Neu-Export dort wuerde
%   vorhandene Ordner neu schreiben, und das soll eine Sensitivitaetsstudie
%   nicht ausloesen.
%
%   Raster wie die Geschwister: MUX auf -15:2:25 dB (wie mux_scaledB_KInf),
%   BF auf dem Quellraster (wie bflosd). Die Deckelung an der
%   Alphabetgrenze (E12) macht exportToGearboxSEData selbst.
mimoRoot = fullfile(gearboxphy.paths.root(), '..', 'QuantizedMimoMI');
addpath(mimoRoot); setupPath;
baseDir = gearboxphy.paths.dataDir('SE_data');
resRoot = fullfile(mimoRoot, 'qam', 'results');
nDone = 0;

% ---- Option A: digitales BF, Rang 1 broadside ---------------------------
srcI = fullfile(resRoot, 'bf_rank1_bs_ideal');
if isfolder(srcI) && ~isempty(dir(fullfile(srcI, 'mi_bfr1b_Nt*_Nr*_M*_B*.mat')))
    fprintf('\n################ SE_data_bfr1b_fixedB ################\n');
    o = struct('pattern', 'mi_bfr1b_Nt*_Nr*_M*_B*.mat', 'variant', "fixedB", 'K', 0, ...
               'baseDir', baseDir, 'sisoFrom1x1', true);
    ref = "SE_data_bfr1b_fixedB";
    exportToGearboxSEData(srcI, gearboxphy.paths.dataDir(ref), o);
    nDone = nDone + 1;
    for suffix = ["" "_common"]
        src = fullfile(resRoot, "bf_rank1_bs_dac0" + suffix);
        if ~isfolder(src) || isempty(dir(fullfile(src, 'mi_bfr1b_Nt*_Nr*_M*_B*.mat')))
            warning('export_rank1:noDac', '%s fehlt -- run_dbf_dac_distance verlangt die Stufenordner.', src);
            continue
        end
        name = ref + "_dac0" + suffix;
        fprintf('\n################ %s ################\n', name);
        dst = gearboxphy.paths.dataDir(name);
        exportToGearboxSEData(src, dst, o);
        gearboxphy.data.capDacCurvesAgainstIdeal(dst, gearboxphy.paths.dataDir(ref), name, ref);
        nDone = nDone + 1;
    end
else
    fprintf('Option A: %s fehlt -- erst runQamSweepBfRank1Broadside.\n', srcI);
end

% ---- Option B: MUX, Rang 1 ueber 32 Richtungen ---------------------------
srcM = fullfile(resRoot, 'rule_mux_rank1_angles');
if isfolder(srcM) && ~isempty(dir(fullfile(srcM, 'mi_Nt*_Nr*_M*_B*_KInf.mat')))
    name = "SE_data_mux_scaledB_r1ang";
    fprintf('\n################ %s ################\n', name);
    o = struct('pattern', 'mi_Nt*_Nr*_M*_B*_KInf.mat', 'variant', "scaledB", 'K', Inf, ...
               'baseDir', baseDir, 'sisoFrom1x1', true, 'snrGrid', -15:2:25);
    exportToGearboxSEData(srcM, gearboxphy.paths.dataDir(name), o);
    nDone = nDone + 1;
else
    fprintf('Option B: %s fehlt -- erst runQamSweepMuxRank1Angles.\n', srcM);
end

fprintf('\nexport_rank1_geometry_curves: %d Ordner geschrieben.\n', nDone);
