%VALIDATE_LNA_COMPARISON  Step 0 of the LNA-model comparison: checks the LNA
%   switch, the B_max override and the whole run/analyze chain BEFORE the
%   HPC sweep (run_lna_comparison). Nothing here has been executed yet.
%
%   Call: in gearboxphy_framework/ simply
%       validate_lna_comparison
%   Duration: a few minutes, no pool. Ends with an error if a check fails.
%
%   L1  Unit tests tests/+unit/LnaModelTest.m (switch, envelope values,
%       floor, B_max override, gears pick both up).
%   L2  Regression: with the default LNA model - and with it set
%       explicitly - the objective of QAM, NA-QAM, ZXM and Pulse-Energy at
%       the stored SISO optimum reproduces the stored E_bit (deterministic,
%       no optimizer run). Missing reference files are skipped.
%   L3  Physics per point, all three carriers, both bandwidth settings,
%       all three models, QAM-16 and Pulse-Energy:
%         a) optimal B <= B_max
%         b) the LNA term in the budget equals lnaPowerFor(B_opt)
%         c) E_bit ordered envelope >= floor >= dissertation (the LNA
%            power is ordered pointwise for every B <= B_max used here)
%   L4  Mini end-to-end run through run/analyze helpers in a temp folder
%       (2.4 GHz, 4 rates, narrow B_max, SISO + beamforming N = 1, 2):
%       stamps are written and a foreign case is refused, the analysis
%       runs, the dissertation model has ratio 1, the others >= 1.
here = fileparts(mfilename('fullpath'));
cd(here);
addpath(here);
fail = 0;

%% L1: unit tests ------------------------------------------------------
fprintf('=== L1 unit tests (LnaModelTest) ===\n');
addpath(fullfile(gearboxphy.paths.root(), 'tests'));
res = runtests('unit.LnaModelTest');
nBad = sum([res.Failed]) + sum([res.Incomplete]);
fprintf('  %d tests, %d failed/incomplete\n', numel(res), nBad);
fail = fail + (nBad > 0);

%% L2: bit-exact regression of the default ------------------------------
fprintf('\n=== L2 default LNA model reproduces stored SISO results bit for bit ===\n');
CASES = { ...
  'results/qam_M256_fc28GHz.mat',          gearboxphy.gears.qamGear(),            256,  28e9; ...
  'results/naqam_M1024_fc2.4GHz.mat',      gearboxphy.gears.naQamGear(),          1024, 2.4e9; ...
  'results/zxm_M2_fc8GHz.mat',             gearboxphy.gears.zxmGear(),            2,    8e9; ...
  'results/pulseenergy_M1_fc2.4GHz.mat',   gearboxphy.gears.pulseGear("Energy"),  1,    2.4e9};
for k = 1:size(CASES, 1)
    if ~isfile(CASES{k,1})
        fprintf('  [skip] %s missing on this machine\n', CASES{k,1});
        continue
    end
    S = load(CASES{k,1});
    gear = CASES{k,2}; order = CASES{k,3}; fc = CASES{k,4};
    siso = isfield(S, 'antennaConfigsUsed') && S.antennaConfigsUsed{1}.N_t == 1 ...
        && S.antennaConfigsUsed{1}.N_r == 1 && isfield(S, 'E_per_bit_all') && ~isempty(S.E_per_bit_all) ...
        && isfield(S, 'Optimal_B_all') && isfield(S, 'Optimal_gamma_all');
    if ~siso
        fprintf('  [skip] %s: no per-config SISO column in this file\n', CASES{k,1});
        continue
    end
    % Deterministic: evaluate the objective at the STORED optimum instead
    % of re-running the random multistart optimizer. The stored E_bit is
    % the objective value at exactly that point, so the default model must
    % reproduce it up to rounding in log10(10^x) - and default and
    % explicit model must agree bit for bit.
    idx = round(linspace(5, numel(S.RVec)-5, 6));
    E = NaN(2, numel(idx));
    for explicit = [false true]
        if explicit
            scen = gearboxphy.sweep.makeScenarioConfig('distance', S.distance, 'RVec', S.RVec, ...
                'fcVec', fc, 'lnaPowerModel', "fom_bandwidth");
        else
            scen = gearboxphy.sweep.makeScenarioConfig('distance', S.distance, 'RVec', S.RVec, 'fcVec', fc);
        end
        cs = gearboxphy.sweep.resolveScenarioForCarrier(scen, fc);
        ctx = gear.prepare(order, cs, struct('N_t', 1, 'N_r', 1));
        scalarX = isscalar(gear.initialGuess(order, cs));   % NA-QAM optimizes gamma only
        for n = 1:numel(idx)
            i = idx(n);
            if ~isfinite(S.E_per_bit_all(i, 1)), continue, end
            if scalarX
                x = S.Optimal_gamma_all(i, 1);
            else
                x1 = log10(S.Optimal_B_all(i, 1));
                % an optimum at B_max can come back 1 ulp above it after
                % the log10/10^ round trip and would then read as infeasible
                while 10^x1 > ctx.B_max, x1 = x1 - 4*eps(x1); end
                x = [x1 S.Optimal_gamma_all(i, 1)];
            end
            obj = gear.makeObjective(ctx, S.RVec(i));
            E(1 + explicit, n) = obj(x);
        end
    end
    ref = S.E_per_bit_all(idx, 1).';
    fin = isfinite(ref);
    worst = max(abs(E(1, fin) - ref(fin)) ./ ref(fin));
    same = isequal(E(1, fin), E(2, fin));
    ok = any(fin) && worst < 1e-12 && same;
    fail = fail + ~ok;
    fprintf('  [%s] %-14s %4g GHz  max rel. dev. to stored %.2e, default == explicit: %d (%d points)\n', ...
        tern(ok,' OK ','FAIL'), gear.name, fc/1e9, worst, same, sum(fin));
end

%% L3: physics per point ------------------------------------------------
fprintf('\n=== L3 B <= B_max, budget LNA = lnaPowerFor(B_opt), E ordered by model ===\n');
cfg = lna_comparison_config();
GEARS = {gearboxphy.gears.qamGear(), 16; gearboxphy.gears.pulseGear("Energy"), 1};
RTEST = [1e4 1e6 1e7];
for b = 1:numel(cfg.bw)
    for fc = cfg.fcVec
        for g = 1:size(GEARS, 1)
            gear = GEARS{g,1}; order = GEARS{g,2};
            E = NaN(numel(cfg.models), numel(RTEST));
            okA = true; okB = true;
            for m = 1:numel(cfg.models)
                scen = gearboxphy.sweep.makeScenarioConfig('distance', 50, 'fcVec', fc, ...
                    'lnaPowerModel', cfg.models(m), 'lnaBetaMin', cfg.lnaBetaMin, ...
                    'B_maxByCarrier', cfg.bw(b).B_maxByCarrier);
                cs = gearboxphy.sweep.resolveScenarioForCarrier(scen, fc);
                op = struct('tolerance', scen.tolerance, 'maxiters', scen.maxiters, 'numtriesPerOpt', scen.numtriesPerOpt);
                ctx = gear.prepare(order, cs, struct('N_t', 1, 'N_r', 1));
                x0 = gear.initialGuess(order, cs); bnds = gear.optimizerBounds(order, cs);
                for i = 1:numel(RTEST)
                    [e, Bopt, gam, pb] = gearboxphy.sweep.optimizeOnePoint(gear, ctx, RTEST(i), x0, bnds, op);
                    E(m, i) = e;
                    if isnan(e), continue, end
                    okA = okA && Bopt <= ctx.B_max * (1 + 1e-9);
                    Plna = pb.LNA * RTEST(i) / (gam + cs.epsilon_rec*(1-gam));
                    okB = okB && abs(Plna - gearboxphy.physics.lnaPowerFor(ctx.hw.lna, Bopt)) ...
                        <= 1e-9 * Plna;
                end
            end
            % envelope >= floor >= dissertation, 1e-3 slack for the multistart optimizer
            fin = all(isfinite(E), 1);
            okC = all(E(3, fin) >= E(2, fin) * (1 - 1e-3)) && all(E(2, fin) >= E(1, fin) * (1 - 1e-3));
            ok = okA && okB && okC && any(fin);
            fail = fail + ~ok;
            fprintf('  [%s] %-6s %4g GHz  %-12s a=%d b=%d c=%d  (%d/%d rates feasible)\n', ...
                tern(ok,' OK ','FAIL'), cfg.bw(b).name, fc/1e9, gear.name, okA, okB, okC, sum(fin), numel(fin));
        end
    end
end

%% L4: mini end-to-end ----------------------------------------------------
fprintf('\n=== L4 mini run + stamps + analysis (temp folder) ===\n');
mini = cfg;
mini.root = tempname;
mkdir(mini.root);                            % exists before the cleanup is armed
mini.fcVec = 2.4e9;
mini.RVec = logspace(4, 9, 4);
mini.bw = cfg.bw(2);                        % narrow
mini.distances.siso = 50;
mini.distances.beamforming = 50;
mini.bfN = [1 2];
cleanL4 = onCleanup(@() rmdir(mini.root, 's'));
nCases = 0;
for study = mini.studies
    for model = mini.models
        c = lna_comparison_case(mini, study, mini.bw, model, 50);
        lna_comparison_prepare_dir(c);
        lna_comparison_prepare_dir(c);        % second call must accept its own stamp
        gearboxphy.sweep.runSweep(c.scenario, 'resultsDir', c.dir, 'useParallel', false);
        nCases = nCases + 1;
    end
end
% a foreign case pointed at an existing directory must be refused
c = lna_comparison_case(mini, "siso", mini.bw, "envelope", 50);
c.stamp.lnaPowerModel = "fom_floor";
try
    lna_comparison_prepare_dir(c);
    refused = false;
catch err
    refused = strcmp(err.identifier, 'lna:stampMismatch');
end
fail = fail + ~refused;
fprintf('  [%s] %d cases run, foreign stamp refused\n', tern(refused,' OK ','FAIL'), nCases);

out = analyze_lna_comparison('cfg', mini, 'figDir', string(fullfile(mini.root, 'figures')), ...
    'rateTable', mini.RVec);
T = out.table;
isRef = strcmp(T.lnaModel, 'fom_bandwidth');
fin = isfinite(T.ratioToDiss);
okRef = all(abs(T.ratioToDiss(isRef & fin) - 1) < 1e-12);
okOth = all(T.ratioToDiss(~isRef & fin) >= 1 - 1e-3);
nFig = numel(dir(fullfile(mini.root, 'figures', '*.png')));
ok = okRef && okOth && nFig == 9 && any(fin);
fail = fail + ~ok;
fprintf('  [%s] analysis: %d rows, ratio(dissertation) = 1: %d, others >= 1: %d, %d figures (expected 9)\n', ...
    tern(ok,' OK ','FAIL'), height(T), okRef, okOth, nFig);
clear cleanL4

%% ------------------------------------------------------------------------
if fail > 0
    error('validate_lna_comparison:failed', '%d check(s) FAILED - do not start run_lna_comparison.', fail);
end
fprintf('\nAll checks passed. Next: run_lna_comparison on the HPC.\n');

function s = tern(c, a, b)
if c, s = a; else, s = b; end
end
