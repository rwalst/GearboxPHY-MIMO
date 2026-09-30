function [best_params, best_value] = multistartOptimize(objective_fun, x0, optParams, bounds)
%MULTISTARTOPTIMIZE Repeated local optimization from several starting
%   points/intervals; returns the best (lowest-objective) result. Ported
%   verbatim from run_multistart_fminsearch.m, including the min(vals)
%   feasibility fix (the original bug: checking the *last* restart's
%   value instead of the best across all restarts, which silently
%   discarded valid optima as NaN whenever the final random restart
%   happened to be infeasible).
%
%   objective_fun : function handle of x alone (built by a gear's
%                   makeObjective(ctx, R) - invariants already baked in)
%   x0            : initial guess (row vector, e.g. [log10(B_0), gamma_0])
%   optParams     : struct with fields tolerance, maxiters, numtriesPerOpt
%   bounds        : optional [lb ub], only meaningful when x0 is scalar
%                   (currently: NA-QAM's gamma in [0,1]). When given, the
%                   scalar case is solved with fminbnd instead of
%                   fminsearch (never leaves the feasible interval, unlike
%                   unconstrained fminsearch + Inf-penalty). Omit for the
%                   multi-dimensional case (QAM/ZXM/Pulse's [log10 B,
%                   gamma]) - MATLAB has no core box-constrained
%                   equivalent of fminbnd for N>1.
%
%   Returns best_value = Inf when every restart was infeasible.

numtries = optParams.numtriesPerOpt;
dim = numel(x0);
vals = NaN(numtries,1);
optimal_parameters_vec = NaN(numtries,dim);

options = optimset('TolX',optParams.tolerance,'TolFun',optParams.tolerance, ...
    'MaxIter',optParams.maxiters,'MaxFunEvals',optParams.maxiters,'Display','off');

if dim == 1 && nargin >= 4 && ~isempty(bounds)
    %% Scalar, box-bounded case (NA-QAM's gamma): use fminbnd.
    lb = bounds(1); ub = bounds(2);
    for i = 1:numtries
        if i == 1
            lo = lb; hi = ub;
        else
            lo = lb + rand()*0.3*(ub-lb);
            hi = ub - rand()*0.3*(ub-lb);
        end
        [xbest,fbest] = fminbnd(objective_fun, lo, hi, options);
        optimal_parameters_vec(i,:) = xbest;
        vals(i) = fbest;
    end
else
    %% General unconstrained case (or dim>1): fminsearch, as before.
    for i = 1:numtries
        x_i = x0;
        if i>1
            x_i = x_i./(1+rand(1,dim).*0.1);
        end
        [optimal_parameters,value] = fminsearch(objective_fun,x_i,options);
        optimal_parameters_vec(i,:) = optimal_parameters;
        vals(i) = value;
    end
end

best_value = min(vals);
index = find(vals==best_value,1,'first');
best_params = optimal_parameters_vec(index,:);

end
