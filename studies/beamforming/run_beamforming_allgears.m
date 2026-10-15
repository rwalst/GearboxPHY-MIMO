%RUN_BEAMFORMING_ALLGEARS  Beamforming-Sweep, nachdem ALLE Gaenge
%   Antennenkandidaten bekommen koennen (Fix in pulseGear.m/naQamGear.m).
%
%   Im vorherigen Lauf hatten nur QAM und ZXM die sieben Konfigurationen;
%   Pulse-E, Pulse-A und NA-QAM liefen SISO-only. Damit waren gerade die
%   Niedrigraten-Gaenge strukturell vom Beamforming ausgeschlossen - und
%   NA-QAM als Baseline-Gang ebenso, was jede Ersparnisangabe gegen einen
%   kuenstlich benachteiligten Bezug gerechnet haette.
%
%   Schreibt BEWUSST in eigene Verzeichnisse (..._allgears), damit die
%   alten Ergebnisse zum Vergleich erhalten bleiben.
%
%   Aufruf:  run_beamforming_allgears
%   Serieller Lauf (diese Maschine hat keine Parallel Computing Toolbox);
%   auf dem Cluster 'useParallel', true setzen.

if ~exist('QUICK','var'), QUICK = false; end

distanceVec = [50 5000];
RVec  = logspace(3,11,100);
fcVec = 28e9;
configs = { ...
    struct('N_t',1,'N_r',1), struct('N_t',2,'N_r',2), struct('N_t',4,'N_r',4), ...
    struct('N_t',8,'N_r',8), struct('N_t',16,'N_r',16), struct('N_t',32,'N_r',32), ...
    struct('N_t',64,'N_r',64) };

if QUICK
    RVec = logspace(4,10,15); configs = configs([1 2 4]);
end

for d = distanceVec
    resultsDir = gearboxphy.paths.resultsDir(sprintf('beamforming_d%g_allgears', d));
    fprintf('\n======== d = %g m -> %s ========\n', d, resultsDir);
    t0 = tic;
    scenario = gearboxphy.sweep.makeScenarioConfig( ...
        'distance', d, 'RVec', RVec, 'fcVec', fcVec, ...
        'antennaMode', "beamforming", 'beamformingConfigs', configs);
    gearboxphy.sweep.runSweep(scenario, 'resultsDir', resultsDir, 'useParallel', false);
    fprintf('d = %g m fertig nach %.1f min\n', d, toc(t0)/60);
end

fprintf('\nFertig.\n');
