function [OptimalParameters,PowerBudget] = get_min_E_bit_Pulse(R, modulation, params)
%GET_MIN_E_BIT_PULSE Multistart optimization of (log10 B, gamma) minimizing
%energy per bit for pulse/impulse-radio schemes.
%   See run_multistart_fminsearch.m for the shared restart logic (also
%   used by QAM/NA-QAM/ZXM), including a fix for a bug that used to cause
%   valid optima to be discarded as NaN.

f_c=params.f_c;

B_0=0.99*params.eta*f_c;
gamma_0=1;
x0=[log10(B_0),gamma_0];

fun = @(x)e_bit_fct_Pulse(x,params,modulation,R,"minimization");
[optimal_parameters, E_per_bit] = run_multistart_fminsearch(fun, x0, params);

if ~isinf(E_per_bit)
    PowerBudget=e_bit_fct_Pulse(optimal_parameters,params,modulation,R,"budget");
    Optimal_B=10^optimal_parameters(1);
    Optimal_gamma=optimal_parameters(2);
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
