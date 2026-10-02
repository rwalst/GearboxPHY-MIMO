%VALIDATE_MIMO_COMPARISON  Schritt 0 (Gearbox-Seite) des BF/MUX-Vergleichs:
%   prueft die Aenderungen an loadSECurve, qamGear, naQamGear und
%   exportToGearboxSEData, BEVOR irgendetwas Teures gerechnet wird.
%
%   Aufruf: in gearboxphy_framework/ einfach
%       validate_mimo_comparison
%   Dauer: wenige Minuten, kein Pool noetig. Bricht am Ende mit Fehler ab,
%   wenn eine Pruefung fehlschlaegt.
%
%   G1  SISO-Regression: QAM/NA-QAM rechnen bitgenau wie vorher, im
%       Multiplexing- und im (idealen) Beamforming-Modus. Fehlt eine
%       Referenzdatei auf diesem Rechner, wird der Fall uebersprungen.
%   G2  Schutz: die alten MIMO-Kurven in SE_data (je Strom normiert, ohne
%       snrReference) werden abgewiesen statt still verwendet.
%   G3  Export der alten Multiplexing-Ergebnisse in einen Testordner:
%       SNR um 10*log10(N_t) verschoben, sourceB gelesen, qamGear bezahlt
%       den ADC mit sourceB und den DAC mit 1/2*log2(M).
%   G4  Export-Optionen mit synthetischen Ergebnisdateien: 'total' wird
%       nicht verschoben, sisoFrom1x1 schreibt den SISO-Namen, SE_data ist
%       davor geschuetzt, Varianten werden gefiltert, gemischte Modi und
%       mehrdeutige Aufloesungen werden abgewiesen, alte MIMO-Kurven aus
%       baseDir werden nicht mitkopiert.
% Pfade ueber gearboxphy.paths, nicht ueber das aktuelle Verzeichnis --
% das fruehere cd(here) ist damit entbehrlich.
mimoRoot = fullfile(gearboxphy.paths.root(), '..', 'QuantizedMimoMI');
addpath(mimoRoot); setupPath;
fail = 0;

%% G1: SISO-Regression --------------------------------------------------
fprintf('=== G1 SISO-Regression (bitgenau gegen gespeicherte Ergebnisse) ===\n');
CASES = { ...
  'results/qam_M256_fc28GHz.mat',                             gearboxphy.gears.qamGear(),   256,  "multiplexing"; ...
  'results/naqam_M1024_fc28GHz.mat',                          gearboxphy.gears.naQamGear(), 1024, "multiplexing"; ...
  'beamforming_d50_allgears/qam_M16_fc28GHz.mat',     gearboxphy.gears.qamGear(),   16,   "beamforming"; ...
  'beamforming_d50_allgears/naqam_M1024_fc28GHz.mat', gearboxphy.gears.naQamGear(), 1024, "beamforming"};
for k = 1:size(CASES,1)
    if ~isfile(CASES{k,1})
        fprintf('  [skip] %s fehlt auf diesem Rechner\n', CASES{k,1});
        continue;
    end
    S = load(CASES{k,1});
    gear = CASES{k,2}; order = CASES{k,3}; amode = CASES{k,4};
    if amode == "beamforming"
        scen = gearboxphy.sweep.makeScenarioConfig('distance', S.distance, 'RVec', S.RVec, ...
            'fcVec', 28e9, 'antennaMode', "beamforming", 'beamformingConfigs', S.antennaConfigsUsed);
    else
        scen = gearboxphy.sweep.makeScenarioConfig('distance', S.distance, 'RVec', S.RVec, 'fcVec', 28e9);
    end
    cs = gearboxphy.sweep.resolveScenarioForCarrier(scen, 28e9);
    cfgs = gear.antennaConfigs(order, cs);
    op = struct('tolerance', scen.tolerance, 'maxiters', scen.maxiters, 'numtriesPerOpt', scen.numtriesPerOpt);
    x0 = gear.initialGuess(order, cs); bnds = gear.optimizerBounds(order, cs);
    idx = round(linspace(5, numel(S.RVec)-5, 6));
    worst = 0; bitsOk = true;
    for ci = 1:numel(cfgs)
        ctx = gear.prepare(order, cs, cfgs{ci});
        bitsOk = bitsOk && ctx.b_ADC == log2(sqrt(order)) && ctx.b_DAC == log2(sqrt(order));
        for i = idx
            e = gearboxphy.sweep.optimizeOnePoint(gear, ctx, S.RVec(i), x0, bnds, op);
            ref = S.E_per_bit_all(i, ci);
            if isfinite(e) && isfinite(ref), worst = max(worst, abs(e-ref)/ref);
            elseif isfinite(e) ~= isfinite(ref), worst = inf; end
        end
    end
    ok = worst < 1e-9 && bitsOk;
    fail = fail + ~ok;
    fprintf('  [%s] %-14s %-13s %d Konfig(s): max rel. Abw. %.2e, Bits 1/2*log2(M): %d\n', ...
        tern(ok,' OK ','FAIL'), gear.name, amode, numel(cfgs), worst, bitsOk);
end

%% G2: Schutz gegen unnormierte MIMO-Kurven -----------------------------
fprintf('\n=== G2 Schutz gegen je Strom normierte MIMO-Kurven ===\n');
f = fullfile(gearboxphy.paths.dataDir('SE_data'), 'SE_16_QAM_2x2.mat');
if ~isfile(f)
    fprintf('  [skip] %s fehlt\n', f);
else
    w = whos('-file', f);
    try
        gearboxphy.data.loadSECurve("QAM", 16, struct('N_t',2,'N_r',2), "SE_data", "multiplexing");
        thrown = '';
    catch err
        thrown = err.identifier;
    end
    if any(strcmp({w.name}, 'snrReference'))
        ok = isempty(thrown);
        fprintf('  [%s] %s hat snrReference und laedt\n', tern(ok,' OK ','FAIL'), f);
    else
        ok = strcmp(thrown, 'gearboxphy:snrReference');
        fprintf('  [%s] %s ohne snrReference wird abgewiesen (%s)\n', tern(ok,' OK ','FAIL'), f, thrown);
    end
    fail = fail + ~ok;
end

%% G3: Export der alten Multiplexing-Ergebnisse -------------------------
fprintf('\n=== G3 Export alter Multiplexing-Ergebnisse (je Strom) ===\n');
src = fullfile(mimoRoot, 'qam', 'results');
if isempty(dir(fullfile(src, 'mi_Nt*_Nr*_M*.mat')))
    fprintf('  [skip] keine mi_*.mat in %s\n', src);
else
    tmpDir = tempname; mkdir(tmpDir);
    cleanG3 = onCleanup(@() rmdir(tmpDir, 's'));
    exportToGearboxSEData(src, tmpDir);
    d = dir(fullfile(src, 'mi_Nt*_Nr*_M*.mat'));
    for i = 1:min(3, numel(d))
        r = load(fullfile(d(i).folder, d(i).name)); r = r.results;
        Nt = r.config.Nt; Nr = r.config.Nr; M = r.config.M;
        sd = gearboxphy.data.loadSECurve("QAM", M, struct('N_t',Nt,'N_r',Nr), string(tmpDir), "multiplexing");
        shift = sd.SNR_vec(:) - r.snrDbList(:);
        scen = gearboxphy.sweep.makeScenarioConfig('distance', 50, 'fcVec', 28e9, ...
            'dataDir', string(tmpDir), 'qamMimoConfigs', {struct('N_t',Nt,'N_r',Nr)});
        cs = gearboxphy.sweep.resolveScenarioForCarrier(scen, 28e9);
        qg = gearboxphy.gears.qamGear();
        ctx = qg.prepare(M, cs, struct('N_t',Nt,'N_r',Nr));
        ok = max(abs(shift - 10*log10(Nt))) < 1e-12 && sd.sourceB == r.B && ...
             ctx.b_ADC == r.B && ctx.b_DAC == log2(sqrt(M));
        fail = fail + ~ok;
        fprintf('  [%s] %dx%d M=%-3d SNR %+.3f dB (Soll %+.3f), b_ADC=%g (Kurve %d), b_DAC=%g\n', ...
            tern(ok,' OK ','FAIL'), Nt, Nr, M, shift(1), 10*log10(Nt), ctx.b_ADC, r.B, ctx.b_DAC);
    end
    clear cleanG3
end

%% G4: Export-Optionen mit synthetischen Ergebnisdateien ----------------
fprintf('\n=== G4 Export-Optionen ===\n');
srcS = tempname; mkdir(srcS);
baseS = fullfile(tempname, 'SE_data'); mkdir(baseS);
dstS = fullfile(tempname, 'SE_data_bf_V0'); mkdir(dstS);
cleanG4 = onCleanup(@() localRmdirs({srcS, fileparts(baseS), fileparts(dstS)}));
% Basis: eine SISO-Kurve (muss mit) und eine alte MIMO-Kurve fuer eine
% Konfiguration, die der Export NICHT schreibt (darf nicht mit)
SNR_vec = -10:10; SE_vec = linspace(0, 4, 21);
save(fullfile(baseS, 'SE_1024_QAM.mat'), 'SNR_vec', 'SE_vec');
save(fullfile(baseS, 'SE_64_QAM_4x4.mat'), 'SNR_vec', 'SE_vec');
% Quellen: BF 1x1 und 2x2 in V0 (B=5) und 2x2 in V1 (B=6)
localFakeResult(srcS, 'mi_bf_Nt1_Nr1_M16_B5.mat', 1, 16, 5, 'bf', 'total');
localFakeResult(srcS, 'mi_bf_Nt2_Nr2_M16_B5.mat', 2, 16, 5, 'bf', 'total');
localFakeResult(srcS, 'mi_bf_Nt2_Nr2_M16_B6.mat', 2, 16, 6, 'bf', 'total');
o = struct('pattern', 'mi_bf_Nt*_Nr*_M*_B*.mat', 'variant', "V0", ...
           'baseDir', string(baseS), 'sisoFrom1x1', true);
exportToGearboxSEData(srcS, dstS, o);
k1 = load(fullfile(dstS, 'SE_16_QAM.mat'));
k2 = load(fullfile(dstS, 'SE_16_QAM_2x2.mat'));
ok = isfile(fullfile(dstS, 'SE_1024_QAM.mat')) && ...          % Basis kopiert
     k1.sourceB == 5 && k2.sourceB == 5 && ...                  % Variante V0 gefiltert
     strcmp(k2.sourceMode, 'bf') && k2.snrShiftDb == 0 && ...   % 'total' nicht verschoben
     isequal(k2.SNR_vec, -15:1:25) && ...
     ~isfile(fullfile(dstS, 'SE_16_QAM_1x1.mat'));              % 1x1 unter SISO-Namen
fail = fail + ~ok;
fprintf('  [%s] Basis kopiert, V0 gefiltert, keine Verschiebung bei total, 1x1 als SISO-Name\n', tern(ok,' OK ','FAIL'));
ok = ~isfile(fullfile(dstS, 'SE_64_QAM_4x4.mat'));
fail = fail + ~ok;
fprintf('  [%s] alte MIMO-Kurve der Basis nicht uebernommen\n', tern(ok,' OK ','FAIL'));
% Abweisungen
checks = { ...
  'Schutz von SE_data',     @() exportToGearboxSEData(srcS, baseS, struct('pattern','mi_bf_*','variant',"V0",'sisoFrom1x1',true)), 'export:protectSEData'; ...
  'mehrdeutige Aufloesung', @() exportToGearboxSEData(srcS, tempname, struct('pattern','mi_bf_*')), 'export:ambiguous'};
for c = 1:size(checks,1)
    try
        checks{c,2}(); id = '';
    catch err
        id = err.identifier;
    end
    ok = strcmp(id, checks{c,3});
    fail = fail + ~ok;
    fprintf('  [%s] %s abgewiesen (%s)\n', tern(ok,' OK ','FAIL'), checks{c,1}, id);
end
% V0-konforme Bitzahl (M=4: 1+3 = 4), sonst filtert die Variante die Datei weg
localFakeResult(srcS, 'mi_Nt2_Nr2_M4_B4.mat', 2, 4, 4, 'mux', 'perStream');
try
    exportToGearboxSEData(srcS, tempname, struct('pattern', 'mi_*.mat', 'variant', "V0")); id = '';
catch err
    id = err.identifier;
end
ok = strcmp(id, 'export:mixedModes');
fail = fail + ~ok;
fprintf('  [%s] gemischte Modi abgewiesen (%s)\n', tern(ok,' OK ','FAIL'), id);
clear cleanG4

%% Ergebnis --------------------------------------------------------------
if fail == 0
    fprintf('\n=== GEARBOX-SEITE: alle Pruefungen bestanden ===\n');
else
    error('validate_mimo_comparison:failed', '%d Pruefung(en) fehlgeschlagen', fail);
end

function localFakeResult(dirName, fileName, N, M, B, mode, ref)
%LOCALFAKERESULT  Minimale Ergebnisdatei im Schema von runRuleSweep.
results.config = struct('Nt', N, 'Nr', N, 'M', M);
results.B = B;
results.mode = mode;
results.snrReference = ref;
results.snrDbList = -15:1:25;
results.lower = linspace(0, log2(M), 41);
results.methodPerSnr = repmat({'exact'}, 1, 41);
save(fullfile(dirName, fileName), 'results');
end

function localRmdirs(dirs)
for i = 1:numel(dirs)
    if isfolder(dirs{i}), rmdir(dirs{i}, 's'); end
end
end

function s = tern(c, a, b)
if c, s = a; else, s = b; end
end
