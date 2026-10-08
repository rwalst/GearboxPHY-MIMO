function run_analog_bf_distance()
%RUN_ANALOG_BF_DISTANCE  Analoges gegen digitales Beamforming: zwei feste
%   Raten, Sweep ueber die Distanz, drei Phasenschieber-Varianten, zwei
%   ADC-Modelle.
%
%   Aufruf: in GearboxPHY-MIMO/ einfach
%       setupGearboxPath; run_analog_bf_distance
%   Vorher: validate_analog_bf.
%
%   RESSOURCEN: nodes=1  ntasks=1  cpus-per-task=32  mem=64G  time=12:00:00
%   (parfor ueber die 25 Distanzen; mehr als 25 Worker bringen nichts.
%   Zeitbedarf NICHT GEMESSEN -- aus run_mimo_comparison_distance
%   uebernommen, das bei aehnlich vielen Varianten dieselbe Schleife hat.)
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

for k = 1:numel(V)
    assert(isfolder(gearboxphy.paths.dataDir(V(k).data)), 'run_analog_bf_distance:noData', ...
        '%s fehlt - erst export_mimo_comparison_curves ausfuehren.', V(k).data);
end

if USE_PARALLEL
    fprintf('Parallel Computing Toolbox vorhanden -- Pool mit %d Workern.\n', numel(CFG.distances));
    if isempty(gcp('nocreate'))
        parpool("HPCServer", numel(CFG.distances));
    end
    % Worker erben das Arbeitsverzeichnis des Clients NICHT (siehe runSweep.m)
    wait(parfevalOnAll(@addpath, 0, gearboxphy.paths.root()));
    nWorkers = numel(CFG.distances);
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
        if SKIP_EXISTING && isfile(outFile) && localCfgMatches(outFile, CFG) && localUpToDate(outFile, dataDir)
            fprintf('\n======== %s / %s: liegt vor, uebersprungen ========\n', v.name, adcModel);
            continue
        end
        fprintf('\n======== %s / %s ========\n', v.name, adcModel);
        t0 = tic;
        E = nan(nD, nR, nM, nN); Etx = E; Erx = E; Epa = E; Eadc = E; Eps = E;
        dists = CFG.distances;
        parfor (di = 1:nD, nWorkers)
            [e, etx, erx, epa, eadc, eps_] = localOneDistance(dists(di), CFG, v, dataDir, adcModel);
            E(di,:,:,:)    = reshape(e,    [1 nR nM nN]);   %#ok<PFOUS>
            Etx(di,:,:,:)  = reshape(etx,  [1 nR nM nN]);   %#ok<PFOUS>
            Erx(di,:,:,:)  = reshape(erx,  [1 nR nM nN]);   %#ok<PFOUS>
            Epa(di,:,:,:)  = reshape(epa,  [1 nR nM nN]);   %#ok<PFOUS>
            Eadc(di,:,:,:) = reshape(eadc, [1 nR nM nN]);   %#ok<PFOUS>
            Eps(di,:,:,:)  = reshape(eps_, [1 nR nM nN]);   %#ok<PFOUS>
        end
        variant = v.name;
        save(outFile, 'E', 'Etx', 'Erx', 'Epa', 'Eadc', 'Eps', 'CFG', 'variant', 'adcModel', 'v');
        fprintf('%s / %s fertig nach %.1f min -> %s\n', v.name, adcModel, toc(t0)/60, outFile);
    end
end
end

function [E, Etx, Erx, Epa, Eadc, Eps] = localOneDistance(d, CFG, v, dataDir, adcModel)
%LOCALONEDISTANCE  Alle (Rate, M, N) bei einer Distanz, auf einem Worker.
nR = numel(CFG.rates); nM = numel(CFG.Ms); nN = numel(CFG.Ns);
E = nan(nR, nM, nN); Etx = E; Erx = E; Epa = E; Eadc = E; Eps = E;
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
            [e, ~, ~, pb] = gearboxphy.sweep.optimizeOnePoint(gear, ctx, CFG.rates(ri), x0, bnds, op);
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
            end
        end
    end
end
end

function scen = localScenario(d, CFG, v, dataDir, adcModel, configs)
%LOCALSCENARIO  Die EINE Stelle, an der aus einer Variante ein Szenario
%   wird -- validate_analog_bf ruft dieselbe Logik ueber
%   analog_bf_scenario.m auf.
scen = analog_bf_scenario(d, CFG, v, dataDir, adcModel, configs);
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
