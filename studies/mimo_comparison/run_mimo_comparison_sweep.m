function run_mimo_comparison_sweep(variants, distances)
%RUN_MIMO_COMPARISON_SWEEP  Schritt 3a des BF/MUX-Vergleichs: Gearbox-Sweep
%   ueber R_eff fuer alle Varianten und drei Distanzen.
%
%   Aufruf: in GearboxPHY-MIMO/ einfach
%       run_mimo_comparison_sweep                      % alles, wie bisher
%       run_mimo_comparison_sweep(["mux_fixedB" "bf_fixedB"])   % Teilmenge
%       run_mimo_comparison_sweep([], [50 5000])       % nur zwei Distanzen
%   Vorher: export_mimo_comparison_curves (legt SE_data_mux_fixedB ... an).
%
%   WARUM EINE FUNKTION MIT TEILMENGE (seit 2026-10-15). Der Lauf besteht aus
%   15 unabhaengigen Einheiten (5 Varianten x 3 Distanzen), jede mit 100
%   Ratenpunkten und damit auf 100 Worker begrenzt. Hintereinander sind das
%   rund 120 h; auf vier Sitzungen verteilt ein Viertel davon. Vorher war
%   dies ein SKRIPT mit festem VARIANTS -- eine Teilmenge liess sich nicht
%   uebergeben, und eine Variable gleichen Namens im Basis-Workspace wurde
%   von Zeile 38 ohnehin ueberschrieben. Ohne Argumente ist das Verhalten
%   unveraendert.
%
%   Die Einheiten schreiben in GETRENNTE Ergebnisordner (cmp_<variante>_d<d>),
%   zwei Sitzungen kommen sich also nicht in die Quere -- solange sie
%   verschiedene Teilmengen bekommen. Dieselbe Teilmenge zweimal zu starten
%   ist nicht gefaehrlich, nur doppelte Arbeit: runSweep ueberspringt
%   Fertiges nur bei passendem Fingerabdruck und setzt Checkpoints je Punkt.
%
%   RESSOURCEN: 100 Worker, 64 GB, 12 h. Ein Knoten.
%   (der Pool ist durch die 100 Ratenpunkte auf 100 Worker begrenzt, mehr
%   Kerne bringen hier nichts -- siehe runSweep.m)
%
%   ZIH-Cluster statt Windows: sbatch hpc/zih/submit_study.sbatch run_mimo_comparison_sweep
%   mit --cpus-per-task=101 (einer fuer den Client). Anleitung und
%   Schritt 0: docs/HPC_RUNBOOK_ZIH.md.
%
%   WAS GERECHNET WIRD: 6 Varianten x 3 Distanzen = 18 Laeufe von
%   runSweep, jeweils alle Gaenge. Fuer den Vergleich zaehlt nur QAM mit
%   M in {4,16,64,256}: nur dort gibt es Rayleigh-Kurven fuer alle
%   Antennenzahlen. ZXM, Pulse, NA-QAM und QAM M=1024 laufen SISO mit Gasts
%   AWGN-Kurven mit und werden von analyze_mimo_comparison ignoriert.
%
%   Modus "multiplexing" fuer ALLE sechs Varianten -- siehe
%   export_mimo_comparison_curves.m: der Array-Effekt steckt in der Kurve,
%   Hardware skaliert je Kette gleich, der Unterschied BF/MUX liegt allein
%   in der Kurve.
%
%   UNTERBRECHBAR: runSweep ueberspringt fertige Kombinationen und nutzt
%   Punkt-Checkpoints. Nach einem Abbruch einfach erneut starten.
%
%   AUSGABE: results_cmp_<variante>_d<d>/ (z.B. results_cmp_bf_fixedB_d5000/)

%% ===================== CONFIG =====================================
% scaledB EXISTIERT FUER BEAMFORMING NICHT (Entscheidung 2026-10-15): das
% +log2(Nt) der Regel bezahlt die Ueberlagerung von Nt Stroemen an jeder
% Empfangsantenne, und beim Beamforming kommt EIN Strom an. bf_scaledB und
% bfideal_scaledB sind deshalb aus der Liste heraus; die gerechneten
% Ergebnisse und Kurvenordner bleiben liegen, werden aber nicht ausgewertet.
VARIANTS     = ["mux_fixedB" "mux_scaledB" "bf_fixedB" "bfideal_fixedB"];
% alphabetB nur, wenn exportiert. Die Regel ist MUX-only -- bei Beamforming
% kommt EIN Strom an, das beobachtete Alphabet ist M unabhaengig von N_t,
% adcBitsRule faellt dort mit fixedB zusammen; ein BF-alphabetB-Lauf waere
% bitgleich zu bf_fixedB. Ohne diesen Eintrag fehlt der Ratenachse und
% analyze_best_gear Teil B die dritte ADC-Spalte -- genau das war der Stand
% am 2026-10-08, obwohl 3b alphabetB schon trug.
if isfolder(gearboxphy.paths.dataDir("SE_data_mux_alphabetB"))
    VARIANTS(end+1) = "mux_alphabetB";
end
distanceVec  = [50 500 5000];
% ---- Teilmenge aus den Argumenten, s. Kopf -------------------------------
if nargin >= 1 && ~isempty(variants)
    want    = string(variants);
    unknown = setdiff(want, VARIANTS);
    assert(isempty(unknown), 'run_mimo_comparison_sweep:unknownVariant', ...
        ['Unbekannte Variante(n): %s.\nBekannt sind: %s.\n' ...
         'Bei bf_scaledB/bfideal_scaledB: die gibt es seit E8 nicht mehr ' ...
         '(scaledB existiert fuer Beamforming nicht).'], ...
        strjoin(unknown, ', '), strjoin(VARIANTS, ', '));
    VARIANTS = want;
end
if nargin >= 2 && ~isempty(distances)
    want    = double(distances);
    unknown = setdiff(want, distanceVec);
    assert(isempty(unknown), 'run_mimo_comparison_sweep:unknownDistance', ...
        'Unbekannte Distanz(en): %s. Bekannt sind: %s.', ...
        mat2str(unknown), mat2str(distanceVec));
    distanceVec = want;
end
fprintf('3a: %d Varianten x %d Distanzen = %d Laeufe (%s | %s)\n', ...
    numel(VARIANTS), numel(distanceVec), numel(VARIANTS)*numel(distanceVec), ...
    strjoin(VARIANTS, ','), strjoin(string(distanceVec), ','));
fcVec        = 28e9;
RVec         = logspace(3, 11, 100);
% N_LIST deckt das volle Raster ab. Bis 2026-10-07 stand hier [1 2 4] mit
% der Begruendung, alle sechs Varianten muessten auf dieselbe Menge
% beschraenkt bleiben -- sonst gewinnt ein Modus allein durch die groessere
% Auswahl. Die Begruendung gilt weiter, nur liegt die Durchsetzung jetzt an
% der richtigen Stelle: analyze_bf_vs_mux_qam maskiert je Zelle SYMMETRISCH
% (fehlt eine (M,N)-Kombination auf einer Seite, wird sie auf beiden
% verworfen) und benutzt dafuer E_per_bit_all zusammen mit
% antennaConfigsUsed, nicht die hier schon gebildete Huellkurve E_per_bit.
%
% DAS RASTER IST VOLL (geprueft am 2026-10-15). Hier stand bis dahin, MUX
% fixedB fehle M=256 bei 8x8 und 16x16; das trifft nicht mehr zu --
% qam/results/bHalf traegt alle fuenf N fuer M=256 (B=7), und
% data/SE_data_mux_fixedB ebenso. Die symmetrische Maskierung verwirft
% deshalb keine Zelle mehr aus diesem Grund.
N_LIST       = [1 2 4 8 16];
USE_PARALLEL = true;
%% ===================================================================

% Pfade ueber gearboxphy.paths, nicht ueber den Ort dieser Datei.
configs = arrayfun(@(n) struct('N_t', n, 'N_r', n), N_LIST, 'UniformOutput', false);

% Alle Datenordner vorab pruefen -- lieber sofort abbrechen als nach
% Stunden beim dritten Ordner
for v = VARIANTS
    dd = gearboxphy.paths.dataDir("SE_data_" + v);
    assert(isfolder(dd), 'run_mimo_comparison_sweep:noData', ...
        '%s fehlt - erst export_mimo_comparison_curves ausfuehren.', dd);
end

tAll = tic;
for v = VARIANTS
    dataDir = gearboxphy.paths.dataDir("SE_data_" + v);
    for d = distanceVec
        resultsDir = gearboxphy.paths.resultsDir(sprintf('cmp_%s_d%g', v, d));
        fprintf('\n======== %s, d = %g m -> %s ========\n', v, d, resultsDir);
        t0 = tic;
        scenario = gearboxphy.sweep.makeScenarioConfig( ...
            'distance', d, 'RVec', RVec, 'fcVec', fcVec, ...
            'antennaMode', "multiplexing", 'qamMimoConfigs', configs, ...
            'dataDir', dataDir);
        gearboxphy.sweep.runSweep(scenario, 'resultsDir', resultsDir, ...
            'useParallel', USE_PARALLEL);
        fprintf('%s, d = %g m fertig nach %.1f min\n', v, d, toc(t0)/60);
    end
end
fprintf('\nAlle %d Laeufe fertig nach %.1f min.\n', numel(VARIANTS)*numel(distanceVec), toc(tAll)/60);
end
