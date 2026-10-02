function [E_per_bit, Optimal_B, Optimal_gamma, budget, Optimal_N_t, Optimal_N_r, ...
    E_per_bit_all, Optimal_B_all, Optimal_gamma_all, budget_all] = ...
    optimizeOnePointBestConfig(gear, ctxList, antennaConfigs, R, x0, bounds, optParams)
%OPTIMIZEONEPOINTBESTCONFIG Nested-enumeration joint optimization over
%   antenna configuration (MIMO_EXTENSION.md decision 4): tries every
%   candidate antennaConfig's already-prepared ctx (see runSweep.m, which
%   builds ctxList once per (gear,order,carrier) - NOT per R, since ctx
%   doesn't depend on R), runs the existing continuous optimizeOnePoint
%   for each, and keeps whichever antenna config gives the lowest
%   energy-per-bit for this specific R. For a SISO-only gear (a single
%   candidate in ctxList), this reduces to exactly optimizeOnePoint's
%   behavior - no special-casing by gear name anywhere in this chain.
%
%   x0/bounds are shared across all candidates (they don't depend on
%   antenna config - see qamGear.m's initialGuess/optimizerBounds).
%
%   The _all outputs (1 x n, n = numel(ctxList)) carry EVERY candidate's
%   own result at this R, not just the winner's - optimizeOnePoint()
%   already computes each one to find bestE, so returning them too costs
%   nothing extra here; it's runSweep.m/saveAllResults.m that decide
%   whether to keep them. Column i of every _all output corresponds to
%   antennaConfigs{i}, the same indexing already used for
%   antennaConfigsUsed (see hasAllResults.m/saveAllResults.m), so no
%   separate column-label needs saving alongside them.
n = numel(ctxList);
bestE = inf;
bestIdx = NaN;
bestB = NaN; bestG = NaN; bestBudget = NaN;

E_per_bit_all = NaN(1, n);
Optimal_B_all = NaN(1, n);
Optimal_gamma_all = NaN(1, n);
budget_all = cell(1, n);

for i = 1:n
    [e, b, g, pb] = gearboxphy.sweep.optimizeOnePoint(gear, ctxList{i}, R, x0, bounds, optParams);
    E_per_bit_all(i) = e; Optimal_B_all(i) = b; Optimal_gamma_all(i) = g; budget_all{i} = pb;
    if ~isnan(e) && e < bestE
        bestE = e; bestB = b; bestG = g; bestBudget = pb; bestIdx = i;
    end
end

if isnan(bestIdx)
    % Every candidate antenna config was infeasible at this point.
    E_per_bit = NaN; Optimal_B = NaN; Optimal_gamma = NaN; budget = NaN;
    Optimal_N_t = NaN; Optimal_N_r = NaN;
else
    E_per_bit = bestE; Optimal_B = bestB; Optimal_gamma = bestG; budget = bestBudget;
    Optimal_N_t = antennaConfigs{bestIdx}.N_t;
    Optimal_N_r = antennaConfigs{bestIdx}.N_r;
end
end
