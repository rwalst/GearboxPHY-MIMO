function P = lnaPowerEnvelope(f_c, B, beta_min)
%LNAPOWERENVELOPE Empirical lower bound on LNA DC power [W], per element,
%   for an LNA designed for exactly the bandwidth it needs (Gearbox
%   paradigm), but no narrower than technology allows:
%       P = 0.776 mW * (f_c/1 GHz)^0.280 * (B_eff/1 GHz)^0.457
%       B_eff = max(B, beta_min*f_c),  beta_min = 0.05 by default
%   5 % quantile regression over 317 silicon LNAs (CMOS+SiGe, G >= 15 dB,
%   NF <= 5 dB, 1-100 GHz) in the Belostotski LNA survey; beta_min is the
%   survey's 5th-percentile fractional bandwidth. At the floor:
%   0.38 / 0.91 / 2.30 / 4.04 mW at 2.4 / 8 / 28 / 60 GHz.
%   Derivation and fit script: LNA_POWER_MODEL.md,
%   LituratureReview/lna_survey_fit/. Alternative to lnaPower.m, not wired
%   into any gear.
arguments
    f_c (1,1) double
    B (1,1) double
    beta_min (1,1) double = 0.05
end
B_eff = max(B, beta_min * f_c);
P = 0.776e-3 * (f_c / 1e9)^0.280 * (B_eff / 1e9)^0.457;
end
