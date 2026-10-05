%RUN_SISO_VS_MIMO_SCALEDB  SISO gegen MIMO, scaledB, volles N-Raster.
%
%   Aufruf:
%       addpath('/workspace/GearboxPHY-MIMO'); setupGearboxPath;
%       run_siso_vs_mimo_scaledB
%
%   RESSOURCEN: nodes=1 ntasks=1 cpus-per-task=100 mem=64G time=08:00:00
%   (wie run_mimo_comparison_sweep: der Pool ist durch die 100
%   Ratenpunkte begrenzt, mehr Kerne bringen nichts)
%
%   WARUM EIN EIGENER TREIBER, und nicht N_LIST in
%   run_mimo_comparison_sweep hochgedreht:
%
%   Dort ist N_LIST mit Absicht auf [1 2 4] beschraenkt, weil SECHS
%   Varianten gegeneinander laufen und jede dieselbe Auswahl haben muss --
%   liefe ideales BF bis N = 16, waehrend MUX fixedB bei 4 endet, gewaenne
%   es allein durch die groessere Menge. Diese Beschraenkung bleibt dort
%   stehen.
%
%   HIER gibt es keine konkurrierende Variante: verglichen wird SISO
%   (N = 1) gegen MIMO INNERHALB von scaledB. Die Fairnessauflage greift
%   also nicht, und alle 20 (M,N)-Kurven von scaledB liegen vor --
%   einschliesslich 8x8 und 16x16 bei M = 256 (B = 10 bzw. 11), die der
%   Kommentar in run_mimo_comparison_sweep noch als fehlend fuehrt.
%
%   EIGENER AUSGABEORDNER (cmp_sisomimo_scaledB_d<d>), damit die
%   vorhandenen cmp_mux_scaledB_d<d> unberuehrt bleiben. Die tragen das
%   N <= 4 der Sechs-Varianten-Studie und sind die Quelle der
%   veroeffentlichten Zahlen; sie hier zu ueberschreiben wuerde die
%   Vergleichbarkeit der ADC-Regel-Auswertung still zerstoeren.
%
%   GLEICHES RATENGITTER wie 3a (logspace(3,11,100)), damit sich die
%   Kurven punktweise gegen den vorhandenen Lauf halten lassen -- die
%   N <= 4 Spalten MUESSEN reproduzieren.
%
%   WAS DIE AUSWERTUNG WISSEN MUSS: E_per_bit_all ist (nR x nN) je
%   M-Datei, Spalte i gehoert zu antennaConfigsUsed{i}. SISO ist die
%   Spalte mit N_t == 1. Die Huellkurve E_per_bit ist das Minimum
%   darueber und beantwortet die Frage NICHT -- sie verschweigt, wie
%   teuer SISO dort war, wo MIMO gewinnt.
%
%   GRENZEN DES ERGEBNISSES, beide gerichtet:
%     * exportToGearboxSEData nimmt results.lower. Bei SISO ist das exakt
%       (Luecke 0,00 %), bei N >= 4 und M >= 64 eine Schranke mit 7-13 %
%       Slack nahe der Saettigung. Die Verzerrung laeuft GEGEN MIMO, jeder
%       MIMO-Vorsprung ist damit eine untere Schranke.
%     * Die SISO-Kurven enden bei 25 dB Gesamt-SNR, die 16x16-Kurven bei
%       37 dB -- dieselbe Quellachse, um 10*log10(N) verschoben. Oberhalb
%       liefert der Gearbox NaN statt zu extrapolieren. Das ist
%       Kurvenabdeckung, nicht Physik.
%
%   AUSGABE: results/cmp_sisomimo_scaledB_d<d>/

%% ===================== CONFIG =====================================
VARIANT      = "mux_scaledB";
distanceVec  = [50 500 5000];
fcVec        = 28e9;
RVec         = logspace(3, 11, 100);     % identisch zu Schritt 3a
N_LIST       = [1 2 4 8 16];             % siehe Kopf: hier zulaessig
USE_PARALLEL = ~isempty(ver('parallel'));
%% ===================================================================

configs = arrayfun(@(n) struct('N_t', n, 'N_r', n), N_LIST, 'UniformOutput', false);

dataDir = gearboxphy.paths.dataDir("SE_data_" + VARIANT);
assert(isfolder(dataDir), 'run_siso_vs_mimo_scaledB:noData', ...
    '%s fehlt - erst export_mimo_comparison_curves ausfuehren.', dataDir);

% Vorab pruefen, dass die Kurven fuer JEDES (M,N) wirklich da sind. Fehlt
% eine, laesst antennaConfigs sie still weg und die Spalte fehlt im
% Ergebnis -- das faellt erst in der Auswertung auf, Stunden spaeter.
fprintf('Kurvenabdeckung in %s:\n', dataDir);
nMiss = 0;
for M = [4 16 64 256]
    row = sprintf('  M=%-4d', M);
    for n = N_LIST
        if n == 1
            f = fullfile(dataDir, sprintf('SE_%d_QAM.mat', M));
        else
            f = fullfile(dataDir, sprintf('SE_%d_QAM_%dx%d.mat', M, n, n));
        end
        if isfile(f)
            row = [row sprintf('  %2dx%-2d ok', n, n)]; %#ok<AGROW>
        else
            row = [row sprintf('  %2dx%-2d FEHLT', n, n)]; %#ok<AGROW>
            nMiss = nMiss + 1;
        end
    end
    fprintf('%s\n', row);
end
assert(nMiss == 0, 'run_siso_vs_mimo_scaledB:incomplete', ...
    '%d Kurven fehlen - der Lauf waere unvollstaendig.', nMiss);

if USE_PARALLEL
    fprintf('Parallel Computing Toolbox vorhanden.\n');
else
    fprintf('KEINE Parallel Computing Toolbox - seriell (dauert laenger).\n');
end

tAll = tic;
for d = distanceVec
    resultsDir = gearboxphy.paths.resultsDir(sprintf('cmp_sisomimo_scaledB_d%g', d));
    fprintf('\n======== %s, d = %g m, N = [%s] -> %s ========\n', ...
        VARIANT, d, num2str(N_LIST), resultsDir);
    t0 = tic;
    scenario = gearboxphy.sweep.makeScenarioConfig( ...
        'distance', d, 'RVec', RVec, 'fcVec', fcVec, ...
        'antennaMode', "multiplexing", 'qamMimoConfigs', configs, ...
        'dataDir', dataDir);
    gearboxphy.sweep.runSweep(scenario, 'resultsDir', resultsDir, ...
        'useParallel', USE_PARALLEL);
    fprintf('d = %g m fertig nach %.1f min\n', d, toc(t0)/60);
end
fprintf('\nAlle %d Laeufe fertig nach %.1f min.\n', numel(distanceVec), toc(tAll)/60);
