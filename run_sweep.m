% RUN_SWEEP Top-level entry point for the GearboxPHY energy-per-bit sweep.
%   Builds a scenario, runs the sweep (parfor over rate points, per
%   gear/order/carrier - same granularity as the original Wrapper.m),
%   then produces the same report figures. See ../ARCHITECTURE_PLAN.md
%   for the design this implements.

scenario = gearboxphy.sweep.makeScenarioConfig( ...
    'distance', 50, ...
    'RVec', logspace(3,11,400), ...
    'fcVec', [2.4 8 28 60]*1e9, ...
    'qamMimoConfigs', { ...
        struct('N_t',1,'N_r',1), ...   % SISO-Baseline, damit MIMO nur gewinnt, wenn es sich energetisch lohnt
        struct('N_t',2,'N_r',2), ...
        struct('N_t',4,'N_r',4), ...
        struct('N_t',8,'N_r',8) ...
    });

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
