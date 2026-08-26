function [OptimalParameters,PowerBudget] = get_min_E_bit_NA_QAM(R, M, params)
%GET_MIN_E_BIT_NA_QAM Multistart optimization of gamma minimizing energy
%per bit for non-adaptive QAM (bandwidth fixed at eta*f_c, not optimized).
%   See run_multistart_fminsearch.m for the shared restart logic (also
%   used by QAM/ZXM/Pulse), including a fix for a bug that used to cause
%   valid optima to be discarded as NaN.

f_c=params.f_c;

gamma_0=1;
x0=gamma_0;

fun = @(x)e_bit_fct_NA_QAM_v2(x,params,M,R,f_c,"minimization");
[optimal_parameters, E_per_bit] = run_multistart_fminsearch(fun, x0, params);

if ~isinf(E_per_bit)
    PowerBudget=e_bit_fct_NA_QAM_v2(optimal_parameters,params,M,R,f_c,"budget");
    Optimal_B=params.eta*f_c;
    Optimal_gamma=optimal_parameters(1);
else
    PowerBudget=NaN;
    Optimal_B=NaN;
    Optimal_gamma=NaN;
    E_per_bit=NaN;
end

OptimalParameters.E_per_bit=E_per_bit;
OptimalParameters.Optimal_B=Optimal_B;
OptimalParameters.Optimal_gamma=Optimal_gamma;

end
