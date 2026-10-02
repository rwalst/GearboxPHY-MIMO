function [kappa_Tx, delta_Rx_dB] = phaseShifterPenalty(L_PS, G_PA, G_LNA, F_LNA)
%PHASESHIFTERPENALTY Cost of a lossy (passive) phase shifter placed before
%   the PA / after the LNA. See PHASE_SHIFTER_POWER_MODEL.md section 2.3.
%   An active PS (L_PS = 1) gives kappa_Tx = 1 and delta_Rx_dB = 0.
%
%   kappa_Tx    - factor on the PA term: a driver must make up the extra
%                 (L_PS-1) of PA input drive, at the PA's efficiency:
%                 P_PA -> P_PA*(1 + (L_PS-1)/G_PA).
%   delta_Rx_dB - extra link loss [dB] from Friis, F = F_LNA+(L_PS-1)/G_LNA.
%                 Relative to F_LNA, because the link budget uses N_0 = kT
%                 without a noise figure.
%
%   Defaults: G_PA = 20 dB (assumption), G_LNA = 32 and F_LNA = 3 as in
%   lnaPower.m.
arguments
    L_PS (1,1) double {mustBeGreaterThanOrEqual(L_PS, 1)}
    G_PA (1,1) double = 100
    G_LNA (1,1) double = 32
    F_LNA (1,1) double = 3
end
kappa_Tx = 1 + (L_PS - 1) / G_PA;
delta_Rx_dB = 10*log10(1 + (L_PS - 1) / (G_LNA * F_LNA));
end
