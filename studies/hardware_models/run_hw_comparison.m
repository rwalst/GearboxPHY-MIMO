%RUN_HW_COMPARISON  SISO gearbox sweep with the old and with the new
%   component power models (docs/HARDWARE_MODEL_SWITCH.md,
%   studies/hardware_models/README.md).
%
%   Call:
%       addpath('<repo>'); setupGearboxPath;
%       run_hw_comparison
%
%   RESOURCES: nodes=1  ntasks=1  cpus-per-task=100  mem=64G  time=04:00:00
%   (the pool is capped by the 100 rate points at 100 workers - more
%   cores do not help, see runSweep.m). The time is an estimate: one case
%   is the size of one SISO case of the LNA comparison.
%
%   WHAT IS COMPUTED (hw_comparison_config.m):
%     one case per variant in VARIANTS, SISO, d = 50 m;
%     each case = all gears x carriers 2.4 / 8 / 28 GHz x 100 rates.
%
%   RESUMABLE: runSweep skips finished combos and reuses point
%   checkpoints - after an interruption just start again. Every results
%   directory is pinned to its case by hw_stamp.mat; a mismatch is an
%   error, never an overwrite (hw_comparison_prepare_dir.m).
%
%   OUTPUT: results/hardware_models/siso_<variant>_d<d>/  - then run
%   analyze_hw_comparison.
%
%   Set VARIANTS / USE_PARALLEL / HW_CFG in the workspace before the call
%   to override the defaults below (HW_CFG: a modified hw_comparison_config
%   struct, e.g. fewer rates for a test).

%% ===================== CONFIG =====================================
if ~exist('VARIANTS', 'var'),     VARIANTS = ["old" "new"]; end   % add "lna_only" "adc_only" "dac_only" to see which model moves the result
if ~exist('USE_PARALLEL', 'var'), USE_PARALLEL = true; end
if ~exist('HW_CFG', 'var'),       HW_CFG = hw_comparison_config(); end
%% ===================================================================

cfg = HW_CFG;

% Build every case first: a bad option or a stamp clash stops the job
% now, not hours in.
cases = {};
for variant = VARIANTS
    for d = cfg.distances
        c = hw_comparison_case(cfg, variant, d);
        hw_comparison_prepare_dir(c);
        cases{end+1} = c; %#ok<SAGROW>
    end
end
fprintf('%d cases, results under %s\n', numel(cases), cfg.root);

tAll = tic;
for k = 1:numel(cases)
    c = cases{k};
    fprintf('\n======== [%d/%d] %s ========\n', k, numel(cases), c.name);
    t0 = tic;
    gearboxphy.sweep.runSweep(c.scenario, 'resultsDir', c.dir, 'useParallel', USE_PARALLEL);
    fprintf('%s done after %.1f min\n', c.name, toc(t0)/60);
end
fprintf('\nAll %d cases done after %.1f h. Next: analyze_hw_comparison\n', ...
    numel(cases), toc(tAll)/3600);
