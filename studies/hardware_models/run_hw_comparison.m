%RUN_HW_COMPARISON  SISO gearbox sweep with the old and with the new
%   component power models (docs/HARDWARE_MODEL_SWITCH.md,
%   studies/hardware_models/README.md).
%
%   Call:
%       addpath('<repo>'); setupGearboxPath;
%       run_hw_comparison
%
%   RESOURCES: 100 workers, 64 GB, 4 h. One node.
%   (the pool is capped by the 100 rate points at 100 workers - more
%   cores do not help, see runSweep.m). The time is an estimate: one case
%   is the size of one SISO case of the LNA comparison.
%
%   ZIH cluster instead of Windows: sbatch hpc/zih/submit_study.sbatch run_hw_comparison
%   with --cpus-per-task=101 (one for the client). Walk-through and
%   step 0: docs/HPC_RUNBOOK_ZIH.md.
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
%   OUTPUT: results/hardware_models_newhw/siso_<variant>_d<d>/  - then run
%   analyze_hw_comparison.
%
%   Set VARIANTS / USE_PARALLEL / HW_CFG in the workspace before the call
%   to override the defaults below (HW_CFG: a modified hw_comparison_config
%   struct, e.g. fewer rates for a test).
%
%   MIND THE SHARED WORKSPACE. This driver is a SCRIPT, so VARIANTS is
%   whatever the base workspace holds - including a leftover from another
%   study script of the same session. Three of them assign that same name
%   to MUX/BF variants ("mux_fixedB" and relatives). The check below names
%   that cause; "clear VARIANTS" is the cure.

%% ===================== CONFIG =====================================
if ~exist('VARIANTS', 'var'),     VARIANTS = ["old" "new"]; end   % add "lna_only" "adc_only" "dac_only" "bw_only" to see which decision moves the result
if ~exist('USE_PARALLEL', 'var'), USE_PARALLEL = true; end
if ~exist('HW_CFG', 'var'),       HW_CFG = hw_comparison_config(); end
%% ===================================================================

cfg = HW_CFG;

% WHERE VARIANTS CAME FROM MATTERS. This driver is a script, so the
% override above reads the base workspace - and three other study scripts
% assign the SAME variable to their own names: run_mimo_comparison_sweep.m
% (line 33), run_mimo_comparison_distance.m (line 42) and
% analyze_mimo_comparison.m (line 67), all with "mux_fixedB" and relatives.
% Whoever ran one of those in the same MATLAB session got
% "Unknown variant mux_fixedB" out of hw_comparison_case - a correct abort,
% but with no hint that the cause is a stale workspace rather than a typo.
% Observed 2026-10-15. Renaming the override would break the documented
% interface and test_hw_comparison.m, so the fix is the message.
known = [cfg.variants.name];
bad   = setdiff(string(VARIANTS), known);
assert(isempty(bad), 'hw:staleVariants', ...
    ['VARIANTS holds %s - not variants of this study (known: %s).\n' ...
     'Most likely a leftover from another study script of this session.\n' ...
     'Either clear it and take the two default cases:\n' ...
     '    clear VARIANTS; run_hw_comparison\n' ...
     'or name the cases you want:\n' ...
     '    VARIANTS = ["lna_only" "adc_only" "dac_only"]; run_hw_comparison'], ...
    strjoin(bad, ', '), strjoin(known, ', '));

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
