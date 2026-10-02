function runSweep(scenario, opts)
%RUNSWEEP Replaces Wrapper.m's parfor orchestration only - no plotting
%   code in this file (see +report/*.m for that). Same parallelization
%   granularity as the original (parfor over rate points, one gear/order/
%   carrier combo at a time), same 'HPCServer' cluster profile kept per
%   this project's toolbox decision.
%
%   Per combo: if a complete consolidated result table already exists for
%   the exact (RVec, distance) being swept, skip it entirely. Otherwise,
%   antenna-config candidates are prepared ONCE per (gear,order,carrier)
%   (ctx doesn't depend on R - see gear.antennaConfigs/prepare), and each
%   parfor iteration over R tries every candidate via
%   optimizeOnePointBestConfig (MIMO_EXTENSION.md decision 4: nested
%   enumeration, not a mixed-integer solver) and keeps the best. Each
%   iteration first checks for a per-point checkpoint file and reuses it
%   if present; if not, it computes the point and immediately writes its
%   OWN checkpoint file before returning - race-free under parfor. Once
%   every point in the combo is done, the whole sweep is written to the
%   consolidated table in one save and the checkpoint files are deleted.
%
%   This means an interrupted run (walltime kill, OOM, preemption) loses
%   at most the points that hadn't been checkpointed yet, not the whole
%   combo - the next run reuses every checkpoint already on disk instead
%   of recomputing from scratch.
arguments
    scenario (1,1) struct
    opts.resultsDir (1,1) string = "results"
    opts.useParallel (1,1) logical = true
    opts.poolProfile (1,1) string = "HPCServer"
end

if ~exist(opts.resultsDir, 'dir')
    mkdir(opts.resultsDir)
end

% Resolve to an ABSOLUTE path before anything is handed to a worker. A
% relative path is resolved against the WORKER's working directory inside
% the parfor, which on a cluster is not the client's - every worker would
% then write its checkpoints somewhere the client never looks, so the
% sweep silently never resumes. See +data/absoluteDir.m.
opts.resultsDir = gearboxphy.data.absoluteDir(opts.resultsDir);

gears = gearboxphy.gears.gearRegistry();

if opts.useParallel
    pool = gcp('nocreate');
    if isempty(pool)
        % NOTE the pool is capped by the number of RATE POINTS, because
        % that is the only axis the parfor below runs over: a 100-point
        % RVec can never use more than 100 workers, however many cores
        % are requested.
        parpool(opts.poolProfile, min(numel(scenario.RVec), scenario.maxCores));
    end
    % Put the framework root on every WORKER's path explicitly.
    % parfor workers do NOT inherit the client's current directory, so
    % code that the client resolves simply by being cd'd into the
    % framework folder is invisible to them - every gearboxphy.* call
    % inside the parfor body then fails to resolve on the worker. Relying
    % on the client's cwd is exactly what makes a sweep work when launched
    % one way and fail when launched another.
    frameworkRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    parfevalOnAll(@addpath, 0, frameworkRoot);

    gearboxphy.sweep.checkWorkersSeeDir(opts.resultsDir);
end

optParams = struct('tolerance', scenario.tolerance, ...
    'maxiters', scenario.maxiters, 'numtriesPerOpt', scenario.numtriesPerOpt);

for fi = 1:numel(scenario.fcVec)
    f_c = scenario.fcVec(fi);
    carrierScenario = gearboxphy.sweep.resolveScenarioForCarrier(scenario, f_c);
    fprintf('Running optimization f_c=%g GHz\n', f_c/1e9);

    for gi = 1:numel(gears)
        gear = gears{gi};
        for oi = 1:numel(gear.orders)
            order = gear.orders(oi);
            fprintf('  %s order=%g\n', gear.name, order);

            % Antenna-config candidates are resolved BEFORE the skip-check
            % (moved up from after it) so hasAllResults can tell a result
            % computed under a different qamMimoConfigs apart from one
            % that's genuinely still current - see hasAllResults.m.
            key = gearboxphy.data.resultKey(gear.name, order, f_c);
            antennaConfigs = gear.antennaConfigs(order, carrierScenario);
            if gearboxphy.data.hasAllResults(opts.resultsDir, key, scenario.RVec, scenario.distance, antennaConfigs)
                continue   % already fully computed with these exact antenna candidates - skip this whole combo
            end

            % ctx is prepared once per combo (not per R) - none of it
            % depends on R.
            ctxList = cell(1, numel(antennaConfigs));
            for ci = 1:numel(antennaConfigs)
                ctxList{ci} = gear.prepare(order, carrierScenario, antennaConfigs{ci});
            end
            x0 = gear.initialGuess(order, carrierScenario);
            bounds = gear.optimizerBounds(order, carrierScenario);

            n = numel(scenario.RVec);
            nCfg = numel(antennaConfigs);
            RVec = scenario.RVec;
            resultsDirLocal = opts.resultsDir;
            E_per_bit = NaN(n,1);
            Optimal_B = NaN(n,1);
            Optimal_gamma = NaN(n,1);
            Optimal_N_t = NaN(n,1);
            Optimal_N_r = NaN(n,1);
            PowerBudget = cell(n,1);
            % Every candidate's OWN result per rate point, not just the
            % winner's (MIMO_EXTENSION.md follow-up: keep each antenna
            % config's curve, not only whichever won) - column i is
            % antennaConfigs{i}, same indexing as antennaConfigsUsed.
            E_per_bit_all = NaN(n, nCfg);
            Optimal_B_all = NaN(n, nCfg);
            Optimal_gamma_all = NaN(n, nCfg);
            PowerBudget_all = cell(n, nCfg);

            if opts.useParallel
                parfor r = 1:n
                    if gearboxphy.data.hasPointCheckpoint(resultsDirLocal, key, r) %#ok<PFBNS>
                        [E_per_bit(r), Optimal_B(r), Optimal_gamma(r), PowerBudget{r}, Optimal_N_t(r), Optimal_N_r(r), ...
                            E_per_bit_all(r,:), Optimal_B_all(r,:), Optimal_gamma_all(r,:), PowerBudget_all(r,:)] = ...
                            gearboxphy.data.loadPointCheckpoint(resultsDirLocal, key, r);
                    else
                        [e, b, g, pb, nt, nr, e_all, b_all, g_all, pb_all] = gearboxphy.sweep.optimizeOnePointBestConfig( ...
                            gear, ctxList, antennaConfigs, RVec(r), x0, bounds, optParams); %#ok<PFBNS>
                        gearboxphy.data.savePointCheckpoint(resultsDirLocal, key, r, e, b, g, pb, nt, nr, e_all, b_all, g_all, pb_all);
                        E_per_bit(r) = e; Optimal_B(r) = b; Optimal_gamma(r) = g; PowerBudget{r} = pb;
                        Optimal_N_t(r) = nt; Optimal_N_r(r) = nr;
                        E_per_bit_all(r,:) = e_all; Optimal_B_all(r,:) = b_all; Optimal_gamma_all(r,:) = g_all;
                        PowerBudget_all(r,:) = pb_all;
                    end
                end
            else
                for r = 1:n
                    if gearboxphy.data.hasPointCheckpoint(resultsDirLocal, key, r)
                        [E_per_bit(r), Optimal_B(r), Optimal_gamma(r), PowerBudget{r}, Optimal_N_t(r), Optimal_N_r(r), ...
                            E_per_bit_all(r,:), Optimal_B_all(r,:), Optimal_gamma_all(r,:), PowerBudget_all(r,:)] = ...
                            gearboxphy.data.loadPointCheckpoint(resultsDirLocal, key, r);
                    else
                        [e, b, g, pb, nt, nr, e_all, b_all, g_all, pb_all] = gearboxphy.sweep.optimizeOnePointBestConfig( ...
                            gear, ctxList, antennaConfigs, RVec(r), x0, bounds, optParams);
                        gearboxphy.data.savePointCheckpoint(resultsDirLocal, key, r, e, b, g, pb, nt, nr, e_all, b_all, g_all, pb_all);
                        E_per_bit(r) = e; Optimal_B(r) = b; Optimal_gamma(r) = g; PowerBudget{r} = pb;
                        Optimal_N_t(r) = nt; Optimal_N_r(r) = nr;
                        E_per_bit_all(r,:) = e_all; Optimal_B_all(r,:) = b_all; Optimal_gamma_all(r,:) = g_all;
                        PowerBudget_all(r,:) = pb_all;
                    end
                end
            end

            gearboxphy.data.saveAllResults(opts.resultsDir, key, scenario.RVec, ...
                scenario.distance, antennaConfigs, E_per_bit, Optimal_B, Optimal_gamma, PowerBudget, Optimal_N_t, Optimal_N_r, ...
                E_per_bit_all, Optimal_B_all, Optimal_gamma_all, PowerBudget_all);
            gearboxphy.data.clearCheckpoints(opts.resultsDir, key);
        end
    end
end
end
