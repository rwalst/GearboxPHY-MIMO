function [best_params, best_value] = run_multistart_fminsearch(objective_fun, x0, params)
%RUN_MULTISTART_FMINSEARCH Repeated fminsearch from randomly perturbed
%starting points; returns the best (lowest-objective) result found.
%
%   objective_fun : function handle of x alone (already bound to R, M/Mtx,
%                   f_c, modulation, etc. by the caller)
%   x0            : initial guess (row vector, e.g. [log10(B_0), gamma_0])
%   params        : struct with fields tolerance, maxiters, numtriesPerOpt
%
%   Returns best_value = Inf when every restart was infeasible.
%
%   This restart loop used to be duplicated near-verbatim across
%   get_min_E_bit_QAM.m, get_min_E_bit_NA_QAM.m, get_min_E_bit_ZXM.m and
%   get_min_E_bit_Pulse.m. All four copies then checked feasibility with
%   `if(~isinf(value))`, where `value` was a leftover loop variable
%   holding the *last* restart's objective value rather than the best one
%   - so whenever the final restart (a small random perturbation of x0)
%   happened to be infeasible, a perfectly good optimum found by an
%   earlier restart was silently discarded and the point saved as NaN.
%   Fixed here once: feasibility is judged from min(vals), not the last
%   iteration.

numtries = params.numtriesPerOpt;
dim = numel(x0);
vals = NaN(numtries,1);
optimal_parameters_vec = NaN(numtries,dim);

options = optimset('TolX',params.tolerance,'TolFun',params.tolerance, ...
    'MaxIter',params.maxiters,'MaxFunEvals',params.maxiters,'Display','off');

for i = 1:numtries
    x_i = x0;
    if i>1
        x_i = x_i./(1+rand(1,dim).*0.1);
    end
    [optimal_parameters,value] = fminsearch(objective_fun,x_i,options);
    optimal_parameters_vec(i,:) = optimal_parameters;
    vals(i) = value;
end

best_value = min(vals);
index = find(vals==best_value,1,'first');
best_params = optimal_parameters_vec(index,:);

end
