function run_mimo_comparison_distance()
%RUN_MIMO_COMPARISON_DISTANCE  Schritt 3b des BF/MUX-Vergleichs: zwei feste
%   Raten, Sweep ueber die Distanz, alle sechs Varianten.
%
%   Bewusst eine FUNKTION ohne Argumente statt eines Skripts: parfor ruft
%   hier eine lokale Funktion auf, und das ist nur in Funktionsdateien
%   ueber alle MATLAB-Versionen verlaesslich.
%
%   Aufruf: in gearboxphy_framework/ einfach
%       run_mimo_comparison_distance
%   Vorher: export_mimo_comparison_curves.
%
%   RESSOURCEN: nodes=1  ntasks=1  cpus-per-task=32  mem=64G  time=06:00:00
%   (parfor ueber die 25 Distanzen; mehr als 25 Worker bringen nichts)
%
%   Gegenstueck zu run_beamforming_distance_sweep.m, aber nur QAM mit
%   M in {4,16,64,256} (nur dort gibt es Rayleigh-Kurven fuer alle
%   Antennenzahlen) und mit den Kurven der sechs Varianten.
%
%   Nicht runSweep: das parallelisiert ueber die RATEN und legt einen
%   Ergebnisordner je Distanz an -- bei zwei Raten liefen zwei Worker und
%   es entstuenden 100 Ordner. Hier: parfor ueber die Distanzen, eine .mat
%   je Variante.
%
%   AUSGABE: results_cmp_distance_<variante>.mat mit
%     E, Etx, Erx, Epa, Eadc   [nD x nR x nM x nN]   J/bit (NaN = unerreichbar)
%     CFG (distances, rates, Ms, Ns, fcGHz), variant

%% ===================== CONFIG =====================================
VARIANTS     = ["mux_V0" "mux_V1" "bf_V0" "bf_V1" "bfideal_V0" "bfideal_V1"];
CFG.rates     = [1e6 1e9];              % niedrig / hoch [bit/s]
CFG.distances = logspace(1, 4, 25);     % 10 m .. 10 km
CFG.fcGHz     = 28;
CFG.Ms        = [4 16 64 256];
CFG.Ns        = [1 2 4 8 16];
USE_PARALLEL  = true;
%% ===================================================================

here = fileparts(mfilename('fullpath'));
TXF = {'PA','DAC','LO_Tx','Mix_Tx'};
RXF = {'LNA','LO_Rx','Mix_Rx','ADC'};

for v = VARIANTS
    assert(isfolder(fullfile(here, "SE_data_" + v)), 'run_mimo_comparison_distance:noData', ...
        '%s fehlt - erst export_mimo_comparison_curves ausfuehren.', "SE_data_" + v);
end

if USE_PARALLEL
    if isempty(gcp('nocreate'))
        parpool("HPCServer", numel(CFG.distances));
    end
    % Worker erben das Arbeitsverzeichnis des Clients NICHT (siehe runSweep.m)
    wait(parfevalOnAll(@addpath, 0, here));
    nWorkers = numel(CFG.distances);
else
    nWorkers = 0;                        % parfor laeuft dann seriell
end

nD = numel(CFG.distances); nR = numel(CFG.rates);
nM = numel(CFG.Ms);        nN = numel(CFG.Ns);
for v = VARIANTS
    dataDir = fullfile(here, "SE_data_" + v);
    fprintf('\n======== %s ========\n', v);
    t0 = tic;
    E = nan(nD, nR, nM, nN); Etx = E; Erx = E; Epa = E; Eadc = E;
    dists = CFG.distances;
    parfor (di = 1:nD, nWorkers)
        [e, etx, erx, epa, eadc] = localOneDistance(dists(di), CFG, dataDir, TXF, RXF);
        E(di,:,:,:)    = reshape(e,    [1 nR nM nN]);
        Etx(di,:,:,:)  = reshape(etx,  [1 nR nM nN]);
        Erx(di,:,:,:)  = reshape(erx,  [1 nR nM nN]);
        Epa(di,:,:,:)  = reshape(epa,  [1 nR nM nN]);
        Eadc(di,:,:,:) = reshape(eadc, [1 nR nM nN]);
    end
    variant = v;
    outFile = fullfile(here, sprintf('results_cmp_distance_%s.mat', v));
    save(outFile, 'E', 'Etx', 'Erx', 'Epa', 'Eadc', 'CFG', 'variant');
    fprintf('%s fertig nach %.1f min -> %s\n', v, toc(t0)/60, outFile);
end
end

function [E, Etx, Erx, Epa, Eadc] = localOneDistance(d, CFG, dataDir, TXF, RXF)
%LOCALONEDISTANCE  Alle (Rate, M, N) bei einer Distanz. Laeuft auf einem
%   Worker; laedt die Kurven dort selbst (kein Broadcast grosser ctx).
nR = numel(CFG.rates); nM = numel(CFG.Ms); nN = numel(CFG.Ns);
E = nan(nR, nM, nN); Etx = E; Erx = E; Epa = E; Eadc = E;
fc = CFG.fcGHz * 1e9;
configs = arrayfun(@(n) struct('N_t', n, 'N_r', n), CFG.Ns, 'UniformOutput', false);
scen = gearboxphy.sweep.makeScenarioConfig('distance', d, 'RVec', CFG.rates, ...
    'fcVec', fc, 'antennaMode', "multiplexing", 'qamMimoConfigs', configs, ...
    'dataDir', dataDir);
cs = gearboxphy.sweep.resolveScenarioForCarrier(scen, fc);
op = struct('tolerance', scen.tolerance, 'maxiters', scen.maxiters, ...
            'numtriesPerOpt', scen.numtriesPerOpt);
gear = gearboxphy.gears.qamGear();
for mi = 1:nM
    M = CFG.Ms(mi);
    cfgs = gear.antennaConfigs(M, cs);           % nur vorhandene Kurven
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
                Epa(ri, mi, ni)  = pb.PA;
                Eadc(ri, mi, ni) = pb.ADC;
            end
        end
    end
end
end
