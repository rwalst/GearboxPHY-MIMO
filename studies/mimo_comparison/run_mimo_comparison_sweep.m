%RUN_MIMO_COMPARISON_SWEEP  Schritt 3a des BF/MUX-Vergleichs: Gearbox-Sweep
%   ueber R_eff fuer alle sechs Varianten und drei Distanzen.
%
%   Aufruf: in gearboxphy_framework/ einfach
%       run_mimo_comparison_sweep
%   Vorher: export_mimo_comparison_curves (legt SE_data_mux_fixedB ... an).
%
%   RESSOURCEN: nodes=1  ntasks=1  cpus-per-task=100  mem=64G  time=12:00:00
%   (der Pool ist durch die 100 Ratenpunkte auf 100 Worker begrenzt, mehr
%   Kerne bringen hier nichts -- siehe runSweep.m)
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
%   AUSGABE: results_cmp_<variante>_d<d>/ (z.B. results_cmp_bf_scaledB_d5000/)

%% ===================== CONFIG =====================================
VARIANTS     = ["mux_fixedB" "mux_scaledB" "bf_fixedB" "bf_scaledB" "bfideal_fixedB" "bfideal_scaledB"];
distanceVec  = [50 500 5000];
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
% Was noch fehlt, damit das Raster wirklich voll ist: MUX fixedB hat
% M=256 bei 8x8 und 16x16 nicht (runQamSweepBHalf, zwei Kurven). Die
% Maskierung nimmt diese beiden Zellen dann auch BF weg -- das Ergebnis ist
% damit korrekt, nur nicht ausgereizt.
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
