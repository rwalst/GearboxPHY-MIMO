function [P_PS, L_PS] = phaseShifterParams(f_c, psType)
%PHASESHIFTERPARAMS Per-element phase-shifter DC power [W] and insertion
%   loss [linear] for analog beamforming, by carrier frequency and PS type.
%   Literature review and derivation: PHASE_SHIFTER_POWER_MODEL.md.
%
%   "active"  - vector modulator: P_PS ~ 15-25 mW with no visible f_c trend
%               over 8-60 GHz, ~0 dB gain, so L_PS = 1. The 2.4 GHz value
%               is carried over (no verified datum at that carrier).
%   "passive" - reflection-type/switched: P_PS = 0, loss L_PS. Its cost
%               enters via phaseShifterPenalty, not here.
%   Neither depends on B or on the resolution b (continuous control).
arguments
    f_c (1,1) double
    psType (1,1) string {mustBeMember(psType, ["active","passive"])}
end
if f_c == 2.4e9
    P_act = 20e-3;   L_dB = 6;     % pSemi PE44820, 8 bit, 1.7-2.2 GHz
elseif f_c == 8e9
    P_act = 16.6e-3; L_dB = 11;    % Kibaroglu (active); Chen 2015 8-14 dB (passive)
elseif f_c == 28e9
    % Survey of 151 phase shifters (LituratureReview/ps_survey): active
    % median 24 mW; passive in CMOS at 28-40 GHz 6.4-11.9 dB for 3-5 bit,
    % median 7.6 dB (reflection type 7.75-9.5 dB).
    P_act = 20e-3;   L_dB = 7.5;
elseif f_c == 60e9
    P_act = 19.8e-3; L_dB = 9.9;   % Yu 2016 TMTT (active); 130 nm BiCMOS RTPS
else
    error('gearboxphy:unsupportedBand', 'f_c=%g not supported', f_c);
end
if psType == "active"
    P_PS = P_act; L_PS = 1;
else
    P_PS = 0;     L_PS = 10^(L_dB/10);
end
end
