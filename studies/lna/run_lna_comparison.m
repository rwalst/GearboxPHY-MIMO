%RUN_LNA_COMPARISON  Gearbox sweep for the LNA-model comparison
%   (LNA_POWER_MODEL.md, HPC_RUNBOOK_LNA_VERGLEICH.md).
%
%   Call: in gearboxphy_framework/ simply
%       run_lna_comparison
%   Run validate_lna_comparison FIRST (minutes, no pool) - this file has
%   not been executed yet.
%
%   RESOURCES: nodes=1  ntasks=1  cpus-per-task=100  mem=64G  time=12:00:00
%   (the pool is capped by the 100 rate points at 100 workers - more
%   cores do not help, see runSweep.m)
%
%   WHAT IS COMPUTED (lna_comparison_config.m):
%     siso:        2 bandwidth settings x 3 LNA models x d = 50 m        =  6 cases
%     beamforming: 2 bandwidth settings x 3 LNA models x d = 50, 5000 m  = 12 cases
%   each case = all gears x carriers 2.4 / 8 / 28 GHz x 100 rates.
%   SISO first: it is cheap and already answers the main question.
%   Beamforming costs about 7x as much (seven N x N candidates per point).
%
%   RESUMABLE: runSweep skips finished combos and reuses point
%   checkpoints - after an interruption just start again. Every results
%   directory is pinned to its case by lna_stamp.mat; a mismatch is an
%   error, never an overwrite (lna_comparison_prepare_dir.m).
%
%   OUTPUT: results_lna/<study>_<bw>_<model>_d<d>/  - then run
%   analyze_lna_comparison.

%% ===================== CONFIG =====================================
STUDIES      = ["siso" "beamforming"];   % drop "beamforming" for a quick first pass
USE_PARALLEL = true;
%% ===================================================================

here = fileparts(mfilename('fullpath'));
cd(here);
cfg = lna_comparison_config();

% Build every case first: a bad option or a stamp clash stops the job
% now, not hours in.
cases = {};
for study = STUDIES
    for b = 1:numel(cfg.bw)
        for model = cfg.models
            for d = cfg.distances.(char(study))
                c = lna_comparison_case(cfg, study, cfg.bw(b), model, d);
                lna_comparison_prepare_dir(c);
                cases{end+1} = c; %#ok<SAGROW>
            end
        end
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
fprintf('\nAll %d cases done after %.1f h. Next: analyze_lna_comparison\n', ...
    numel(cases), toc(tAll)/3600);
