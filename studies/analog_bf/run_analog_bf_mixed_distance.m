function run_analog_bf_mixed_distance()
%RUN_ANALOG_BF_MIXED_DISTANCE  Mischformen: eine Seite analog, die andere
%   digital. Zwei feste Raten, Sweep ueber die Distanz.
%
%   Aufruf: in GearboxPHY-MIMO/ einfach
%       setupGearboxPath; run_analog_bf_mixed_distance
%   Vorher: validate_analog_bf.
%
%   RESSOURCEN: nodes=1  ntasks=1  cpus-per-task=32  mem=64G  time=12:00:00
%   (parfor ueber die 25 Distanzen. NICHT GEMESSEN: zehn Varianten im
%   LOS-Fall, also etwa 0.7-mal der Aufwand von run_analog_bf_distance mit
%   seinen 14; mit den Rayleigh-Kurven kommen bis zu zehn dazu. Fertige
%   Dateien werden uebersprungen.)
%
%   Gegenstueck zu run_analog_bf_distance, das nur "beide Seiten analog"
%   und "beide Seiten digital" kennt. Raster (Raten, Distanzen, M, N,
%   28 GHz) ist IDENTISCH, damit die Auswertung beide Dateisaetze
%   nebeneinanderlegen kann: Referenzen sind dort dbf_ideal, dbf_ideal_lo*
%   und abf_*.
%
%   VARIANTEN, LOS (laufen sofort, Kurven aus SE_data_bfideal_fixedB):
%     mix_txA_rxD_active     Sender analog (aktive PS), Empfaenger digital
%     mix_txA_rxD_passive    Sender analog (passive PS), Empfaenger digital.
%                            NUR EINE passive Variante: "Ausgleich" und "nur
%                            Abzug" unterscheiden sich allein auf der
%                            Empfangsseite, und die ist hier digital.
%     mix_txD_rxA_active       Sender digital, Empfaenger analog (aktive PS)
%     mix_txD_rxA_passive_comp   ... passive PS, Verlust im LNA ausgeglichen
%     mix_txD_rxA_passive_pen    ... passive PS, nur Daempfungsabzug
%   Im LOS-Fall braucht kein Mischfall neue MI-Kurven: bei Rang 1 sind die
%   optimalen Sendegewichte reine Phasen, und der digitale Empfaenger nutzt
%   dieselbe bfideal-Naeherung wie die digitale Referenz.
%
%   VARIANTEN, RAYLEIGH (nur, wenn die Kurven exportiert sind):
%     mixray_txD_rxA_*   SE_data_abfrx_fixedB  (runQamSweepBfAnalog, SIDES "rx")
%     mixray_txA_rxD_*   SE_data_abftx_fixedB  (runQamSweepBfTxAnalog, HPC)
%   Die Kurven tragen den Arraygewinn in sich; der Gearbox laeuft dort im
%   Modus "multiplexing" mit analogCurvesCarryArrayGain = true.
%
%   LO-VERTEILUNG: jede Variante einmal mit geteiltem LO und einmal mit
%   12.5 mW je zusaetzlichem Mischer. Der Aufschlag trifft nur die DIGITALE
%   Seite (N Mischer); die analoge hat einen.
%
%   ADC-MODELL: nur "envelope". In run_analog_bf_distance war der
%   Unterschied zu "quantile5" nicht sichtbar (ADC-Anteil unter 1 %).
%
%   AUSGABE: results/abfmix_distance_<variante>_<lo>.mat, <lo> = loShared
%   oder lo12p5mW, mit
%     E, Etx, Erx, Epa, Eadc, Eps   [nD x nR x nM x nN]   J/bit (NaN = unerreichbar)
%     CFG, variant, loTag, v

%% ===================== CONFIG =====================================
% Raster wie run_analog_bf_distance -- NICHT einzeln aendern.
CFG.rates     = [1e6 1e9];
CFG.distances = logspace(1, 4, 25);
CFG.fcGHz     = 28;
CFG.Ms        = [4 16 64 256];
CFG.Ns        = [1 2 4 8 16];
CFG.psBits    = 6;
CFG.psPower   = NaN;
CFG.psLossDb  = NaN;
ADC_MODEL     = "envelope";
LO_CASES      = struct('tag', {"loShared", "lo12p5mW"}, 'model', {"", "per_mixer"}, 'power', {NaN, 12.5e-3});
USE_PARALLEL  = ~isempty(ver('parallel'));
SKIP_EXISTING = true;
%% ===================================================================

D = "SE_data_bfideal_fixedB"; A = "analog"; G = "digital";
% name, Datenordner, Gearbox-Modus, Architektur Tx / Rx, Phasenschieber
V = struct( ...
  'name',   {"mix_txA_rxD_active", "mix_txA_rxD_passive", "mix_txD_rxA_active", "mix_txD_rxA_passive_comp", "mix_txD_rxA_passive_pen"}, ...
  'data',   {D, D, D, D, D}, ...
  'mode',   {"beamforming", "beamforming", "beamforming", "beamforming", "beamforming"}, ...
  'arch',   {G, G, G, G, G}, ...
  'archTx', {A, A, G, G, G}, ...
  'archRx', {G, G, A, A, A}, ...
  'ps',     {"active", "passive_penalty", "active", "passive_compensated", "passive_penalty"});
% Rayleigh, nur wenn exportiert
RAY = struct( ...
  'name',   {"mixray_txA_rxD_active", "mixray_txA_rxD_passive", "mixray_txD_rxA_active", "mixray_txD_rxA_passive_comp", "mixray_txD_rxA_passive_pen"}, ...
  'data',   {"SE_data_abftx_fixedB", "SE_data_abftx_fixedB", "SE_data_abfrx_fixedB", "SE_data_abfrx_fixedB", "SE_data_abfrx_fixedB"}, ...
  'mode',   {"multiplexing", "multiplexing", "multiplexing", "multiplexing", "multiplexing"}, ...
  'arch',   {G, G, G, G, G}, ...
  'archTx', {A, A, G, G, G}, ...
  'archRx', {G, G, A, A, A}, ...
  'ps',     {"active", "passive_penalty", "active", "passive_compensated", "passive_penalty"});
for k = 1:numel(RAY)
    if isfolder(gearboxphy.paths.dataDir(RAY(k).data))
        V(end+1) = RAY(k); %#ok<AGROW>
    else
        fprintf('%s fehlt -- %s uebersprungen (erst die Kurven rechnen und export_analog_bf_curves).\n', ...
            RAY(k).data, RAY(k).name);
    end
end
for k = 1:numel(V)
    assert(isfolder(gearboxphy.paths.dataDir(V(k).data)), 'run_analog_bf_mixed_distance:noData', ...
        '%s fehlt - erst export_mimo_comparison_curves ausfuehren.', V(k).data);
end

if USE_PARALLEL
    fprintf('Parallel Computing Toolbox vorhanden -- Pool mit %d Workern.\n', numel(CFG.distances));
    if isempty(gcp('nocreate'))
        parpool("HPCServer", numel(CFG.distances));
    end
    wait(parfevalOnAll(@addpath, 0, gearboxphy.paths.root()));
    nWorkers = numel(CFG.distances);
else
    fprintf('Keine Parallel Computing Toolbox -- parfor laeuft seriell.\n');
    nWorkers = 0;
end

nD = numel(CFG.distances); nR = numel(CFG.rates); nM = numel(CFG.Ms); nN = numel(CFG.Ns);
for lc = LO_CASES
    for k = 1:numel(V)
        v = V(k);
        v.lo = lc.model; v.loPower = lc.power;       % analog_bf_scenario liest beides
        dataDir = gearboxphy.paths.dataDir(v.data);
        outFile = gearboxphy.paths.resultsDir(sprintf('abfmix_distance_%s_%s.mat', v.name, lc.tag));
        if SKIP_EXISTING && isfile(outFile) && localCfgMatches(outFile, CFG) && localUpToDate(outFile, dataDir)
            fprintf('\n======== %s / %s: liegt vor, uebersprungen ========\n', v.name, lc.tag);
            continue
        end
        fprintf('\n======== %s / %s ========\n', v.name, lc.tag);
        t0 = tic;
        E = nan(nD, nR, nM, nN); Etx = E; Erx = E; Epa = E; Eadc = E; Eps = E;
        dists = CFG.distances;
        parfor (di = 1:nD, nWorkers)
            [e, etx, erx, epa, eadc, eps_] = localOneDistance(dists(di), CFG, v, dataDir, ADC_MODEL);
            E(di,:,:,:)    = reshape(e,    [1 nR nM nN]);   %#ok<PFOUS>
            Etx(di,:,:,:)  = reshape(etx,  [1 nR nM nN]);   %#ok<PFOUS>
            Erx(di,:,:,:)  = reshape(erx,  [1 nR nM nN]);   %#ok<PFOUS>
            Epa(di,:,:,:)  = reshape(epa,  [1 nR nM nN]);   %#ok<PFOUS>
            Eadc(di,:,:,:) = reshape(eadc, [1 nR nM nN]);   %#ok<PFOUS>
            Eps(di,:,:,:)  = reshape(eps_, [1 nR nM nN]);   %#ok<PFOUS>
        end
        variant = v.name; loTag = lc.tag; adcModel = ADC_MODEL;
        save(outFile, 'E', 'Etx', 'Erx', 'Epa', 'Eadc', 'Eps', 'CFG', 'variant', 'loTag', 'adcModel', 'v');
        fprintf('%s / %s fertig nach %.1f min -> %s\n', v.name, lc.tag, toc(t0)/60, outFile);
    end
end
end

function [E, Etx, Erx, Epa, Eadc, Eps] = localOneDistance(d, CFG, v, dataDir, adcModel)
%LOCALONEDISTANCE  Alle (Rate, M, N) bei einer Distanz, auf einem Worker.
%   Derselbe Rechenweg wie in run_analog_bf_distance.
nR = numel(CFG.rates); nM = numel(CFG.Ms); nN = numel(CFG.Ns);
E = nan(nR, nM, nN); Etx = E; Erx = E; Epa = E; Eadc = E; Eps = E;
fc = CFG.fcGHz * 1e9;
configs = arrayfun(@(n) struct('N_t', n, 'N_r', n), CFG.Ns, 'UniformOutput', false);
scen = analog_bf_scenario(d, CFG, v, dataDir, adcModel, configs);
cs = gearboxphy.sweep.resolveScenarioForCarrier(scen, fc);
op = struct('tolerance', scen.tolerance, 'maxiters', scen.maxiters, 'numtriesPerOpt', scen.numtriesPerOpt);
gear = gearboxphy.gears.qamGear();
TXF = {'PA','DAC','LO_Tx','Mix_Tx','PS_Tx'}; RXF = {'LNA','LO_Rx','Mix_Rx','ADC','PS_Rx'};
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
                % N = 1 ist in jeder Variante SISO: dann fehlen die PS-Felder nicht,
                % sie sind null (abf ist aktiv, sobald eine Seite analog ist).
                Etx(ri, mi, ni)  = sum(cellfun(@(n) pb.(n), TXF));
                Erx(ri, mi, ni)  = sum(cellfun(@(n) pb.(n), RXF));
                Eps(ri, mi, ni)  = pb.PS_Tx + pb.PS_Rx;
                Epa(ri, mi, ni)  = pb.PA;
                Eadc(ri, mi, ni) = pb.ADC;
            end
        end
    end
end
end

function tf = localUpToDate(outFile, dataDir)
o = dir(outFile);
d = dir(fullfile(dataDir, '*.mat'));
tf = ~isempty(d) && max([d.datenum]) <= o.datenum;
end

function tf = localCfgMatches(outFile, CFG)
tf = false;
try
    T = load(outFile, 'CFG');
catch
    return
end
if ~isfield(T, 'CFG'), return; end
tf = isequaln(T.CFG, CFG);
end
