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
% alphabetB nur, wenn exportiert -- die Regel ist MUX-only (bei BF kommt EIN
% Strom an, das beobachtete Alphabet ist M unabhaengig von N_t, alphabetB
% ist dort identisch zu fixedB).
if isfolder(gearboxphy.paths.dataDir("SE_data_mux_alphabetB"))
    VARIANTS(end+1) = "mux_alphabetB";
end
CFG.rates     = [1e6 1e9];              % niedrig / hoch [bit/s]
CFG.distances = logspace(1, 4, 25);     % 10 m .. 10 km
CFG.fcGHz     = 28;
CFG.Ms        = [4 16 64 256];
% N JE VARIANTE, nicht global. Bis 2026-10-07 stand hier CFG.Ns = [1 2 4]
% fuer ALLE Varianten, weil die MUX-Laeufe damals nicht weiter reichten.
% Inzwischen liegen die Kurven bis N = 16 vor -- aber nicht fuer jede
% Variante, und ein globales Ns waere jetzt die schlechteste Wahl: bei den
% Rice-Varianten liefe es ins Leere (die MI-Laeufe dort rechnen nur N <= 4,
% runQamSweepRiceMux/Bf), bei den uebrigen wuerde es Daten verschenken.
%
% Abdeckung, geprueft an data/SE_data_<variante>/ am 2026-10-07:
%     mux_scaledB, bf_fixedB, bf_scaledB, bfideal_*   20/20, N bis 16
%     mux_fixedB      18/20 -- M=256 fehlt bei 8x8 und 16x16
%     mux_alphabetB   15/20 -- B > 20 ist nicht rechenbar (alphabetGrid)
%     mux_scaledB_KInf 20/20 nach dem Re-Export (die Kurven kamen nach dem
%                      letzten Exportlauf, der Ordner war nur veraltet)
%     *_K3, *_K30      12/20 -- die MI-Laeufe rechnen nur N <= 4
%
% DIE FAIRNESS LIEGT NICHT MEHR HIER. Frueher musste jede Variante auf
% dieselbe Ns-Menge beschraenkt werden, damit kein Modus durch die
% groessere Auswahl gewinnt. Das ist jetzt Sache der AUSWERTUNG:
% analyze_bf_vs_mux_qam maskiert je Zelle symmetrisch -- fehlt eine
% (M,N)-Kombination auf einer Seite, wird sie auf BEIDEN verworfen. Damit
% darf hier jede Variante so weit rechnen, wie ihre Kurven reichen.
NS_FULL = [1 2 4 8 16];                 % Obergrenze dessen, was die Studie kennt
% KEINE festverdrahtete Tabelle je Variante mehr. Hier stand eine Map, die
% die Rice-Varianten auf [1 2 4] festnagelte, weil ihre MI-Laeufe damals
% nicht weiter reichten. Das ist genau die Sorte Eintrag, die nach dem
% naechsten MI-Lauf still falsch wird: die Kurven liegen dann bis N = 16
% vor, die Tabelle sagt weiter 4, und niemand merkt es. Stattdessen wird je
% Variante im Exportordner nachgesehen, welche Antennenzahlen ueberhaupt
% Kurven haben (localAvailableNs) -- die Daten sind die Quelle, nicht eine
% Liste im Treiber.
CFG.Ns        = NS_FULL;                % Vorgabe; je Variante unten gesetzt
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
nM = numel(CFG.Ms);        % nN kommt je Variante aus NS_BY_VARIANT, s. Schleife
for v = VARIANTS
    dataDir = gearboxphy.paths.dataDir("SE_data_" + v);
    outFile = gearboxphy.paths.resultsDir(sprintf('cmp_distance_%s.mat', v));
    % Wiederaufnahme: eine fertige Variante wird nicht neu gerechnet. Die
    % MI-Sweeps machen das seit jeher; hier fehlte es, und ein Abbruch in
    % der achten von zehn Varianten kostete alle sieben davor noch einmal.
    % SKIP_EXISTING = false erzwingt den vollen Lauf -- noetig, wenn sich
    % die Kurven unter data/ geaendert haben.
    % N je Variante aus den vorhandenen Kurven, s. Kopf.
    CFG.Ns = localAvailableNs(dataDir, NS_FULL, CFG.Ms);
    assert(~isempty(CFG.Ns), 'run_mimo_comparison_distance:noCurves', ...
        '%s enthaelt keine einzige (M,N)-Kurve der Studie.', dataDir);
    nN = numel(CFG.Ns);
    fprintf('   N = %s (aus den vorhandenen Kurven)\n', mat2str(CFG.Ns));
    % SKIP nur bei PASSENDER Signatur. Vorher genuegte isfile(outFile), und
    % das war eine Falle: aendert sich CFG (z.B. Ns von [1 2 4] auf
    % [1 2 4 8 16]), liegt die alte Datei noch da und der Lauf ueberspringt
    % sie als fertig -- die Auswertung rechnet dann still auf dem alten
    % Raster weiter. Dieselbe Klasse Fehler wie die Checkpoint-Signatur in
    % QuantizedMimoMI/qam/sweep/runRuleSweep.m.
    if SKIP_EXISTING && isfile(outFile) && localCfgMatches(outFile, CFG) ...
            && localUpToDate(outFile, dataDir)
        fprintf('\n======== %s: liegt vor (passende CFG, Kurven aelter), uebersprungen ========\n', v);
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

function Ns = localAvailableNs(dataDir, NsAll, Ms)
%LOCALAVAILABLENS  Welche Antennenzahlen hat dieser Exportordner wirklich?
%   Behalten wird ein N, sobald dafuer MINDESTENS EINE Modulationsordnung
%   eine Kurve hat -- die Raggedness innerhalb eines N (etwa alphabetB, dem
%   M=64/256 bei N>=8 fehlt, oder die bewusst nicht gerechneten Ecken der
%   Rice-Laeufe) faengt die symmetrische Maskierung in
%   analyze_bf_vs_mux_qam ab, nicht diese Funktion.
%
%   N = 1 heisst SE_<M>_QAM.mat, N > 1 heisst SE_<M>_QAM_<N>x<N>.mat.
Ns = [];
for N = NsAll
    found = false;
    for M = Ms
        if N == 1, nm = sprintf('SE_%d_QAM.mat', M);
        else,      nm = sprintf('SE_%d_QAM_%dx%d.mat', M, N, N);
        end
        if isfile(fullfile(dataDir, nm)), found = true; break; end
    end
    if found, Ns(end+1) = N; end %#ok<AGROW>
end
end

function tf = localUpToDate(outFile, dataDir)
%LOCALUPTODATE  Sind die QUELLKURVEN aelter als das Ergebnis?
%   Die CFG-Pruefung allein genuegt nicht: kommen neue Kurven in
%   data/SE_data_<variante>/, bleibt die CFG gleich und der Lauf haelt das
%   alte Ergebnis fuer fertig. Genau das passierte am 2026-10-07, als die
%   zwei fehlenden MUX-fixedB-Kurven (M=256 bei 8x8/16x16) vom HPC kamen --
%   cmp_distance_mux_fixedB.mat trug die richtige CFG und waere
%   uebersprungen worden, obwohl die Eingangsdaten andere sind.
o = dir(outFile);
d = dir(fullfile(dataDir, '*.mat'));
tf = ~isempty(d) && max([d.datenum]) <= o.datenum;
end

function tf = localCfgMatches(outFile, CFG)
%LOCALCFGMATCHES  Traegt die vorhandene Datei dasselbe Raster?
tf = false;
try
    T = load(outFile, 'CFG');
catch
    return
end
if ~isfield(T, 'CFG'), return; end
C = T.CFG;
tf = isequal(double(C.distances(:).'), double(CFG.distances(:).')) ...
  && isequal(double(C.rates(:).'),     double(CFG.rates(:).')) ...
  && isequal(double(C.Ms(:).'),        double(CFG.Ms(:).')) ...
  && isequal(double(C.Ns(:).'),        double(CFG.Ns(:).'));
end
