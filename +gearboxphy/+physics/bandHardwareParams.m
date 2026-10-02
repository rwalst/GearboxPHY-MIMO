function [P_Mix, P_LO, etaOverride] = bandHardwareParams(f_c)
%BANDHARDWAREPARAMS Per-carrier-frequency P_Mix/P_LO literature constants
%   (and, for the WiFi7 bands, an eta override). Ported from Sim_Init.m's
%   if/elseif dispatch on f_c. The 28GHz P_LO=26.9mW value is confirmed
%   as the intended one (over the retired get_params.m's stale 10.8mW
%   value for the same quantity - see ARCHITECTURE_PLAN.md section 6,
%   item 5).
%   etaOverride is NaN when the band doesn't override scenario.eta.
etaOverride = NaN;
if f_c == 2.4e9
    P_Mix = 1.57e-3; P_LO = 6e-3;
elseif f_c == 28e9
    P_Mix = 8.4e-3; P_LO = 26.9e-3;
elseif f_c == 60e9
    P_Mix = 17e-3; P_LO = 60e-3;
elseif f_c == 120e9
    P_Mix = 8e-3; P_LO = 43e-3;
elseif f_c == 8e9
    P_Mix = 6.9e-3; P_LO = 14.9e-3;
elseif f_c == 6e9
    P_Mix = 1.57e-3; P_LO = 6e-3; etaOverride = 0.3;
elseif f_c == 6.1e9
    P_Mix = 1.57e-3; P_LO = 6e-3; etaOverride = 0.3;
else
    error('gearboxphy:unsupportedBand', 'f_c=%g not supported', f_c);
end
end
