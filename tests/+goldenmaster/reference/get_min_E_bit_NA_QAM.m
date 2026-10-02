function [OptimalParameters,PowerBudget] = get_min_E_bit_NA_QAM(R, M, params)
%GET_MIN_E_BIT_NA_QAM Multistart optimization of gamma minimizing energy
%per bit for non-adaptive QAM (bandwidth fixed at eta*f_c, not optimized).
%   See run_multistart_fminsearch.m for the shared restart logic (also
%   used by QAM/ZXM/Pulse), including a fix for a bug that used to cause
%   valid optima to be discarded as NaN.

f_c=params.f_c;

gamma_0=1;
x0=gamma_0;

%Precompute quantities that do not depend on gamma - the only
%optimization variable here (unlike QAM/ZXM/Pulse, NA-QAM's bandwidth is
%fixed at eta*f_c, not optimized). Since B doesn't depend on gamma,
%neither do P_ADC/P_LNA/P_DAC, so - unlike the other three families -
%those can be computed exactly once here rather than on every one of the
%many objective evaluations fminbnd performs. See e_bit_fct_NA_QAM_v2.m
%for how these feed the energy-per-bit formula.
B=params.eta*f_c;
b=log2(sqrt(M));
pow2_b=2^b;
lambda=params.c/f_c;
L=( params.D_r*params.D_t*(lambda/(4*pi*params.distance))^params.beta )^(-1); %To match definition in paper
PAPR_QAM_Linear=3*(sqrt(M)-1)/(sqrt(M)+1);
FoM_LNA=10^(-7);

params.inv_B=B;
params.inv_sqrt_fc=sqrt(f_c);
params.inv_L_dB=10*log10(L);
params.inv_PAPR=10^((10*log10(PAPR_QAM_Linear)+3+3.17)/10);
params.inv_P_ADC=2*params.c_ADC*pow2_b*B*sqrt(1+(B/params.f_b)^2);
params.inv_P_LNA=32*B*params.N_0/((3-1)*FoM_LNA);
params.inv_P_DAC=2*(1/2*params.DAC_VDD*params.DAC_I0*(pow2_b-1)+params.DAC_Cp*params.DAC_VDD^2*b*B);

fun = @(x)e_bit_fct_NA_QAM_v2(x,params,M,R,f_c,"minimization");
%gamma's feasible domain is exactly [0,1] (see e_bit_fct_NA_QAM_v2.m's own
%gamma<0||gamma>1 check) - passing that as explicit bounds lets
%run_multistart_fminsearch use fminbnd instead of unconstrained
%fminsearch + Inf-penalty for this scalar case.
[optimal_parameters, E_per_bit] = run_multistart_fminsearch(fun, x0, params, [0,1]);

if ~isinf(E_per_bit)
    PowerBudget=e_bit_fct_NA_QAM_v2(optimal_parameters,params,M,R,f_c,"budget");
    Optimal_B=B;
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
