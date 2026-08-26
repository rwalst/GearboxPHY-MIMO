function [OptimalParameters,PowerBudget] = get_min_E_bit_QAM(R, M, params)
%GET_MIN_E_BIT_QAM Multistart optimization of (log10 B, gamma) minimizing
%energy per bit for adaptive-bandwidth QAM.
%   See run_multistart_fminsearch.m for the shared restart logic (also
%   used by NA-QAM/ZXM/Pulse), including a fix for a bug that used to
%   cause valid optima to be discarded as NaN.

f_c=params.f_c;

B_0=0.99*params.eta*f_c;
gamma_0=1;
x0=[log10(B_0),gamma_0];

%Precompute quantities that do not depend on the optimization variable x
%=(log10 B, gamma): they only depend on M/f_c/params, which are all fixed
%for the duration of this call. e_bit_fct_QAM_v2.m used to recompute all
%of these from scratch on every one of the (numtriesPerOpt x up to
%maxiters) objective evaluations fminsearch performs for this single
%(R,M,f_c) point - same result every time, just wasted work. Stashed into
%params.inv_* (read back out in e_bit_fct_QAM_v2.m) rather than changed
%as function arguments, so every existing call site keeps working as-is.
lambda=params.c/f_c;
L=( params.D_r*params.D_t*(lambda/(4*pi*params.distance))^params.beta )^(-1); %To match definition in paper
PAPR_QAM_Linear=3*(sqrt(M)-1)/(sqrt(M)+1);
params.inv_b=log2(sqrt(M));
params.inv_pow2_b=2^params.inv_b;
params.inv_sqrt_fc=sqrt(f_c);
params.inv_L_dB=10*log10(L);
params.inv_PAPR=10^((10*log10(PAPR_QAM_Linear)+3+3.17)/10);
params.inv_B_max=params.eta*f_c;

fun = @(x)e_bit_fct_QAM_v2(x,params,M,R,f_c,"minimization");
[optimal_parameters, E_per_bit] = run_multistart_fminsearch(fun, x0, params);

if ~isinf(E_per_bit)
    PowerBudget=e_bit_fct_QAM_v2(optimal_parameters,params,M,R,f_c,"budget");
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
