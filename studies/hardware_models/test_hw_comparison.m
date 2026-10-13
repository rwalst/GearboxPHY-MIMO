%TEST_HW_COMPARISON  Mini end-to-end run of the hardware-model comparison in
%   a temporary folder: one carrier, four rates, no pool. Checks the whole
%   run/analyze chain BEFORE the HPC sweep (run_hw_comparison); the numbers
%   it produces are not results.
%
%   Call:
%       addpath('<repo>'); setupGearboxPath;
%       test_hw_comparison
%   Duration: a few minutes. Ends with an error if a check fails.
HW_CFG = hw_comparison_config();
HW_CFG.root  = tempname;
HW_CFG.fcVec = 2.4e9;
HW_CFG.RVec  = logspace(4, 10, 4);
VARIANTS     = ["old" "new" "dac_only"];
USE_PARALLEL = false;
cleanup = onCleanup(@() rmdir(HW_CFG.root, 's'));

run_hw_comparison

% a second call must resume without recomputing and without a stamp clash
run_hw_comparison

% a foreign case in the same directory must be refused
c = hw_comparison_case(HW_CFG, "old", HW_CFG.distances(1));
c.stamp.adcPowerModel = "quantile5";
try
    hw_comparison_prepare_dir(c);
    error('hw:test', 'A foreign stamp was accepted.');
catch err
    assert(strcmp(err.identifier, 'hw:stampMismatch'), 'Unexpected error: %s', err.message);
end

out = analyze_hw_comparison(cfg=HW_CFG, rateTable=HW_CFG.RVec);
T = out.table;
for f = ["hw_gear_d50.png" "hw_budget_d50.png" "hw_ebit_d50.png" "summary.csv"]
    assert(isfile(fullfile(out.figDir, f)), 'Missing output %s.', f);
end
ok = isfinite(T.Ebit_J);                 % a rate no gear can serve stays NaN
assert(any(ok), 'No feasible point in the test.');
assert(all(abs(T.ratioToRef(ok & string(T.variant) == "old") - 1) < 1e-12), 'Reference ratio is not 1.');
shares = T{ok, startsWith(T.Properties.VariableNames, 'share_')};
assert(all(abs(sum(shares, 2) - 100) < 1e-9), 'Budget shares do not sum to 100 %%.');
assert(numel(unique(string(T.variant))) == 3, 'Not all three variants were analysed.');
copyfile(out.figDir, fullfile(tempdir, 'hw_comparison_test_figures'));
fprintf('\ntest_hw_comparison: all checks passed. Figures copied to %s\n', ...
    fullfile(tempdir, 'hw_comparison_test_figures'));
