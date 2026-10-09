function run_dbf_dac_distance(over)
%RUN_DBF_DAC_DISTANCE  Digitales Beamforming MIT DAC-Quantisierung gegen
%   analoges Beamforming: zwei feste Raten, Sweep ueber die Distanz, je
%   DAC-Stufe eine Kurve, drei DAC-Leistungsmodelle.
%
%   Aufruf: in GearboxPHY-MIMO/ einfach
%       setupGearboxPath; run_dbf_dac_distance
%   Vorher: export_dbf_dac_curves (und davor in QuantizedMimoMI
%   runQamSweepBfIdealDac, spaeter runQamSweepBfRayleighDac).
%
%   RESSOURCEN: nodes=1  ntasks=1  cpus-per-task=25  mem=64G  time=24:00:00
%   parfor ueber die 25 Distanzen; mehr als 25 Worker bringen nichts.
%   Zeitbedarf NICHT GEMESSEN. Fertige Dateien werden uebersprungen
%   (SKIP_EXISTING): nach einem Abbruch einfach noch einmal starten.
%
%   WAS GERECHNET WIRD (alles QAM, 28 GHz, ADC-Modell "envelope", ADC-Regel
%   fixedB; Raster wie run_analog_bf_distance):
%     Kanal    "los" (Rang 1, immer) und "ray" (Rayleigh, sobald die
%              Kurvenordner existieren)
%     LO       loShared und lo12p5mW (LO-Puffer je zusaetzlichem Mischer)
%     DAC-Leistungsmodell (makeScenarioConfig 'dacPowerModel'):
%              "analytic" (3 V, Stand des Codes), "analytic_1V"
%              (Dissertation Kap. 5/6), "survey" (DAC-Uebersicht)
%   Je (Kanal, LO, DAC-Modell) eine Datei mit der DIGITALEN Seite:
%     Eideal   Kurve mit idealem DAC, bezahlt 1/2*log2(M) -- der bisherige
%              Stand (SE_data_bfideal_fixedB bzw. SE_data_bf_fixedB)
%     E        Kurven mit DAC-Quantisierung, letzte Dimension = DAC-Stufe
%              (SE_data_..._dac<k>), der DAC bezahlt sourceBdac
%     Ebest    Minimum ueber die Stufen (gearboxphy.sweep.minOverDacLevels),
%     kBest    Index der gewaehlten Stufe
%     Ecommon  Vergleichsfall gemeinsame Aussteuerung, soweit Ordner
%              ..._dac<k>_common existieren
%   Je (analoge Variante, DAC-Modell) eine Datei: der analoge Sender hat
%   EINEN DAC mit ungedrehtem Symbol und zahlt immer 1/2*log2(M); er wird
%   mitgerechnet, weil das DAC-Leistungsmodell auch ihn trifft.
%
%   AUSGABE:
%     results/dbfdac_distance_<kanal>_<lo>_<dacModell>.mat
%     results/abfdac_distance_<variante>_<dacModell>.mat
%   Felder J/bit: E, Etx, Erx, Epa, Edac (NaN = unerreichbar), dazu CFG,
%   dacLevels, dacModel und die Szenario-Einstellungen.
%
%   over (optional): struct, dessen Felder gleichnamige Einstellungen
%   unten ersetzen (nur fuer Tests gedacht, z.B. ein kleines Raster).

%% ===================== CONFIG =====================================
P.N_WORKERS     = 25;                   % feste Poolgroesse
P.rates         = [1e6 1e9];            % niedrig / hoch [bit/s]
P.distances     = logspace(1, 4, 25);   % 10 m .. 10 km
P.fcGHz         = 28;
P.Ms            = [4 16 64 256];
P.Ns            = [1 2 4 8 16];
P.psBits        = 6;
P.psPower       = NaN;                  % NaN = Vorgabe aus phaseShifterParams
P.psLossDb      = NaN;
P.DAC_LEVELS    = [0 1 2 3];            % Bit ueber 1/2*log2(M)
P.DAC_MODELS    = ["analytic" "analytic_1V" "survey"];
P.ADC_MODEL     = "envelope";
P.LO_NAMES      = ["loShared" "lo12p5mW"];
P.LO_POWER      = [NaN 12.5e-3];        % [W] je zusaetzlichem Mischer, NaN = gemeinsamer LO
P.RESULT_PREFIX = "";                   % nur fuer Tests
P.SKIP_EXISTING = true;
%% ===================================================================
if nargin >= 1 && isstruct(over)
    for f = fieldnames(over).'
        assert(isfield(P, f{1}), 'run_dbf_dac_distance:over', 'Unbekannte Einstellung "%s".', f{1});
        P.(f{1}) = over.(f{1});
    end
end
CFG = struct('rates', P.rates, 'distances', P.distances, 'fcGHz', P.fcGHz, 'Ms', P.Ms, 'Ns', P.Ns, ...
             'psBits', P.psBits, 'psPower', P.psPower, 'psLossDb', P.psLossDb);

% ---- Kanaele: Ordner der digitalen Seite und der analogen Varianten ----
CH = struct( ...
  'name',       {"los", "ray"}, ...
  'digBase',    {"SE_data_bfideal_fixedB", "SE_data_bf_fixedB"}, ...
  'anaData',    {"SE_data_bfideal_fixedB", "SE_data_abf_fixedB"}, ...
  'anaMode',    {"beamforming", "multiplexing"}, ...
  'anaPrefix',  {"abf", "abfray"});
PS_NAMES = ["active" "passive_comp" "passive_pen"];
PS_TYPES = ["active" "passive_compensated" "passive_penalty"];

nWorkers = localPool(P.N_WORKERS);

for ch = CH
    % vorhandene DAC-Stufen dieses Kanals
    lev = []; levCommon = [];
    for k = P.DAC_LEVELS
        if isfolder(gearboxphy.paths.dataDir(sprintf("%s_dac%d", ch.digBase, k))), lev(end+1) = k; end %#ok<AGROW>
        if isfolder(gearboxphy.paths.dataDir(sprintf("%s_dac%d_common", ch.digBase, k))), levCommon(end+1) = k; end %#ok<AGROW>
    end
    if isempty(lev)
        fprintf('\n%s: keine Ordner %s_dac<k> -- Kanal uebersprungen (erst export_dbf_dac_curves).\n', ...
                ch.name, ch.digBase);
        continue
    end
    assert(isfolder(gearboxphy.paths.dataDir(ch.digBase)), 'run_dbf_dac_distance:noData', ...
        '%s fehlt - erst export_mimo_comparison_curves ausfuehren.', ch.digBase);

    for dacModel = P.DAC_MODELS
        % ---------------- digitale Seite ----------------
        for li = 1:numel(P.LO_NAMES)
            outFile = gearboxphy.paths.resultsDir(sprintf('%sdbfdac_distance_%s_%s_%s.mat', ...
                P.RESULT_PREFIX, ch.name, P.LO_NAMES(li), dacModel));
            if P.SKIP_EXISTING && localDone(outFile, CFG, lev, levCommon)
                fprintf('\n======== %s liegt vor, uebersprungen ========\n', outFile);
                continue
            end
            fprintf('\n======== digital, %s / %s / %s ========\n', ch.name, P.LO_NAMES(li), dacModel);
            t0 = tic;
            v = struct('name', "dbf", 'data', ch.digBase, 'mode', "multiplexing", 'arch', "digital", ...
                       'ps', "active", 'lo', "", 'loPower', NaN);
            if ~isnan(P.LO_POWER(li)), v.lo = "per_mixer"; v.loPower = P.LO_POWER(li); end

            R0 = localCase(CFG, v, P.ADC_MODEL, dacModel, nWorkers);
            Eideal = R0.E; EidealDac = R0.Edac; EidealPa = R0.Epa;

            [E, Etx, Erx, Epa, Edac] = localLevels(CFG, v, ch.digBase, lev, "", P.ADC_MODEL, dacModel, nWorkers);
            [Ebest, kBest, EbestDac, EbestPa] = gearboxphy.sweep.minOverDacLevels(E, Edac, Epa);
            S = struct('E', E, 'Etx', Etx, 'Erx', Erx, 'Epa', Epa, 'Edac', Edac, ...
                       'Eideal', Eideal, 'EidealDac', EidealDac, 'EidealPa', EidealPa, ...
                       'Ebest', Ebest, 'kBest', kBest, 'EbestDac', EbestDac, 'EbestPa', EbestPa, ...
                       'dacLevels', lev, 'dacLevelsCommon', levCommon, 'CFG', CFG, ...
                       'channel', ch.name, 'lo', P.LO_NAMES(li), 'dacModel', dacModel, 'v', v);
            if ~isempty(levCommon)
                [S.Ecommon, ~, ~, S.EcommonPa, S.EcommonDac] = ...
                    localLevels(CFG, v, ch.digBase, levCommon, "_common", P.ADC_MODEL, dacModel, nWorkers);
            end
            save(outFile, '-struct', 'S');
            fprintf('fertig nach %.1f min -> %s\n', toc(t0)/60, outFile);
        end

        % ---------------- analoge Varianten ----------------
        if ~isfolder(gearboxphy.paths.dataDir(ch.anaData))
            fprintf('\n%s fehlt -- analoge Varianten fuer "%s" uebersprungen.\n', ch.anaData, ch.name);
            continue
        end
        for pi_ = 1:numel(PS_NAMES)
            vname = sprintf("%s_%s", ch.anaPrefix, PS_NAMES(pi_));
            outFile = gearboxphy.paths.resultsDir(sprintf('%sabfdac_distance_%s_%s.mat', ...
                P.RESULT_PREFIX, vname, dacModel));
            if P.SKIP_EXISTING && localDone(outFile, CFG, [], [])
                fprintf('\n======== %s liegt vor, uebersprungen ========\n', outFile);
                continue
            end
            fprintf('\n======== analog, %s / %s ========\n', vname, dacModel);
            t0 = tic;
            v = struct('name', vname, 'data', ch.anaData, 'mode', ch.anaMode, 'arch', "analog", ...
                       'ps', PS_TYPES(pi_), 'lo', "", 'loPower', NaN);
            S = localCase(CFG, v, P.ADC_MODEL, dacModel, nWorkers);
            S.CFG = CFG; S.variant = vname; S.channel = ch.name; S.dacModel = dacModel; S.v = v;
            S.dacLevels = []; S.dacLevelsCommon = [];
            save(outFile, '-struct', 'S');
            fprintf('fertig nach %.1f min -> %s\n', toc(t0)/60, outFile);
        end
    end
end
end

function [E, Etx, Erx, Epa, Edac] = localLevels(CFG, v, base, levels, suffix, adcModel, dacModel, nWorkers)
%LOCALLEVELS  Dieselbe Variante fuer jede DAC-Stufe; letzte Dimension = Stufe.
nK = numel(levels);
sz = [numel(CFG.distances), numel(CFG.rates), numel(CFG.Ms), numel(CFG.Ns)];
E = nan([sz nK]); Etx = E; Erx = E; Epa = E; Edac = E;
for i = 1:nK
    vk = v; vk.data = sprintf("%s_dac%d%s", base, levels(i), suffix);
    fprintf('  -- DAC-Stufe +%d%s (%s)\n', levels(i), suffix, vk.data);
    R = localCase(CFG, vk, adcModel, dacModel, nWorkers);
    E(:,:,:,:,i) = R.E; Etx(:,:,:,:,i) = R.Etx; Erx(:,:,:,:,i) = R.Erx;
    Epa(:,:,:,:,i) = R.Epa; Edac(:,:,:,:,i) = R.Edac;
end
end

function R = localCase(CFG, v, adcModel, dacModel, nWorkers)
%LOCALCASE  Eine Variante ueber alle Distanzen (parfor), Felder [nD nR nM nN].
nD = numel(CFG.distances); nR = numel(CFG.rates); nM = numel(CFG.Ms); nN = numel(CFG.Ns);
dataDir = gearboxphy.paths.dataDir(v.data);
E = nan(nD, nR, nM, nN); Etx = E; Erx = E; Epa = E; Edac = E;
dists = CFG.distances;
parfor (di = 1:nD, nWorkers)
    [e, etx, erx, epa, edac] = localOneDistance(dists(di), CFG, v, dataDir, adcModel, dacModel);
    E(di,:,:,:)    = reshape(e,    [1 nR nM nN]);
    Etx(di,:,:,:)  = reshape(etx,  [1 nR nM nN]);
    Erx(di,:,:,:)  = reshape(erx,  [1 nR nM nN]);
    Epa(di,:,:,:)  = reshape(epa,  [1 nR nM nN]);
    Edac(di,:,:,:) = reshape(edac, [1 nR nM nN]);
end
R = struct('E', E, 'Etx', Etx, 'Erx', Erx, 'Epa', Epa, 'Edac', Edac);
end

function [E, Etx, Erx, Epa, Edac] = localOneDistance(d, CFG, v, dataDir, adcModel, dacModel)
%LOCALONEDISTANCE  Alle (Rate, M, N) bei einer Distanz, auf einem Worker.
%   Wie in run_analog_bf_distance, zusaetzlich der DAC-Anteil.
nR = numel(CFG.rates); nM = numel(CFG.Ms); nN = numel(CFG.Ns);
E = nan(nR, nM, nN); Etx = E; Erx = E; Epa = E; Edac = E;
fc = CFG.fcGHz * 1e9;
configs = arrayfun(@(n) struct('N_t', n, 'N_r', n), CFG.Ns, 'UniformOutput', false);
scen = analog_bf_scenario(d, CFG, v, dataDir, adcModel, configs, dacModel);
cs = gearboxphy.sweep.resolveScenarioForCarrier(scen, fc);
op = struct('tolerance', scen.tolerance, 'maxiters', scen.maxiters, 'numtriesPerOpt', scen.numtriesPerOpt);
gear = gearboxphy.gears.qamGear();
TXF = {'PA','DAC','LO_Tx','Mix_Tx'}; RXF = {'LNA','LO_Rx','Mix_Rx','ADC'};
for mi = 1:nM
    M = CFG.Ms(mi);
    cfgs = gear.antennaConfigs(M, cs);
    x0 = gear.initialGuess(M, cs); bnds = gear.optimizerBounds(M, cs);
    for c = 1:numel(cfgs)
        ni = find(CFG.Ns == cfgs{c}.N_t, 1);
        if isempty(ni), continue; end
        ctx = gear.prepare(M, cs, cfgs{c});
        for ri = 1:nR
            [e, ~, ~, pb] = gearboxphy.sweep.optimizeOnePoint(gear, ctx, CFG.rates(ri), x0, bnds, op);
            E(ri, mi, ni) = e;
            if isstruct(pb)
                Etx(ri, mi, ni)  = sum(cellfun(@(n) pb.(n), TXF));
                Erx(ri, mi, ni)  = sum(cellfun(@(n) pb.(n), RXF));
                if isfield(pb, 'PS_Tx')
                    Etx(ri, mi, ni) = Etx(ri, mi, ni) + pb.PS_Tx;
                    Erx(ri, mi, ni) = Erx(ri, mi, ni) + pb.PS_Rx;
                end
                Epa(ri, mi, ni)  = pb.PA;
                Edac(ri, mi, ni) = pb.DAC;
            end
        end
    end
end
end

function nWorkers = localPool(nWanted)
%LOCALPOOL  Vorhandenen Pool nutzen (nie schliessen), sonst einen mit genau
%   nWanted Workern oeffnen; gelingt das nicht, seriell rechnen.
nWorkers = 0;
if isempty(ver('parallel')) || nWanted < 1
    fprintf('Kein Pool -- parfor laeuft seriell.\n');
    return
end
pool = gcp('nocreate');
if isempty(pool)
    try
        pool = parpool("HPCServer", nWanted);
    catch err
        fprintf('Pool liess sich nicht oeffnen (%s) -- parfor laeuft seriell.\n', err.message);
        return
    end
end
% Worker erben das Arbeitsverzeichnis des Clients NICHT (siehe runSweep.m)
wait(parfevalOnAll(@addpath, 0, gearboxphy.paths.root()));
wait(parfevalOnAll(@addpath, 0, fileparts(mfilename('fullpath'))));
nWorkers = min(pool.NumWorkers, nWanted);
fprintf('Pool mit %d Workern, genutzt werden %d.\n', pool.NumWorkers, nWorkers);
end

function tf = localDone(outFile, CFG, lev, levCommon)
%LOCALDONE  Datei vorhanden UND mit demselben Raster und denselben Stufen
%   gerechnet. Kommen spaeter Stufen dazu (z.B. die Rayleigh-Kurven oder
%   der Vergleichsfall), wird neu gerechnet.
tf = false;
if ~isfile(outFile), return; end
try
    T = load(outFile, 'CFG', 'dacLevels', 'dacLevelsCommon');
catch
    return
end
if ~isfield(T, 'CFG') || ~isfield(T, 'dacLevels') || ~isfield(T, 'dacLevelsCommon'), return; end
tf = isequaln(T.CFG, CFG) && isequal(T.dacLevels(:), lev(:)) && isequal(T.dacLevelsCommon(:), levCommon(:));
end
