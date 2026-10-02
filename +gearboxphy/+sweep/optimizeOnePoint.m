function [E_per_bit, Optimal_B, Optimal_gamma, budget] = optimizeOnePoint(gear, ctx, R, x0, bounds, optParams)
%OPTIMIZEONEPOINT Pure compute for a single rate point - no file I/O
%   inside this function at all, which is what makes it safe to call from
%   inside a parfor loop over R without any concurrent-write risk (see
%   runSweep.m/+data/saveAllResults.m for where the single bulk write
%   happens, after the whole parfor completes).
fun = gear.makeObjective(ctx, R);
[optimal_parameters, E_per_bit] = gearboxphy.optimize.multistartOptimize(fun, x0, optParams, bounds);

if ~isinf(E_per_bit)
    budget = gear.computeBudget(ctx, optimal_parameters, R);
    if isscalar(x0)
        Optimal_B = ctx.B;                    % NA-QAM: fixed bandwidth
        Optimal_gamma = optimal_parameters(1);
    else
        Optimal_B = 10^optimal_parameters(1);
        Optimal_gamma = optimal_parameters(2);
    end
else
    budget = NaN;
    Optimal_B = NaN;
    Optimal_gamma = NaN;
    E_per_bit = NaN;
end
end
