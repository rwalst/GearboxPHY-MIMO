function [OptimalParameters,PowerBudget] = get_min_E_bit_ZXM(R, Mtx, params)
%GET_MIN_E_BIT_ZXM Multistart optimization of (log10 B, gamma) minimizing
%energy per bit for ZXM.
%   See run_multistart_fminsearch.m for the shared restart logic (also
%   used by QAM/NA-QAM/Pulse), including a fix for a bug that used to
%   cause valid optima to be discarded as NaN.

f_c=params.f_c;

B_0=0.99*params.eta*f_c;
gamma_0=1;
x0=[log10(B_0),gamma_0];

%Precompute quantities that do not depend on the optimization variable x
%=(log10 B, gamma): they only depend on f_c/params, fixed for the
%duration of this call. e_bit_fct_ZXM.m used to recompute all of these
%from scratch on every one of the many objective evaluations fminsearch
%performs for this single (R,Mtx,f_c) point. Unlike NA-QAM, B here IS
%being optimized, so P_ADC/P_DAC (which depend on B) still have to be
%evaluated inside e_bit_fct_ZXM.m on every call - only the truly
%B-independent pieces are hoisted out.
lambda=params.c/f_c;
L=( params.D_r*params.D_t*(lambda/(4*pi*params.distance))^params.beta )^(-1); %To match definition in paper
params.inv_B_max=params.eta*f_c;
params.inv_L_dB=10*log10(L);
params.inv_PAPR=10^((3.63+3)/10); %ZXM has rather constant PAPR see peter neuhaus ojcoms
params.inv_sqrt_fc=sqrt(f_c);

fun = @(x)e_bit_fct_ZXM(x,params,Mtx,R,f_c,"minimization");
[optimal_parameters, E_per_bit] = run_multistart_fminsearch(fun, x0, params);

if ~isinf(E_per_bit)
    PowerBudget=e_bit_fct_ZXM(optimal_parameters,params,Mtx,R,f_c,"budget");
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
