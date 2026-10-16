% RUN_SWEEP Top-level entry point for the GearboxPHY energy-per-bit sweep.
%   Builds a scenario, runs the sweep (parfor over rate points, per
%   gear/order/carrier - same granularity as the original Wrapper.m),
%   then produces the same report figures. See ../ARCHITECTURE_PLAN.md
%   for the design this implements.
%
%   SISO ONLY (decision 2026-10-16). This is the base sweep: four carriers,
%   every gear, 400 rate points, one antenna. The MIMO axis belongs to the
%   studies built for it - studies/mimo_comparison (3a over the rate axis,
%   3b over distance) and studies/analog_bf - which read curve folders
%   tagged with their ADC rule.
%
%   UNTIL TODAY THIS SCRIPT ASKED FOR 1x1, 2x2, 4x4 AND 8x8 against the base
%   folder data/SE_data, and that was wrong in a way worth writing down.
%   Nine MIMO curves live there (M = 4/16/64 x 2x2/4x4/8x8) from an early
%   export, before exportToGearboxSEData wrote snrReference: they carry
%   source, sourceB and sourceTier but not that field. Curves from
%   QuantizedMimoMI are normalised PER STREAM (Es = 1 per stream) while the
%   gearbox budgets TOTAL transmit power, so without the 10*log10(N_t) shift
%   multiplexing is handed +3.0 dB at 2x2, +6.0 dB at 4x4 and +9.0 dB at 8x8.
%
%   results/main WAS COMPUTED THAT WAY. qam_M4, qam_M16 and qam_M64 carry
%   all four configurations in antennaConfigsUsed, so their MIMO columns are
%   wrong - independently of the hardware model set. Only qam_M256 is clean,
%   and only because those curves are missing from the base folder entirely
%   and filterAvailableAntennaConfigs dropped them.
%
%   loadSECurve has rejected such curves since f3406b7, which is AFTER those
%   results were stored - so this script has been aborting with
%   gearboxphy:snrReference ever since, and the abort is the check doing its
%   job: it refuses to reproduce a known-wrong result. Observed 2026-10-16 in
%   run_newhw_w4.
%
%   Nothing but this script reads results/main (grep: only line 18 and the
%   figure directory below), so dropping the MIMO columns costs no analysis.
scenario = gearboxphy.sweep.makeScenarioConfig( ...
    'distance', 50, ...
    'RVec', logspace(3,11,400), ...
    'fcVec', [2.4 8 28 60]*1e9, ...
    'qamMimoConfigs', {struct('N_t',1,'N_r',1)});

gearboxphy.sweep.runSweep(scenario, 'resultsDir', 'main');

% All four +report/*.m functions return a figure handle but never save it
% themselves (fig = plotXReport(...) is the contract, no exportgraphics/
% saveas inside any of them - confirmed by grep). On an interactive
% desktop the windows stay open to save by hand; in a non-interactive
% cluster batch job (matlab -batch, no display - exactly how this script
% is meant to run on a compute cluster) the figures are built and then
% simply lost when the session ends, with no error to flag it. Capturing
% and exporting each handle here, in the one place already responsible
% for orchestration/output, closes that gap without touching the report
% functions themselves (they stay pure "build a figure", reusable as-is
% e.g. from mimo_smoke_test.m without forcing a save).
figDir = fullfile(gearboxphy.paths.resultsDir('main'), 'figures');
if ~exist(figDir, 'dir'), mkdir(figDir); end

for fi_ = 1:numel(scenario.fcVec)
    fig = gearboxphy.report.plotEnergyReport('main', scenario, scenario.fcVec(fi_));
    exportgraphics(fig, fullfile(figDir, sprintf('energy_fc%gGHz.png', scenario.fcVec(fi_)/1e9)), 'Resolution', 150);
end

fig = gearboxphy.report.plotOptimalGearReport('main', scenario);
exportgraphics(fig, fullfile(figDir, 'optimal_gear.png'), 'Resolution', 150);

fig = gearboxphy.report.plotSavingsReport('main', scenario);
exportgraphics(fig, fullfile(figDir, 'savings.png'), 'Resolution', 150);

fig = gearboxphy.report.plotPowerBudgetReport('main', scenario, "QAM", 1024, 28e9);
exportgraphics(fig, fullfile(figDir, 'power_budget_QAM_1024_28GHz.png'), 'Resolution', 150);

fprintf('\nReport-Grafiken gespeichert in %s\n', figDir);
