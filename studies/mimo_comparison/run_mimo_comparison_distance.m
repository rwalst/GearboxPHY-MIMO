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
%   RESSOURCEN: 25 Worker, 64 GB, 6 h. Ein Knoten.
%   (parfor ueber die 25 Distanzen; mehr als 25 Worker bringen nichts)
%
%   ZIH-Cluster statt Windows: sbatch hpc/zih/submit_study.sbatch run_mimo_comparison_distance
%   mit --cpus-per-task=26 (einer fuer den Client). Anleitung und
%   Schritt 0: docs/HPC_RUNBOOK_ZIH.md.
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
%   LO-VERTEILUNG ueber LO_MODEL im CONFIG-Block: "per_mixer" (Vorgabe seit
%   2026-10-15, LO-Puffer je weiterem Mischer) oder "shared". Das Suffix
%   traegt der ABWEICHENDE Fall: "shared" schreibt nach
%   cmp_distance_<variante>_loshared.mat. Der Aufschlag trifft nur die
%   digitale Seite -- siehe CONFIG. Dateien ohne Suffix von vor dem
%   2026-10-15 sind mit dem alten Modellsatz (und gemeinsamem LO) gerechnet;
%   ihr Fingerabdruck passt nicht mehr, sie werden neu gerechnet und
%   ueberschrieben.
%
%   AUSGABE: results_cmp_distance_<variante>[_loshared].mat mit
%     E, Etx, Erx, Epa, Eadc   [nD x nR x nM x nN]   J/bit (NaN = unerreichbar)
%     CFG (distances, rates, Ms, Ns, fcGHz), variant

%% ===================== CONFIG =====================================
% Die sechs Grundvarianten plus die Rice-Laeufe. K = 0 steckt bereits in
% den ersten sechs (mux_scaledB/bf_scaledB sind der Rayleigh-Fall), die
% K-Varianten kommen dazu. K = 10 wurde bewusst ausgelassen.
VARIANTS     = ["mux_fixedB" "mux_scaledB" "bf_fixedB" "bf_scaledB" "bfideal_fixedB" "bfideal_scaledB"];
for Kv = [3 30]
    VARIANTS(end+1) = sprintf("mux_scaledB_K%g", Kv); %#ok<AGROW>
    VARIANTS(end+1) = sprintf("bf_fixedB_K%g", Kv);   %#ok<AGROW>
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
% LO-VERTEILUNG. "shared" (Vorgabe) heisst: ein LO je Seite, gleich wie
% viele Mischer -- so sind alle bisherigen Ergebnisse gerechnet.
% "per_mixer" laesst jeden Mischer UEBER DEN ERSTEN HINAUS einen Puffer
% zahlen, bei 28 GHz 12.5 mW (+physics/loDistributionPower.m).
%
% DER AUFSCHLAG TRIFFT NUR DIE DIGITALE SEITE, und zwar von selbst: die
% Formel ist (nMischer - 1) * P_buf, und eine analoge Kette hat EINEN
% Mischer. Nachgemessen am 2026-10-15 bei 16x16 und 28 GHz: digital
% 214.4 mW gegen 26.9 mW (Aufschlag 187.5 mW = 15 x 12.5 mW), analog
% 26.9 mW (Aufschlag 0). In DIESER Studie sind ohnehin alle zwoelf
% Varianten digital -- der Aufschlag trifft also beide Seiten des
% Vergleichs, nur mit ihrem jeweiligen N.
%
% WARUM DAS NICHT NEUTRAL IST: wo MUX und BF dasselbe N waehlen, kuerzt
% sich der LO-Anteil im Verhaeltnis q heraus. Gemessen bei R = 1 Gbit/s,
% K = 0, fixedB: nur 12 von 25 Distanzen. Rund um die Schnittdistanz
% d* ~ 721 m waehlt MUX N = 16 und BF N = 8, dort zahlt MUX also mehr --
% d* wandert mit per_mixer zu kleineren Distanzen. Richtung bekannt,
% Groesse nicht; genau dafuer ist dieser Schalter da.
%
% Das Suffix traegt der abweichende Fall: "shared" schreibt nach
% cmp_distance_<variante>_loshared.mat, der Standard per_mixer ohne Suffix.
% Bis 2026-10-15 war es umgekehrt (per_mixer bekam "_permixer").
LO_MODEL      = "per_mixer";               % "shared" | "per_mixer"
CFG.loModel   = LO_MODEL;
CFG.Ms        = [4 16 64 256];
% N JE VARIANTE, nicht global. Bis 2026-10-07 stand hier CFG.Ns = [1 2 4]
% fuer ALLE Varianten, weil die MUX-Laeufe damals nicht weiter reichten.
% Inzwischen liegen die Kurven bis N = 16 vor -- aber nicht fuer jede
% Variante, und ein globales Ns waere jetzt die schlechteste Wahl: bei den
% Rice-Varianten liefe es ins Leere, bei den uebrigen wuerde es Daten
% verschenken. SEIT 2026-10-15 rechnen die Rice-Laeufe bis N = 16 (die
% letzten zwei Kurven, 16x16/M=256 bei K=3 und K=30, sind da) -- je Variante
% zu bestimmen bleibt es trotzdem, denn welches Raster wirklich vorliegt,
% entscheidet der Ordner unter data/ und nicht die Quelle: der Export muss
% dafuer erst neu laufen.
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
else
    fprintf('Keine Parallel Computing Toolbox -- parfor laeuft seriell.\n');
    nWorkers = 0;
end

nD = numel(CFG.distances); nR = numel(CFG.rates);
nM = numel(CFG.Ms);        % nN kommt je Variante aus NS_BY_VARIANT, s. Schleife
for v = VARIANTS
    dataDir = gearboxphy.paths.dataDir("SE_data_" + v);
    loSuffix = "";
    if CFG.loModel == "shared", loSuffix = "_loshared"; end
    outFile = gearboxphy.paths.resultsDir(sprintf('cmp_distance_%s%s.mat', v, loSuffix));
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
    % WIEDERVERWENDEN STATT NEU RECHNEN -- siehe +data/gridFingerprint.m.
    % Der Schluessel deckt jede Zelle des (Distanz, M, N)-Gitters ab; die
    % Form "cmp_distance/v1" sorgt dafuer, dass nur Dateien mit demselben
    % Variablensatz uebernommen werden.
    fp = gearboxphy.data.gridFingerprint("cmp_distance/v1", ...
        @(d) gearboxphy.sweep.makeScenarioConfig('distance', d, 'RVec', CFG.rates, ...
            'fcVec', CFG.fcGHz*1e9, 'antennaMode', "multiplexing", ...
            'qamMimoConfigs', arrayfun(@(n) struct('N_t', n, 'N_r', n), CFG.Ns, ...
                'UniformOutput', false), 'dataDir', dataDir, ...
            'loDistributionModel', CFG.loModel), CFG);
    % Seit 2026-10-15 zaehlt zum Ueberspringen auch der Fingerabdruck: eine
    % Datei mit anderen Hardwaremodellen gilt als nicht fertig.
    if SKIP_EXISTING && isfile(outFile) && localCfgMatches(outFile, CFG) ...
            && localUpToDate(outFile, dataDir) && gearboxphy.data.fingerprintMatches(string(outFile), fp)
        fprintf('\n======== %s: liegt vor (gleicher Schluessel), uebersprungen ========\n', v);
        continue
    end
    if gearboxphy.data.fetchFromStore(fp, outFile)
        fprintf('\n======== %s: schon gerechnet (%s), uebernommen ========\n', v, fp);
        continue
    end
    fprintf('\n======== %s ========\n', v);
    t0 = tic;
    E = nan(nD, nR, nM, nN); Etx = E; Erx = E; Epa = E; Eadc = E;
    % ARBEITSPUNKT JE ZELLE (SE, noetiger SNR). Ohne das stehen im Ergebnis
    % nur Energien, und die Spektraleffizienz, bei der das Gearbox den Punkt
    % betreibt, ist nach dem Lauf nicht mehr rekonstruierbar.
    SE = E; SNRrx_dB = E;
    dists = CFG.distances;
    parfor (di = 1:nD, nWorkers)
        [e, etx, erx, epa, eadc, se, snr] = localOneDistance(dists(di), CFG, dataDir, TXF, RXF);
        % PFOUS: checkcode sieht die Verwendung nicht, weil sie unten im
        % save() ueber den Variablennamen als STRING laeuft. Die Arrays
        % sind das Ergebnis der Schleife.
        E(di,:,:,:)    = reshape(e,    [1 nR nM nN]);   %#ok<PFOUS>
        Etx(di,:,:,:)  = reshape(etx,  [1 nR nM nN]);   %#ok<PFOUS>
        Erx(di,:,:,:)  = reshape(erx,  [1 nR nM nN]);   %#ok<PFOUS>
        Epa(di,:,:,:)  = reshape(epa,  [1 nR nM nN]);   %#ok<PFOUS>
        Eadc(di,:,:,:) = reshape(eadc, [1 nR nM nN]);   %#ok<PFOUS>
        SE(di,:,:,:)       = reshape(se,  [1 nR nM nN]);   %#ok<PFOUS>
        SNRrx_dB(di,:,:,:) = reshape(snr, [1 nR nM nN]);   %#ok<PFOUS>
    end
    variant = v;
    resultFingerprint = fp;
    save(outFile, 'E', 'Etx', 'Erx', 'Epa', 'Eadc', 'SE', 'SNRrx_dB', 'CFG', 'variant', 'resultFingerprint');
    gearboxphy.data.publishToStore(fp, outFile);
    fprintf('%s fertig nach %.1f min -> %s\n', v, toc(t0)/60, outFile);
end
end

function [E, Etx, Erx, Epa, Eadc, SE, SNRrx_dB] = localOneDistance(d, CFG, dataDir, TXF, RXF)
%LOCALONEDISTANCE  Alle (Rate, M, N) bei einer Distanz. Laeuft auf einem
%   Worker; laedt die Kurven dort selbst (kein Broadcast grosser ctx).
nR = numel(CFG.rates); nM = numel(CFG.Ms); nN = numel(CFG.Ns);
E = nan(nR, nM, nN); Etx = E; Erx = E; Epa = E; Eadc = E;
SE = E; SNRrx_dB = E;
fc = CFG.fcGHz * 1e9;
configs = arrayfun(@(n) struct('N_t', n, 'N_r', n), CFG.Ns, 'UniformOutput', false);
scen = gearboxphy.sweep.makeScenarioConfig('distance', d, 'RVec', CFG.rates, ...
    'fcVec', fc, 'antennaMode', "multiplexing", 'qamMimoConfigs', configs, ...
    'dataDir', dataDir, 'loDistributionModel', CFG.loModel);
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
            % opPt, nicht op: op ist hier schon die Optimierer-Parameter.
            [e, ~, ~, pb, opPt] = gearboxphy.sweep.optimizeOnePoint(gear, ctx, CFG.rates(ri), x0, bnds, op);
            SE(ri, mi, ni) = opPt.SE; SNRrx_dB(ri, mi, ni) = opPt.SNR_rx_dB;
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
