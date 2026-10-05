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
% Die sechs Grundvarianten plus die Rice-Laeufe. K = 0 steckt bereits in
% den ersten sechs (mux_scaledB/bf_scaledB sind der Rayleigh-Fall), die
% K-Varianten kommen dazu. K = 10 wurde bewusst ausgelassen.
VARIANTS     = ["mux_fixedB" "mux_scaledB" "bf_fixedB" "bf_scaledB" "bfideal_fixedB" "bfideal_scaledB"];
for Kv = [3 30]
    VARIANTS(end+1) = sprintf("mux_scaledB_K%g", Kv); %#ok<AGROW>
    VARIANTS(end+1) = sprintf("bf_scaledB_K%g", Kv);  %#ok<AGROW>
end
% Rang-1-Endpunkt, nur MUX -- fuer BF ist bfideal_scaledB bereits dieser Fall.
VARIANTS(end+1) = "mux_scaledB_KInf";
CFG.rates     = [1e6 1e9];              % niedrig / hoch [bit/s]
CFG.distances = logspace(1, 4, 25);     % 10 m .. 10 km
CFG.fcGHz     = 28;
CFG.Ms        = [4 16 64 256];
% ACHTUNG, VORLAEUFIG: CFG.Ns ist auf [1 2 4] beschraenkt, weil erst dort
% ALLE SECHS Varianten vollstaendig vorliegen. Von den 20 (N,M)-Kombinationen
% fehlen noch sechs, alle in den teuersten Ecken der beiden
% Multiplexing-Laeufe:
%     MUX fixedB: 16x16 bei M=4,16,64,256 und 8x8 bei M=64,256
%     MUX scaledB: 8x8 und 16x16 bei M=256
%
% ALLE Varianten MUESSEN auf dieselbe Menge beschraenkt bleiben. Ideales
% Beamforming ist bereits vollstaendig (20/20); liefe es mit N bis 16,
% waehrend MUX fixedB bei 4 endet, gewaenne es allein durch die groessere
% Auswahl -- genau die einseitige Asymmetrie, gegen die der ganze
% Vergleich aufgebaut ist.
%
% Zurueckschalten, sobald die acht fehlenden Kurven da sind:
%     CFG.Ns = [1 2 4 8 16];
% Was die Beschraenkung NICHT zeigt: bei N <= 4 betraegt der Arraygewinn
% hoechstens 12 dB und die ADC-Regel kostet hoechstens 2 Bit. Ob
% Beamforming bei 16x16 noch gewinnt und ob die Regel Multiplexing dort
% kippt, bleibt offen.
CFG.Ns        = [1 2 4];
% Automatisch: auf dem Cluster parallel, ohne Parallel Computing Toolbox
% (z.B. am Arbeitsplatz) seriell. Fest auf true wuerde hier schon an
% gcp()/parpool scheitern, bevor irgendetwas gerechnet ist.
USE_PARALLEL  = ~isempty(ver('parallel'));
% Fertige Varianten ueberspringen (siehe Schleife unten).
SKIP_EXISTING = true;
%% ===================================================================

% Pfade ueber gearboxphy.paths, nicht ueber den Ort dieser Datei.
TXF = {'PA','DAC','LO_Tx','Mix_Tx'};
RXF = {'LNA','LO_Rx','Mix_Rx','ADC'};

for v = VARIANTS
    assert(isfolder(gearboxphy.paths.dataDir("SE_data_" + v)), 'run_mimo_comparison_distance:noData', ...
        '%s fehlt - erst export_mimo_comparison_curves ausfuehren.', "SE_data_" + v);
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

nD = numel(CFG.distances); nR = numel(CFG.rates);
nM = numel(CFG.Ms);        nN = numel(CFG.Ns);
for v = VARIANTS
    dataDir = gearboxphy.paths.dataDir("SE_data_" + v);
    outFile = gearboxphy.paths.resultsDir(sprintf('cmp_distance_%s.mat', v));
    % Wiederaufnahme: eine fertige Variante wird nicht neu gerechnet. Die
    % MI-Sweeps machen das seit jeher; hier fehlte es, und ein Abbruch in
    % der achten von zehn Varianten kostete alle sieben davor noch einmal.
    % SKIP_EXISTING = false erzwingt den vollen Lauf -- noetig, wenn sich
    % die Kurven unter data/ geaendert haben.
    if SKIP_EXISTING && isfile(outFile)
        fprintf('\n======== %s: liegt vor, uebersprungen ========\n', v);
        continue
    end
    fprintf('\n======== %s ========\n', v);
    t0 = tic;
    E = nan(nD, nR, nM, nN); Etx = E; Erx = E; Epa = E; Eadc = E;
    dists = CFG.distances;
    parfor (di = 1:nD, nWorkers)
        [e, etx, erx, epa, eadc] = localOneDistance(dists(di), CFG, dataDir, TXF, RXF);
        % PFOUS: checkcode sieht die Verwendung nicht, weil sie unten im
        % save() ueber den Variablennamen als STRING laeuft. Die Arrays
        % sind das Ergebnis der Schleife.
        E(di,:,:,:)    = reshape(e,    [1 nR nM nN]);   %#ok<PFOUS>
        Etx(di,:,:,:)  = reshape(etx,  [1 nR nM nN]);   %#ok<PFOUS>
        Erx(di,:,:,:)  = reshape(erx,  [1 nR nM nN]);   %#ok<PFOUS>
        Epa(di,:,:,:)  = reshape(epa,  [1 nR nM nN]);   %#ok<PFOUS>
        Eadc(di,:,:,:) = reshape(eadc, [1 nR nM nN]);   %#ok<PFOUS>
    end
    variant = v;
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
