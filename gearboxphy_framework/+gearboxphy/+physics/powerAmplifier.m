function P = powerAmplifier(P_t, sqrt_fc, papr, c_PA, N_t, P_0)
%POWERAMPLIFIER Transmit power-amplifier power draw. Two selectable
%   models (see PA_POWER_MODEL_DECISION.md):
%
%   - Model A "constant efficiency" (default, N_t=1/P_0=0 or any N_t with
%     P_0=0): P = c_PA*P_t*sqrt_fc*papr, independent of how many PAs
%     (N_t) share that total P_t. This is forced by "efficiency doesn't
%     depend on power level" - splitting P_t across N_t equally-efficient
%     PAs sums back to exactly this, so N_t drops out algebraically. This
%     is the original dissertation formula, unchanged.
%   - Model B "affine" (Auer et al. 2011's BS power model, P=P_0+beta*P_T,
%     applied per chain): each of N_t individual PAs also draws a fixed
%     per-chain overhead P_0 (independent of output power - Class-AB bias/
%     quiescent current, matching-network loss), so total power gains an
%     extra N_t*P_0 term on top of the same scale-invariant linear part.
%
%   Called with only 4 arguments (N_t/P_0 omitted), this defaults to
%   N_t=1, P_0=0 - i.e. exactly today's original formula, unchanged for
%   every gear that doesn't opt into the affine model or MIMO.
arguments
    P_t (1,1) double
    sqrt_fc (1,1) double
    papr (1,1) double
    c_PA (1,1) double
    N_t (1,1) double = 1
    P_0 (1,1) double = 0
end
P = N_t * P_0 + c_PA * P_t * sqrt_fc * papr;
end
