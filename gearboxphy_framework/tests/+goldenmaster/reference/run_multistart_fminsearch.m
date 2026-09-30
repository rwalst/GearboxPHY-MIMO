function [best_params, best_value] = run_multistart_fminsearch(objective_fun, x0, params, bounds)
%RUN_MULTISTART_FMINSEARCH Repeated local optimization from several
%starting points/intervals; returns the best (lowest-objective) result.
%
%   objective_fun : function handle of x alone (already bound to R, M/Mtx,
%                   f_c, modulation, etc. by the caller)
%   x0            : initial guess (row vector, e.g. [log10(B_0), gamma_0])
%   params        : struct with fields tolerance, maxiters, numtriesPerOpt
%   bounds        : optional [lb ub], only meaningful when x0 is scalar
%                   (currently: NA-QAM's gamma in [0,1]). When given, the
%                   scalar case is solved with fminbnd instead of
%                   fminsearch (see rationale below). Omit for the
%                   multi-dimensional case (QAM/ZXM/Pulse's [log10 B,
%                   gamma]), which stays on the fminsearch + Inf-penalty
%                   approach - MATLAB has no box-constrained equivalent of
%                   fminbnd for N>1 outside the (not guaranteed licensed)
%                   Optimization Toolbox's fmincon, and reparametrizing
%                   the 2-D objective to be unconstrained would touch the
%                   e_bit_fct_*.m physics files themselves, which is a
%                   bigger risk than this change is worth.
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

if dim == 1 && nargin >= 4 && ~isempty(bounds)
    %% Scalar, box-bounded case (NA-QAM's gamma): use fminbnd.
    % The original approach ran fminsearch unconstrained and returned Inf
    % from the objective whenever x fell outside the box - which not only
    % wastes evaluations probing a region fminsearch had no way to know
    % was off-limits, but gives it zero gradient information there (an
    % Inf plateau looks the same everywhere), unlike fminbnd's
    % golden-section/parabolic search, which never leaves [lb,ub].
    %
    % fminbnd has no starting point, only an interval, so "restart from a
    % perturbed x0" doesn't apply. Instead each restart searches a
    % randomly shrunk sub-interval of [lb,ub] (the first restart always
    % gets the full interval), preserving the original multistart-style
    % defense against any local structure the piecewise-linear SNR lookup
    % table (interp1) might introduce, while each individual restart
    % converges in far fewer evaluations than an unconstrained
    % Nelder-Mead simplex with a penalty wall.
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
