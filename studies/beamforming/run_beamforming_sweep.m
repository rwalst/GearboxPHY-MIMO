% RUN_BEAMFORMING_SWEEP  Gearbox sweep with the antenna array used for
%   BEAMFORMING instead of spatial multiplexing, for QAM and ZXM.
%
%   In MATLAB, cd to this folder and type:
%
%       run_beamforming_sweep
%
%   Quick functional check first (a few minutes instead of ~20):
%
%       QUICK = true; run_beamforming_sweep
%
%   MODELLANNAHME (die einfachste Grenzbetrachtung, siehe
%   +physics/linkBudgetDb.m und BEAMFORMING_EXTENSION.md):
%     * Die Mutual Information bleibt die des SISO-Systems -- ein Strom,
%       unveraenderte SE-Kurve. Es wird KEINE MIMO-SE-Datei gebraucht, die
%       Konfigurationen sind daher frei waehlbar (auch 32x32, 64x64).
%     * Das Array kauft ausschliesslich PFADVERLUST: idealer Gewinn
%       N_t*N_r, also L_dB - 10*log10(N_t*N_r).
%     * Die Hardwareleistung skaliert unveraendert pro Kette: ADC/LNA/
%       Rx-Mischer mit N_r, DAC/Tx-Mischer mit N_t, LO geteilt, PA nach
%       dem eingestellten Modell.
%
%   WARUM UEBER MEHRERE DISTANZEN GESWEEPT WIRD -- das ist die eigentliche
%   Frage dieses Modells, nicht ein Extra: der Gewinn wirkt AUSSCHLIESSLICH
%   auf den PA-Term, und der ist bei kurzer Distanz verschwindend klein.
%   Gemessen bei 28 GHz, d=50 m, R=1e5: der PA macht 0.2 % der Energie aus,
%   LO_Rx und Mix_Rx zusammen 97 %. Beamforming kann dort also 8x8 Ketten
%   unmoeglich bezahlen -- bei d=50 m gewinnt fast ueberall N_t=1, und das
%   ist die RICHTIGE Antwort des Modells, kein Fehler. Erst mit wachsender
%   Distanz waechst der PA-Anteil, und damit lohnt sich das Array:
%       d =   50 m : N_t = 1,  1,  2   (bei R = 1e5, 1e7, 1e9)
%       d =  500 m : N_t = 1,  2,  8
%       d = 5000 m : N_t = 2,  8, 32
%   Ein Lauf bei nur einer (kurzen) Distanz wuerde deshalb den Eindruck
%   erwecken, Beamforming bringe grundsaetzlich nichts.
%
%   Ergebnisse landen je Distanz in results_beamforming_d<D>/ und damit
%   getrennt von den Multiplexing-Ergebnissen in results/ -- alle Laeufe
%   bleiben nebeneinander gueltig. d=50 m ist bewusst dabei, weil nur diese
%   Distanz direkt mit dem Multiplexing-Lauf vergleichbar ist.

% BEWUSST KEIN cd(): run_sweep.m macht auch keins, und ein cd aendert nur
% das Arbeitsverzeichnis des CLIENTS -- die parfor-Worker erben es nicht.
% Wer sich darauf verlaesst, dass das Framework "das aktuelle Verzeichnis"
% ist, bekommt genau deshalb einen Lauf, der lokal geht und auf dem Cluster
% nicht. runSweep.m schiebt den Framework-Pfad jetzt zusaetzlich explizit
% auf alle Worker.
if ~exist('QUICK','var'), QUICK = false; end

distanceVec = [50 500 5000];
RVec   = logspace(3,11,100);
fcVec  = [2.4 8 28 60]*1e9;
configs = { ...
    struct('N_t',1,'N_r',1), ...    % SISO-Baseline: Beamforming muss sich lohnen
    struct('N_t',2,'N_r',2), ...
    struct('N_t',4,'N_r',4), ...
    struct('N_t',8,'N_r',8), ...
    struct('N_t',16,'N_r',16), ...
    struct('N_t',32,'N_r',32), ...
    struct('N_t',64,'N_r',64) };

if QUICK
    fprintf('*** QUICK-MODUS: nur Funktionstest, NICHT die Studie ***\n');
    distanceVec = [50 5000];
    RVec  = logspace(4,10,25);
    fcVec = 28e9;
    configs = configs([1 2 4 6]);
end

for d = distanceVec
    resultsDir = gearboxphy.paths.resultsDir(sprintf('beamforming_d%g', d));
    fprintf('\n================ distance = %g m -> %s ================\n', d, resultsDir);
    scenario = gearboxphy.sweep.makeScenarioConfig( ...
        'distance', d, 'RVec', RVec, 'fcVec', fcVec, ...
        'antennaMode', "beamforming", 'beamformingConfigs', configs);

    % QUICK laeuft bewusst SERIELL: der Funktionstest soll auch auf einer
    % Maschine ohne Parallel Computing Toolbox durchlaufen (gcp wirft dort
    % einen harten Fehler), der volle Lauf nutzt den Pool wie sonst auch.
    gearboxphy.sweep.runSweep(scenario, 'resultsDir', resultsDir, 'useParallel', ~QUICK);

    figDir = fullfile(resultsDir, 'figures');
    if ~exist(figDir, 'dir'), mkdir(figDir); end
    for fi = 1:numel(scenario.fcVec)
        fig = gearboxphy.report.plotEnergyReport(resultsDir, scenario, scenario.fcVec(fi));
        exportgraphics(fig, fullfile(figDir, sprintf('energy_fc%gGHz.png', scenario.fcVec(fi)/1e9)), 'Resolution', 150);
        close(fig);
    end
    fig = gearboxphy.report.plotOptimalGearReport(resultsDir, scenario);
    exportgraphics(fig, fullfile(figDir,'optimal_gear.png'), 'Resolution', 150); close(fig);
    fig = gearboxphy.report.plotSavingsReport(resultsDir, scenario);
    exportgraphics(fig, fullfile(figDir,'savings.png'), 'Resolution', 150); close(fig);

    % Dieselben Zusatzgrafiken wie beim Multiplexing-Lauf. ACHTUNG bei der
    % Beschriftung: N_t heisst hier "Antennen je Seite", nicht "Stroeme".
    plot_gear_and_antennas(resultsDir, fullfile(figDir,'gear_and_antennas.png'));
    plot_ebit_mimo_configs(resultsDir, 16, fullfile(figDir,'ebit_beamforming_M16.png'));
end

fprintf('\nFertig. Ergebnisse in results/beamforming_d{%s}/\n', ...
    strjoin(string(distanceVec), ','));
