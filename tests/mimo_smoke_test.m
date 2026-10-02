% MIMO_SMOKE_TEST End-to-end check of the MIMO nested-enumeration
%   pipeline using SE_16_QAM_2x2.mat. Originally exercised the synthetic
%   placeholder curve from generate_synthetic_mimo_curve.m; SE_16_QAM_2x2
%   (and the other 8 MIMO SE_data files) have since been replaced with
%   real QuantizedMimoMI/qam simulation results (results.lower per config),
%   so this is now a wiring test AND a real-data smoke test.
%
%   Run from gearboxphy_framework/ (relative paths below assume that cwd,
%   same convention as run_sweep.m). obw()-stub addpath removed - the
%   real Signal Processing Toolbox is installed, so containmentBandwidth.m
%   uses the genuine obw() rather than the goldenmaster shim.
%
%   DATENORDNER: die MIMO-Kurven in SE_data sind je STROM normiert und
%   tragen kein snrReference -- loadSECurve.m weist sie seit der
%   SNR-Korrektur ab (Multiplexing bekam sonst 10*log10(N_t) dB
%   geschenkt). Der Test laeuft deshalb auf SE_data_mux_fixedB aus
%   export_mimo_comparison_curves.m.
dataDir = gearboxphy.paths.dataDir("SE_data_mux_fixedB");
assert(isfolder(dataDir), 'mimo_smoke_test:noData', ...
    ['%s fehlt. Die MIMO-Kurven in SE_data werden seit der SNR-Korrektur ' ...
     'abgewiesen - erst export_mimo_comparison_curves ausfuehren.'], dataDir);

scenario = gearboxphy.sweep.makeScenarioConfig( ...
    'distance', 50, ...
    'RVec', logspace(6,9,4), ...
    'fcVec', 28e9, ...
    'maxiters', 300, 'tolerance', 1e-6, 'numtriesPerOpt', 2, ...
    'dataDir', dataDir, ...
    'qamMimoConfigs', {struct('N_t',1,'N_r',1), struct('N_t',2,'N_r',2)});

% Einmal aufloesen: der Name wird weiter unten sowohl an runSweep/die
% Report-Funktionen gereicht als auch direkt mit fullfile/load benutzt.
% Nur ein absoluter Pfad ist an beiden Stellen derselbe Ordner.
rd = gearboxphy.paths.resultsDir('mimo_smoke_results');
if exist(rd, 'dir'); rmdir(rd, 's'); end

% Direct unit-level check first: does qamGear actually let a 2x2 config
% win at at least one point, given the synthetic curve's doubled SE?
gear = gearboxphy.gears.qamGear();
cs = gearboxphy.sweep.resolveScenarioForCarrier(scenario, 28e9);
antennaConfigs = gear.antennaConfigs(16, cs);
assert(numel(antennaConfigs) == 2, 'expected 2 antenna config candidates');
ctxList = {gear.prepare(16, cs, antennaConfigs{1}), gear.prepare(16, cs, antennaConfigs{2})};
assert(ctxList{1}.N_t==1 && ctxList{1}.N_r==1, 'first candidate should be SISO');
assert(ctxList{2}.N_t==2 && ctxList{2}.N_r==2, 'second candidate should be 2x2');
x0 = gear.initialGuess(16, cs);
bounds = gear.optimizerBounds(16, cs);
optParams = struct('tolerance', cs.tolerance, 'maxiters', cs.maxiters, 'numtriesPerOpt', cs.numtriesPerOpt);
[e, b, g, ~, nt, nr] = gearboxphy.sweep.optimizeOnePointBestConfig(gear, ctxList, antennaConfigs, 1e9, x0, bounds, optParams);
fprintf('QAM order=16, R=1e9: best config N_t=%d N_r=%d, E_per_bit=%.4e, B=%.4e, gamma=%.4e\n', nt, nr, e, b, g);
assert(isfinite(e), 'expected a feasible point at R=1e9');
fprintf('optimizeOnePointBestConfig direct check OK (winner: %dx%d)\n', nt, nr);

% Full sweep + result schema check
gearboxphy.sweep.runSweep(scenario, 'resultsDir', rd, 'useParallel', false);
fprintf('runSweep (with MIMO candidates) completed OK\n');

qamKey = gearboxphy.data.resultKey("QAM", 16, 28e9);
S = gearboxphy.data.loadAllResults(rd, qamKey);
assert(isfield(S, 'Optimal_N_t') && isfield(S, 'Optimal_N_r'), 'result table missing Optimal_N_t/N_r fields');
fprintf('QAM order=16 Optimal_N_t: %s\n', mat2str(S.Optimal_N_t.'));
fprintf('QAM order=16 Optimal_N_r: %s\n', mat2str(S.Optimal_N_r.'));
% Verdrahtung, nicht Physik: BEIDE Kandidaten muessen gerechnet worden sein.
% Ob 2x2 irgendwo gewinnt, ist eine Ergebnisfrage -- frueher war das hier
% eine Assertion, die nur dank der geschenkten 3 dB (SNR je Strom statt
% gesamt) sicher hielt.
assert(size(S.E_per_bit_all, 2) == 2 && any(isfinite(S.E_per_bit_all(:, 2))), ...
    'expected finite results for the 2x2 candidate as well');
fprintf('QAM order=16: 2x2 wins at %d of %d points (informativ)\n', ...
    sum(S.Optimal_N_t == 2), numel(S.Optimal_N_t));

% A non-MIMO order must still work and report N_t=N_r=1 uniformly.
% In SE_data_mux_fixedB gibt es MIMO-Kurven fuer M in {4,16,64,256}; der
% echte SISO-only-Fall ist dort M = 1024 (nur Gasts SE_1024_QAM.mat).
qamSisoKey = gearboxphy.data.resultKey("QAM", 1024, 28e9);
Ssiso = gearboxphy.data.loadAllResults(rd, qamSisoKey);
assert(all(Ssiso.Optimal_N_t(isfinite(Ssiso.E_per_bit)) == 1), 'QAM order=1024 (SISO-curve-only) should always report N_t=1');
assert(all(Ssiso.Optimal_N_r(isfinite(Ssiso.E_per_bit)) == 1), 'QAM order=1024 (SISO-curve-only) should always report N_r=1');
fprintf('QAM order=1024 (no MIMO curve available) correctly stayed SISO\n');

% ZXM (no MIMO variant at all) must also report N_t=N_r=1 uniformly.
zxmKey = gearboxphy.data.resultKey("ZXM", 1, 28e9);
Sz = gearboxphy.data.loadAllResults(rd, zxmKey);
assert(all(Sz.Optimal_N_t == 1) && all(Sz.Optimal_N_r == 1), 'ZXM should always report N_t=N_r=1');
fprintf('ZXM (no MIMO variant) correctly reports N_t=N_r=1\n');

fprintf('MIMO SMOKE TEST PASSED\n');
