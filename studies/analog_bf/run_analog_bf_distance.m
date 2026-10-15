function run_analog_bf_distance()
%RUN_ANALOG_BF_DISTANCE  Analoges gegen digitales Beamforming: zwei feste
%   Raten, Sweep ueber die Distanz, drei Phasenschieber-Varianten, zwei
%   ADC-Modelle.
%
%   Aufruf: in GearboxPHY-MIMO/ einfach
%       setupGearboxPath; run_analog_bf_distance
%   Vorher: validate_analog_bf.
%
%   RESSOURCEN: 25 Worker, 64 GB, 12 h. Ein Knoten.
%   (parfor ueber die 25 Distanzen; mehr als 25 Worker bringen nichts.
%   Zeitbedarf NICHT GEMESSEN -- aus run_mimo_comparison_distance
%   uebernommen, das bei aehnlich vielen Varianten dieselbe Schleife hat.)
%
%   ZIH-Cluster statt Windows: sbatch hpc/zih/submit_study.sbatch run_analog_bf_distance
%   mit --cpus-per-task=26 (einer fuer den Client). Anleitung und
%   Schritt 0: docs/HPC_RUNBOOK_ZIH.md.
%
%   FALL 1 (laeuft sofort, Kurven liegen vor): Rang-1-Kanal (LOS), ideale
%   Phasen. Nach dem analogen Kombinieren bleibt ein skalarer AWGN-Kanal
%   mit EINEM ADC; die SE ist die quantisierte SISO-Kurve, der Gewinn
%   N_t*N_r steht im Linkbudget (antennaMode "beamforming"). Die Kurven
%   kommen aus SE_data_bfideal_fixedB (1x1-Dateien: SISO-AWGN mit
%   B = 1/2*log2(M) + 3).
%     dbf_ideal            digitale Referenz: gleiche Kurve, eine Kette je Antenne
%     dbf_ideal_lo4mW      dieselbe, aber jeder Mischer ueber den ersten hinaus
%     dbf_ideal_lo12p5mW   zahlt einen LO-Puffer (loDistributionModel "per_mixer")
%     dbf_ideal_lo17mW     von 4, 12.5 bzw. 17 mW. Belege bei 28 GHz: rund 4 mW
%                          (Synthesizer je Element, Wang & Razavi), 12.5 mW (Khanna
%                          2026), 16.6 mW (Pang 2019); siehe docs/ANALOG_BEAMFORMING.md.
%                          Die analogen Varianten haben EINEN Mischer je Seite und
%                          aendern sich dadurch nicht.
%     abf_active           aktiver Phasenschieber, 20 mW je Element
%     abf_passive_comp     passiv, Verlust durch LNA-Gewinn ausgeglichen
%     abf_passive_pen      passiv, Verlust nur als Treiberleistung und
%                          Rauschzahl (optimistische Grenze)
%
%   FALL 2 (laeuft nur, wenn die Kurven exportiert sind): Rayleigh/Rice mit
%   reinen Phasengewichten. Die Kurven tragen den Arraygewinn in sich
%   (SE_data_abf_fixedB*, aus QuantizedMimoMI runQamSweepBfAnalog ueber
%   export_analog_bf_curves), der Gearbox laeuft deshalb im Modus
%   "multiplexing" mit analogCurvesCarryArrayGain = true.
%     abfray_active / _passive_comp / _passive_pen      (K = 0)
%   Die digitale Rayleigh-Referenz dazu ist results/cmp_distance_bf_fixedB.mat
%   aus run_mimo_comparison_distance.
%
%   Hardware in allen analogen Varianten (qamGear, beamformingArch "analog"):
%   ein DAC-Paar, ein ADC-Paar und ein Mischer je Seite, N PAs, N LNAs, ein
%   Phasenschieber je Element. N = 1 ist in jeder Variante die SISO-Strecke.
%
%   AUSGABE: results/abf_distance_<variante>_<adc>.mat mit
%     E, Etx, Erx, Epa, Eadc, Eps   [nD x nR x nM x nN]   J/bit (NaN = unerreichbar)
%     CFG, variant, adcModel, V (die Szenario-Einstellungen der Variante)

%% ===================== CONFIG =====================================
CFG.rates     = [1e6 1e9];              % niedrig / hoch [bit/s]
CFG.distances = logspace(1, 4, 25);     % 10 m .. 10 km
CFG.fcGHz     = 28;
CFG.Ms        = [4 16 64 256];
CFG.Ns        = [1 2 4 8 16];
CFG.psBits    = 6;                      % Phasenaufloesung; Inf = kein Quantisierungsverlust
CFG.psPower   = NaN;                    % NaN = Vorgabe aus phaseShifterParams (28 GHz: 20 mW)
CFG.psLossDb  = NaN;                    % NaN = Vorgabe aus phaseShifterParams (28 GHz: 7.5 dB)
ADC_MODELS    = ["envelope" "quantile5"];
USE_PARALLEL  = ~isempty(ver('parallel'));
SKIP_EXISTING = true;
%% ===================================================================

% name, Datenordner, Gearbox-Modus, Architektur, Phasenschieber
D = "SE_data_bfideal_fixedB"; B = "beamforming";
V = struct( ...
  'name',    {"dbf_ideal", "dbf_ideal_lo4mW", "dbf_ideal_lo12p5mW", "dbf_ideal_lo17mW", "abf_active", "abf_passive_comp", "abf_passive_pen"}, ...
  'data',    {D, D, D, D, D, D, D}, ...
  'mode',    {B, B, B, B, B, B, B}, ...
  'arch',    {"digital", "digital", "digital", "digital", "analog", "analog", "analog"}, ...
  'ps',      {"active", "active", "active", "active", "active", "passive_compensated", "passive_penalty"}, ...
  'lo',      {"", "per_mixer", "per_mixer", "per_mixer", "", "", ""}, ...
  'loPower', {NaN, 4e-3, 12.5e-3, 17e-3, NaN, NaN, NaN});     % [W] je zusaetzlichem Mischer
% Fall 2, nur wenn exportiert
if isfolder(gearboxphy.paths.dataDir("SE_data_abf_fixedB"))
    names = ["abfray_active" "abfray_passive_comp" "abfray_passive_pen"];
    pss   = ["active" "passive_compensated" "passive_penalty"];
    for k = 1:numel(names)
        V(end+1) = struct('name', names(k), 'data', "SE_data_abf_fixedB", 'mode', "multiplexing", ...
            'arch', "analog", 'ps', pss(k), 'lo', "", 'loPower', NaN); %#ok<AGROW>
    end
else
    fprintf('SE_data_abf_fixedB fehlt -- nur Fall 1 (LOS). Fall 2 nach export_analog_bf_curves.\n');
end
% FALL 2 UEBER DEN RICE-FAKTOR (AP3). Dieselbe Konstruktion wie Fall 2, nur
% mit dem Kurvenordner des jeweiligen K -- der Arraygewinn steckt in der
% Kurve, deshalb mode = "multiplexing". Damit hat die analoge Seite als
% letzte der drei Architekturen eine Rice-Spalte; MUX und digitales BF
% haben sie seit dem Rice-Sweep.
%
% K = Inf gehoert dazu und ist NICHT dasselbe wie Fall 1: Fall 1 nimmt die
% bfideal-Kurve und legt den Gewinn N_t*N_r ins Linkbudget, hier kommt der
% Rang-1-Kanal aus der Kurve selbst (phase-only Praekodierer, 1-Bit-
% Quantisierung inklusive). Zwei Wege zum Grenzfall, die sich genau um das
% unterscheiden, was die Studie messen will.
%
% Die Ordner liegen seit dem 2026-10-11 da und wurden von keinem Sweep
% gelesen -- deshalb hier, und deshalb je Ordner nur wenn vorhanden.
for Kv = [3 30 Inf]
    dK = sprintf("SE_data_abf_fixedB_K%g", Kv);
    if ~isfolder(gearboxphy.paths.dataDir(dK))
        fprintf('%s fehlt -- Rice-Variante K = %g uebersprungen.\n', dK, Kv);
        continue
    end
    pss = ["active" "passive_compensated" "passive_penalty"];
    tag = ["active" "passive_comp" "passive_pen"];
    for k = 1:numel(pss)
        V(end+1) = struct('name', sprintf("abfray_%s_K%g", tag(k), Kv), 'data', dK, ...
            'mode', "multiplexing", 'arch', "analog", 'ps', pss(k), ...
            'lo', "", 'loPower', NaN); %#ok<AGROW>
    end
end

for k = 1:numel(V)
    assert(isfolder(gearboxphy.paths.dataDir(V(k).data)), 'run_analog_bf_distance:noData', ...
        '%s fehlt - erst export_mimo_comparison_curves ausfuehren.', V(k).data);
end

if USE_PARALLEL
    % Profil und Workerzahl kommen aus +sweep, nicht als Literal: dasselbe
    % Skript laeuft auf dem Windows-Cluster und in einem SLURM-Job auf dem
    % ZIH-Cluster, wo es kein Profil "HPCServer" gibt (+sweep/poolProfile.m).
    nWorkers = gearboxphy.sweep.workerBudget(numel(CFG.distances));
    if isempty(gcp('nocreate'))
        [cl, profilQuelle] = gearboxphy.sweep.clusterFor();
        fprintf('Pool: Profil "%s" (%s), %d Worker.\n', cl.Profile, profilQuelle, nWorkers);
        parpool(cl, nWorkers);
    else
        nWorkers = min(nWorkers, gcp('nocreate').NumWorkers);
        fprintf('Vorhandener Pool -- genutzt werden %d Worker.\n', nWorkers);
    end
    % Worker erben das Arbeitsverzeichnis des Clients NICHT (siehe runSweep.m)
    wait(parfevalOnAll(@addpath, 0, gearboxphy.paths.root()));
    wait(parfevalOnAll(@setupGearboxPath, 0));    % Studienordner, u.a. studies/common
else
    fprintf('Keine Parallel Computing Toolbox -- parfor laeuft seriell.\n');
    nWorkers = 0;
end

nD = numel(CFG.distances); nR = numel(CFG.rates); nM = numel(CFG.Ms); nN = numel(CFG.Ns);
for adcModel = ADC_MODELS
    for k = 1:numel(V)
        v = V(k);
        dataDir = gearboxphy.paths.dataDir(v.data);
        outFile = gearboxphy.paths.resultsDir(sprintf('abf_distance_%s_%s.mat', v.name, adcModel));
        % WIEDERVERWENDEN STATT NEU RECHNEN. Der Fingerabdruck deckt jede
        % Zelle des (Distanz, M, N)-Gitters ab, gebildet aus genau dem ctx,
        % mit dem sie gerechnet wird (+data/gridFingerprint.m). Hat ein
        % anderer Lauf dasselbe schon gerechnet -- etwa unter einem anderen
        % Variantennamen oder in einem anderen Ergebnisordner -- wird seine
        % Datei uebernommen. Die Form "abf_distance/v1" steht im Schluessel:
        % nur Dateien mit demselben Variablensatz sind austauschbar.
        % Ein Szenario nur zum ABLESEN der Modellnamen, die in die Datei
        % gehoeren. Billig (kein Kurvenzugriff), und es haelt die
        % Vorgabewerte an EINER Stelle: in makeScenarioConfig.
        cfgsFp = arrayfun(@(n) struct('N_t', n, 'N_r', n), CFG.Ns, 'UniformOutput', false);
        scen0 = localScenario(CFG.distances(1), CFG, v, dataDir, adcModel, cfgsFp);
        fp = gearboxphy.data.gridFingerprint("abf_analog/v2", ...
            @(d) localScenario(d, CFG, v, dataDir, adcModel, ...
                arrayfun(@(n) struct('N_t', n, 'N_r', n), CFG.Ns, 'UniformOutput', false)), CFG);
        % Ueberspringen nur mit passendem Fingerabdruck (seit 2026-10-15):
        % eine Datei mit anderen Hardwaremodellen gilt als nicht fertig.
        if SKIP_EXISTING && isfile(outFile) && localCfgMatches(outFile, CFG) && localUpToDate(outFile, dataDir) ...
                && gearboxphy.data.fingerprintMatches(string(outFile), fp)
            fprintf('\n======== %s / %s: liegt vor, uebersprungen ========\n', v.name, adcModel);
            continue
        end
        if gearboxphy.data.fetchFromStore(fp, outFile)
            fprintf('\n======== %s / %s: schon gerechnet (%s), uebernommen ========\n', ...
                v.name, adcModel, fp);
            continue
        end
        fprintf('\n======== %s / %s ========\n', v.name, adcModel);
        t0 = tic;
        E = nan(nD, nR, nM, nN); Etx = E; Erx = E; Epa = E; Eadc = E; Edac = E; Eps = E;
        % ARBEITSPUNKT JE ZELLE: wo der Gang diesen Punkt betreibt. Ohne das
        % stehen im Ergebnis nur Energien -- Spektraleffizienz und noetiger SNR
        % waren nach dem Lauf nicht mehr rekonstruierbar.
        SE = E; SNRrx_dB = E;
        dists = CFG.distances;
        parfor (di = 1:nD, nWorkers)
            [e, etx, erx, epa, eadc, edac, eps_, se, snr] = localOneDistance(dists(di), CFG, v, dataDir, adcModel);
            E(di,:,:,:)    = reshape(e,    [1 nR nM nN]);   %#ok<PFOUS>
            Etx(di,:,:,:)  = reshape(etx,  [1 nR nM nN]);   %#ok<PFOUS>
            Erx(di,:,:,:)  = reshape(erx,  [1 nR nM nN]);   %#ok<PFOUS>
            Epa(di,:,:,:)  = reshape(epa,  [1 nR nM nN]);   %#ok<PFOUS>
            Eadc(di,:,:,:) = reshape(eadc, [1 nR nM nN]);   %#ok<PFOUS>
            Edac(di,:,:,:) = reshape(edac, [1 nR nM nN]);   %#ok<PFOUS>
            Eps(di,:,:,:)  = reshape(eps_, [1 nR nM nN]);   %#ok<PFOUS>
            SE(di,:,:,:)       = reshape(se,  [1 nR nM nN]);   %#ok<PFOUS>
            SNRrx_dB(di,:,:,:) = reshape(snr, [1 nR nM nN]);   %#ok<PFOUS>
        end
        variant = v.name;
        resultFingerprint = fp;
        % VEREINIGTER VARIABLENSATZ (docs/RESULT_NAMING.md, Fall 2): genau
        % diese Felder schreibt studies/digital_bf_dac fuer dieselben
        % analogen Varianten. Nur so kann der Ergebnisspeicher die eine
        % Datei fuer die andere liefern, statt sie doppelt zu rechnen.
        % hw und dacModel kommen aus dem Szenario, nicht aus Konstanten --
        % diese Studie variiert die Modelle nicht, benutzt also die
        % Vorgaben, und die sollen auch so dokumentiert sein.
        hw = struct('name', scen0.dacPowerModel, 'lna', scen0.lnaPowerModel, ...
                    'adc', scen0.adcPowerModel, 'dac', scen0.dacPowerModel);
        dacModel = scen0.dacPowerModel;
        save(outFile, 'E', 'Etx', 'Erx', 'Epa', 'Eadc', 'Edac', 'Eps', ...
            'SE', 'SNRrx_dB', 'CFG', 'variant', 'v', 'adcModel', 'dacModel', 'hw', ...
            'resultFingerprint');
        gearboxphy.data.publishToStore(fp, outFile);
        fprintf('%s / %s fertig nach %.1f min -> %s\n', v.name, adcModel, toc(t0)/60, outFile);
    end
end
end

function [E, Etx, Erx, Epa, Eadc, Edac, Eps, SE, SNRrx_dB] = localOneDistance(d, CFG, v, dataDir, adcModel)
%LOCALONEDISTANCE  Alle (Rate, M, N) bei einer Distanz, auf einem Worker.
nR = numel(CFG.rates); nM = numel(CFG.Ms); nN = numel(CFG.Ns);
E = nan(nR, nM, nN); Etx = E; Erx = E; Epa = E; Eadc = E; Edac = E; Eps = E;
% ARBEITSPUNKT JE ZELLE: wo der Gang diesen Punkt betreibt. Ohne das
% stehen im Ergebnis nur Energien -- Spektraleffizienz und noetiger SNR
% waren nach dem Lauf nicht mehr rekonstruierbar.
SE = E; SNRrx_dB = E;
fc = CFG.fcGHz * 1e9;
configs = arrayfun(@(n) struct('N_t', n, 'N_r', n), CFG.Ns, 'UniformOutput', false);
scen = localScenario(d, CFG, v, dataDir, adcModel, configs);
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
            % opPt, nicht op: op ist hier schon die Optimierer-Parameter.
            [e, ~, ~, pb, opPt] = gearboxphy.sweep.optimizeOnePoint(gear, ctx, CFG.rates(ri), x0, bnds, op);
            SE(ri, mi, ni) = opPt.SE; SNRrx_dB(ri, mi, ni) = opPt.SNR_rx_dB;
            E(ri, mi, ni) = e;
            if isstruct(pb)
                ps = 0;
                if isfield(pb, 'PS_Tx'), ps = pb.PS_Tx + pb.PS_Rx; end
                Eps(ri, mi, ni)  = ps;
                Etx(ri, mi, ni)  = sum(cellfun(@(n) pb.(n), TXF));
                Erx(ri, mi, ni)  = sum(cellfun(@(n) pb.(n), RXF));
                if isfield(pb, 'PS_Tx')
                    Etx(ri, mi, ni) = Etx(ri, mi, ni) + pb.PS_Tx;
                    Erx(ri, mi, ni) = Erx(ri, mi, ni) + pb.PS_Rx;
                end
                Epa(ri, mi, ni)  = pb.PA;
                Eadc(ri, mi, ni) = pb.ADC;
                % Edac gehoert mit in die Datei, auch wenn DIESE Studie das
                % DAC-Modell nicht variiert: dieselbe Rechnung entsteht in
                % studies/digital_bf_dac als abfdac_distance_*_analytic, und
                % austauschbar sind zwei Dateien nur mit demselben
                % Variablensatz (docs/RESULT_NAMING.md, Fall 2).
                Edac(ri, mi, ni) = pb.DAC;
            end
        end
    end
end
end

function scen = localScenario(d, CFG, v, dataDir, adcModel, configs)
%LOCALSCENARIO  Die EINE Stelle, an der aus einer Variante ein Szenario
%   wird -- validate_analog_bf ruft dieselbe Logik ueber
%   studies/common/bf_arch_scenario.m auf.
scen = bf_arch_scenario(d, CFG, v, dataDir, adcModel, configs);
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
