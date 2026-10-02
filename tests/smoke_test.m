% SMOKE_TEST Tiny end-to-end run exercising runSweep + all 4 report
%   functions, plus targeted checks of the 10 code-review fixes:
%   checkpoint resumability, plotPowerBudgetReport's clear error on an
%   incompatible gear, and isBaselineGear.
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'tests', '+goldenmaster', 'shim')); % obw() stub

scenario = gearboxphy.sweep.makeScenarioConfig( ...
    'distance', 50, ...
    'RVec', logspace(6,9,3), ...
    'fcVec', [2.4 28]*1e9, ...
    'maxiters', 300, 'tolerance', 1e-6, 'numtriesPerOpt', 2, ...
    'dataDir', "SE_data");

% Einmal aufloesen: der Name wird weiter unten sowohl an runSweep/die
% Report-Funktionen gereicht als auch direkt mit fullfile/load benutzt.
% Nur ein absoluter Pfad ist an beiden Stellen derselbe Ordner.
rd = gearboxphy.paths.resultsDir('smoke_results');
if exist(rd, 'dir'); rmdir(rd, 's'); end

gearboxphy.sweep.runSweep(scenario, 'resultsDir', rd, 'useParallel', false);
fprintf('runSweep completed OK\n');

% --- Checkpoint resumability check ---
% Simulate an interrupted sweep: delete one gear/order/carrier's
% consolidated result file (as if it never finished) but manually leave
% behind checkpoints for some of its points, then verify runSweep reuses
% those checkpoints instead of recomputing everything.
key = gearboxphy.data.resultKey("QAM", 4, 2.4e9);
resultFile = fullfile(rd, key + ".mat");
assert(isfile(resultFile), 'expected QAM order=4 result to exist after first run');
S_before = gearboxphy.data.loadAllResults(rd, key);

delete(resultFile);
% Manually recreate checkpoints for points 1 and 2 (of 3) using the
% previous run's values, to prove they get reused rather than recomputed.
gearboxphy.data.savePointCheckpoint(rd, key, 1, S_before.E_per_bit(1), ...
    S_before.Optimal_B(1), S_before.Optimal_gamma(1), S_before.PowerBudget{1});
gearboxphy.data.savePointCheckpoint(rd, key, 2, S_before.E_per_bit(2), ...
    S_before.Optimal_B(2), S_before.Optimal_gamma(2), S_before.PowerBudget{2});
assert(gearboxphy.data.hasPointCheckpoint(rd, key, 1), 'checkpoint 1 should exist');
assert(gearboxphy.data.hasPointCheckpoint(rd, key, 2), 'checkpoint 2 should exist');
assert(~gearboxphy.data.hasPointCheckpoint(rd, key, 3), 'checkpoint 3 should NOT exist yet');

gearboxphy.sweep.runSweep(scenario, 'resultsDir', rd, 'useParallel', false);
assert(isfile(resultFile), 'result should be rebuilt after resuming from checkpoints');
S_after = gearboxphy.data.loadAllResults(rd, key);
assert(isequal(S_after.E_per_bit(1:2), S_before.E_per_bit(1:2)), ...
    'resumed points 1-2 should match the checkpointed values exactly (reused, not recomputed)');
assert(~exist(gearboxphy.data.checkpointDir(rd, key), 'dir'), ...
    'checkpoint folder should be cleaned up after a successful consolidated save');
fprintf('checkpoint resumability OK\n');

% --- isBaselineGear check ---
gears = gearboxphy.gears.gearRegistry();
baselineCount = 0;
for gi = 1:numel(gears)
    if gearboxphy.gears.isBaselineGear(gears{gi})
        baselineCount = baselineCount + 1;
        assert(gears{gi}.name == "NA-QAM", 'baseline gear should be NA-QAM');
    end
end
assert(baselineCount == 1, 'expected exactly one baseline gear');
fprintf('isBaselineGear OK\n');

% --- Report functions ---
for fi_ = 1:numel(scenario.fcVec)
    f = gearboxphy.report.plotEnergyReport(rd, scenario, scenario.fcVec(fi_));
    close(f);
end
fprintf('plotEnergyReport OK\n');

f = gearboxphy.report.plotOptimalGearReport(rd, scenario);
close(f);
fprintf('plotOptimalGearReport OK\n');

f = gearboxphy.report.plotSavingsReport(rd, scenario);
close(f);
fprintf('plotSavingsReport OK\n');

f = gearboxphy.report.plotPowerBudgetReport(rd, scenario, "QAM", 4, 2.4e9);
close(f);
fprintf('plotPowerBudgetReport (QAM, compatible schema) OK\n');

% plotPowerBudgetReport must now refuse Pulse-Energy with a CLEAR error
% instead of crashing on a missing-field reference (finding #1).
try
    gearboxphy.report.plotPowerBudgetReport(rd, scenario, "Pulse-Energy", 1, 2.4e9);
    error('smoke_test:expectedError', 'plotPowerBudgetReport should have errored for Pulse-Energy');
catch ME
    assert(strcmp(ME.identifier, 'gearboxphy:report:unsupportedBudgetSchema'), ...
        'expected gearboxphy:report:unsupportedBudgetSchema, got %s: %s', ME.identifier, ME.message);
    fprintf('plotPowerBudgetReport correctly rejects Pulse-Energy: %s\n', ME.message);
end

fprintf('SMOKE TEST PASSED\n');
