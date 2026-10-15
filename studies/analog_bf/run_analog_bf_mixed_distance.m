function run_analog_bf_mixed_distance(over)
%RUN_ANALOG_BF_MIXED_DISTANCE  Mischformen: eine Seite analog, die andere
%   digital. Zwei feste Raten, Sweep ueber die Distanz.
%
%   Aufruf: in GearboxPHY-MIMO/ einfach
%       setupGearboxPath; run_analog_bf_mixed_distance
%   Vorher: validate_analog_bf.
%
%   RESSOURCEN: 25 Worker, 64 GB, 12 h. Ein Knoten.
%   (parfor ueber die 25 Distanzen. NICHT GEMESSEN: zehn Varianten im
%   LOS-Fall, also etwa 0.7-mal der Aufwand von run_analog_bf_distance mit
%   seinen 14; mit den Rayleigh-Kurven kommen bis zu zehn dazu. Fertige
%   Dateien werden uebersprungen.)
%
%   ZIH-Cluster statt Windows: sbatch hpc/zih/submit_study.sbatch run_analog_bf_mixed_distance
%   mit --cpus-per-task=26 (einer fuer den Client). Anleitung und
%   Schritt 0: docs/HPC_RUNBOOK_ZIH.md.
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
RESULT_PREFIX = "";                      % nur fuer Vorablaeufe
N_WORKERS     = numel(CFG.distances);    % mehr als Distanzen bringt nichts
%% ===================================================================

% VORABLAEUFE OHNE DATEIAENDERUNG. Wie in run_dbf_dac_distance: ein
% struct-Argument ueberschreibt einzelne Einstellungen, damit sich die ganze
% Kette auf einem Mini-Raster pruefen laesst, bevor sie Stunden auf dem
% Cluster kostet. Fuer den regulaeren Lauf bleibt der Aufruf ohne Argument.
%
%   run_analog_bf_mixed_distance(struct('distances', [50 5000], 'Ms', 4, ...
%       'Ns', [1 2], 'N_WORKERS', 0, 'VARIANTS', "mix_txA_rxD_active", ...
%       'LO_TAGS', "loShared", 'RESULT_PREFIX', "pre_"))
%
% VARIANTS und LO_TAGS filtern die Tabellen unten, alles andere sind
% Felder von CFG oder die vier Schalter darueber.
VARIANT_FILTER = strings(1,0); LO_FILTER = strings(1,0);
if nargin >= 1 && isstruct(over)
    for f = fieldnames(over).'
        n = f{1};  val = over.(n);
        switch n
            case 'ADC_MODEL',     ADC_MODEL = string(val);
            case 'SKIP_EXISTING', SKIP_EXISTING = logical(val);
            case 'RESULT_PREFIX', RESULT_PREFIX = string(val);
            case 'N_WORKERS',     N_WORKERS = double(val);
            case 'VARIANTS',      VARIANT_FILTER = string(val);
            case 'LO_TAGS',       LO_FILTER = string(val);
            otherwise
                assert(isfield(CFG, n), 'run_analog_bf_mixed_distance:over', ...
                    ['Unbekannte Einstellung "%s". Erlaubt sind die Felder von CFG ' ...
                     'sowie ADC_MODEL, SKIP_EXISTING, RESULT_PREFIX, N_WORKERS, ' ...
                     'VARIANTS und LO_TAGS.'], n);
                CFG.(n) = val;
        end
    end
end

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
if ~isempty(VARIANT_FILTER)
    keep = ismember(string({V.name}), VARIANT_FILTER);
    assert(any(keep), 'run_analog_bf_mixed_distance:over', ...
        'VARIANTS = %s trifft keine der Varianten %s.', ...
        strjoin(VARIANT_FILTER, ','), strjoin(string({V.name}), ','));
    V = V(keep);
end
if ~isempty(LO_FILTER)
    keep = ismember(string({LO_CASES.tag}), LO_FILTER);
    assert(any(keep), 'run_analog_bf_mixed_distance:over', ...
        'LO_TAGS = %s trifft keinen der Faelle %s.', ...
        strjoin(LO_FILTER, ','), strjoin(string({LO_CASES.tag}), ','));
    LO_CASES = LO_CASES(keep);
end
for k = 1:numel(V)
    assert(isfolder(gearboxphy.paths.dataDir(V(k).data)), 'run_analog_bf_mixed_distance:noData', ...
        '%s fehlt - erst export_mimo_comparison_curves ausfuehren.', V(k).data);
end

if USE_PARALLEL && N_WORKERS >= 1
    % Profil und Workerzahl kommen aus +sweep, nicht als Literal: dasselbe
    % Skript laeuft auf dem Windows-Cluster und in einem SLURM-Job auf dem
    % ZIH-Cluster, wo es kein Profil "HPCServer" gibt (+sweep/poolProfile.m).
    nWorkers = gearboxphy.sweep.workerBudget(N_WORKERS);
    if isempty(gcp('nocreate'))
        [cl, profilQuelle] = gearboxphy.sweep.clusterFor();
        fprintf('Pool: Profil "%s" (%s), %d Worker.\n', cl.Profile, profilQuelle, nWorkers);
        parpool(cl, nWorkers);
    else
        nWorkers = min(nWorkers, gcp('nocreate').NumWorkers);
        fprintf('Vorhandener Pool -- genutzt werden %d Worker.\n', nWorkers);
    end
    wait(parfevalOnAll(@addpath, 0, gearboxphy.paths.root()));
    wait(parfevalOnAll(@setupGearboxPath, 0));    % Studienordner, u.a. studies/common
else
    fprintf('Keine Parallel Computing Toolbox -- parfor laeuft seriell.\n');
    nWorkers = 0;
end

nD = numel(CFG.distances); nR = numel(CFG.rates); nM = numel(CFG.Ms); nN = numel(CFG.Ns);
for lc = LO_CASES
    for k = 1:numel(V)
        v = V(k);
        v.lo = lc.model; v.loPower = lc.power;       % bf_arch_scenario liest beides
        dataDir = gearboxphy.paths.dataDir(v.data);
        outFile = gearboxphy.paths.resultsDir(sprintf('%sabfmix_distance_%s_%s.mat', RESULT_PREFIX, v.name, lc.tag));
        % WIEDERVERWENDEN STATT NEU RECHNEN -- siehe +data/gridFingerprint.m.
        % Derselbe Variablensatz wie abf_distance, aber eine eigene Form:
        % diese Studie mischt die Architekturen, und v traegt dafuer
        % archTx/archRx. Dass die Form im Schluessel steht, haelt die zwei
        % Dateifamilien auseinander.
        fp = gearboxphy.data.gridFingerprint("abfmix_distance/v1", ...
            @(d) bf_arch_scenario(d, CFG, v, dataDir, ADC_MODEL, ...
                arrayfun(@(n) struct('N_t', n, 'N_r', n), CFG.Ns, 'UniformOutput', false)), CFG);
        % Ueberspringen nur mit passendem Fingerabdruck (seit 2026-10-15).
        if SKIP_EXISTING && isfile(outFile) && localCfgMatches(outFile, CFG) && localUpToDate(outFile, dataDir) ...
                && gearboxphy.data.fingerprintMatches(string(outFile), fp)
            fprintf('\n======== %s / %s: liegt vor, uebersprungen ========\n', v.name, lc.tag);
            continue
        end
        if gearboxphy.data.fetchFromStore(fp, outFile)
            fprintf('\n======== %s / %s: schon gerechnet (%s), uebernommen ========\n', ...
                v.name, lc.tag, fp);
            continue
        end
        fprintf('\n======== %s / %s ========\n', v.name, lc.tag);
        t0 = tic;
        E = nan(nD, nR, nM, nN); Etx = E; Erx = E; Epa = E; Eadc = E; Eps = E;
        % ARBEITSPUNKT JE ZELLE (SE, noetiger SNR) -- ohne das stehen im
        % Ergebnis nur Energien.
        SE = E; SNRrx_dB = E;
        dists = CFG.distances;
        parfor (di = 1:nD, nWorkers)
            [e, etx, erx, epa, eadc, eps_, se, snr] = localOneDistance(dists(di), CFG, v, dataDir, ADC_MODEL);
            E(di,:,:,:)    = reshape(e,    [1 nR nM nN]);   %#ok<PFOUS>
            Etx(di,:,:,:)  = reshape(etx,  [1 nR nM nN]);   %#ok<PFOUS>
            Erx(di,:,:,:)  = reshape(erx,  [1 nR nM nN]);   %#ok<PFOUS>
            Epa(di,:,:,:)  = reshape(epa,  [1 nR nM nN]);   %#ok<PFOUS>
            Eadc(di,:,:,:) = reshape(eadc, [1 nR nM nN]);   %#ok<PFOUS>
            Eps(di,:,:,:)  = reshape(eps_, [1 nR nM nN]);   %#ok<PFOUS>
            SE(di,:,:,:)       = reshape(se,  [1 nR nM nN]);   %#ok<PFOUS>
            SNRrx_dB(di,:,:,:) = reshape(snr, [1 nR nM nN]);   %#ok<PFOUS>
        end
        variant = v.name; loTag = lc.tag; adcModel = ADC_MODEL;
        resultFingerprint = fp;
        save(outFile, 'E', 'Etx', 'Erx', 'Epa', 'Eadc', 'Eps', 'SE', 'SNRrx_dB', 'CFG', 'variant', 'loTag', 'adcModel', 'v', 'resultFingerprint');
        gearboxphy.data.publishToStore(fp, outFile);
        fprintf('%s / %s fertig nach %.1f min -> %s\n', v.name, lc.tag, toc(t0)/60, outFile);
    end
end
end

function [E, Etx, Erx, Epa, Eadc, Eps, SE, SNRrx_dB] = localOneDistance(d, CFG, v, dataDir, adcModel)
%LOCALONEDISTANCE  Alle (Rate, M, N) bei einer Distanz, auf einem Worker.
%   Derselbe Rechenweg wie in run_analog_bf_distance.
nR = numel(CFG.rates); nM = numel(CFG.Ms); nN = numel(CFG.Ns);
E = nan(nR, nM, nN); Etx = E; Erx = E; Epa = E; Eadc = E; Eps = E;
SE = E; SNRrx_dB = E;
fc = CFG.fcGHz * 1e9;
configs = arrayfun(@(n) struct('N_t', n, 'N_r', n), CFG.Ns, 'UniformOutput', false);
scen = bf_arch_scenario(d, CFG, v, dataDir, adcModel, configs);
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
            % opPt, nicht op: op ist hier schon die Optimierer-Parameter.
            [e, ~, ~, pb, opPt] = gearboxphy.sweep.optimizeOnePoint(gear, ctx, CFG.rates(ri), x0, bnds, op);
            SE(ri, mi, ni) = opPt.SE; SNRrx_dB(ri, mi, ni) = opPt.SNR_rx_dB;
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
