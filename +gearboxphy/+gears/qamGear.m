function gear = qamGear()
%QAMGEAR Adaptive-bandwidth QAM. Optimizes 2-D (log10 B, gamma), fixed
%   orders 4/16/64/256/1024. Ported from get_min_E_bit_QAM.m +
%   e_bit_fct_QAM_v2.m.
%
%   The only gear with a MIMO variant (MIMO_EXTENSION.md decision 2).
%   antennaConfigs comes from the scenario (cs.qamMimoConfigs, default
%   SISO-only - see makeScenarioConfig.m) so enabling MIMO is a config
%   change, not a code change. +sweep/runSweep.m tries every candidate
%   antennaConfig for each (order, R, f_c) point and keeps whichever
%   gives the lowest energy-per-bit (MIMO_EXTENSION.md decision 4: joint
%   optimization via nested enumeration, not a mixed-integer solver).
gear.name = "QAM";
gear.orders = [4 16 64 256 1024];
% Candidates are filtered per-order to only those with an actual SE_data
% curve present - MIMO curves are externally supplied per order
% (MIMO_EXTENSION.md decision 3), so a scenario enabling e.g. 2x2
% globally will realistically only have matching data for some orders.
% A missing curve for one order is a visible warning, not a sweep-ending
% error - see +data/filterAvailableAntennaConfigs.m.
%   In BEAMFORMING mode the candidates come from cs.beamformingConfigs
%   instead and need NO filtering: every one of them reuses the SISO
%   curve, so there is no per-order MIMO file that could be missing.
gear.antennaConfigs = @(order, cs) localAntennaConfigs(order, cs);
gear.prepare = @prepare;
gear.initialGuess = @(order, cs) [log10(0.99*cs.eta*cs.f_c), 1];
gear.optimizerBounds = @(order, cs) [];   % 2-D, unconstrained -> fminsearch
gear.makeObjective = @makeObjective;
gear.computeBudget = @computeBudget;
end

function ctx = prepare(order, cs, antennaConfig)
M = order;
seData = gearboxphy.data.loadSECurve("QAM", M, antennaConfig, cs.dataDir, localMode(cs));
bwFactor = gearboxphy.physics.containmentBandwidth(cs.alpha, 99);
rawMui = seData.SE_vec ./ bwFactor;
[ctx.mui_vec, ctx.SNR_vec] = gearboxphy.optimize.trimCurve(rawMui, seData.SNR_vec);
ctx.M = M;
ctx.N_t = antennaConfig.N_t;
ctx.N_r = antennaConfig.N_r;

% Cap is N_t*log2(M), not log2(M): the SE_data curve for a MIMO
% antennaConfig legitimately carries N_t independent streams' worth of
% mutual information (e.g. 8x8/64-QAM saturates near 8*log2(64)=48 bit,
% not 6 bit). Comparing against the SISO cap alone fired spuriously for
% every genuine MIMO curve; N_t=1 recovers the original SISO check
% exactly, so no behavior changes for any existing SISO SE_data file.
% In beamforming mode the curve is the SISO one (one stream), so the cap
% is log2(M) again - using N_t*log2(M) there would make the check so
% loose it could never fire.
if localMode(cs) == "beamforming"
    capBits = log2(M);
else
    capBits = ctx.N_t * log2(M);
end
if max(ctx.mui_vec) > capBits
    warning('gearboxphy:qam:seOutOfRange', ...
        'QAM SE curve for M=%d, N_t=%d exceeds N_t*log2(M)=%.4g - check SE_data table.', ...
        M, ctx.N_t, capBits);
end

% ADC und DAC werden GETRENNT aufgeloest:
%   DAC: bleibt bei der Dissertations-Aufloesung 1/2*log2(M). DAC-
%        Quantisierung steckt in keinem SE-Modell (weder Gasts SISO-Kurven
%        noch QuantizedMimoMI) - mehr DAC-Bits kosteten nur Leistung und
%        braechten im Modell nichts.
%   ADC: bezahlt GENAU die Aufloesung, mit der die SE-Kurve gerechnet wurde
%        (sourceB aus der Kurvendatei, z.B. 1/2*log2(M)+log2(N)+3 fuer die
%        HPC-Kurven). Ohne das Feld (Gasts SISO-Kurven) gilt ebenfalls
%        1/2*log2(M) - damit bleibt jedes bisherige Ergebnis bitgenau.
%   Frueher bezahlte der ADC hier immer 1/2*log2(M), auch fuer MIMO-Kurven,
%   die mit feinerem ADC gerechnet waren: die SE kam dann von einem ADC,
%   der um 2^(sourceB - 1/2*log2(M)) teurer ist als bezahlt.
ctx.b_DAC = log2(sqrt(M));
ctx.pow2_b_DAC = 2^ctx.b_DAC;
if isfinite(seData.sourceB)
    ctx.b_ADC = seData.sourceB;
else
    ctx.b_ADC = log2(sqrt(M));
end
ctx.pow2_b_ADC = 2^ctx.b_ADC;
ctx.sqrt_fc = sqrt(cs.f_c);
% MIMO_EXTENSION.md decision 1: D_r/D_t still apply on top of the MIMO SE
% curve (which is treated as a pure channel-capacity/SNR relationship,
% no array gain baked in) - pathLossDb is unchanged and unaware of
% antenna count.
ctx.L_dB = gearboxphy.physics.linkBudgetDb(cs, antennaConfig);
% Analog beamforming (docs/ANALOG_BEAMFORMING.md): chain counts, phase-
% shifter power and loss. Disabled by default; then nothing below reads
% anything but ctx.abf.enabled and the per-chain path is unchanged.
ctx.abf = gearboxphy.physics.analogBeamformingParams(cs, antennaConfig);
if ctx.abf.enabled
    ctx.L_dB = ctx.L_dB + ctx.abf.extra_L_dB;
end
% LO power per side: P_LO, plus the distribution to every mixer beyond the
% first if the scenario asks for it (loDistributionPower.m; 0 by default).
% An analog array has ONE mixer per side.
if ctx.abf.enabled
    nMixTx = ctx.abf.nChainsTx; nMixRx = ctx.abf.nChainsRx;
else
    nMixTx = ctx.N_t; nMixRx = ctx.N_r;
end
ctx.P_LO_Tx = cs.P_LO + gearboxphy.physics.loDistributionPower(cs, nMixTx);
ctx.P_LO_Rx = cs.P_LO + gearboxphy.physics.loDistributionPower(cs, nMixRx);

PAPR_QAM_Linear = 3*(sqrt(M)-1)/(sqrt(M)+1);
% PAPR_RRC (the original get_QAM_PAPR.m/qammod-based, more accurate
% RRC-shaped PAPR) is deliberately NOT wired in here - open dissertation
% question, kept as a TODO per decision (ARCHITECTURE_PLAN.md section 6,
% item 1).
ctx.papr = 10^((10*log10(PAPR_QAM_Linear)+3+3.17)/10);
ctx.B_max = cs.eta * cs.f_c;

ctx.hw = narrowHwParams(cs);
end

function mode = localMode(cs)
mode = "multiplexing";
if isfield(cs,'antennaMode'), mode = cs.antennaMode; end
end

function cfgs = localAntennaConfigs(order, cs)
if localMode(cs) == "beamforming"
    cfgs = cs.beamformingConfigs;
else
    cfgs = gearboxphy.data.filterAvailableAntennaConfigs( ...
        "QAM", order, cs.qamMimoConfigs, cs.dataDir);
end
end

function hw = narrowHwParams(cs)
hw.N_0 = cs.N_0;
hw.c_PA = cs.c_PA;
hw.c_ADC = cs.c_ADC;
hw.f_b = cs.f_b;
hw.DAC_VDD = cs.DAC_VDD;
hw.DAC_I0 = cs.DAC_I0;
hw.DAC_Cp = cs.DAC_Cp;
hw.Maximum_P_T = cs.Maximum_P_T;
hw.epsilon_trans = cs.epsilon_trans;
hw.epsilon_rec = cs.epsilon_rec;
hw.P_LO = cs.P_LO;
hw.P_Mix = cs.P_Mix;
% LNA model switch (LNA_POWER_MODEL.md); default = dissertation formula.
hw.lna = gearboxphy.physics.lnaParams(cs);

% PA power model trigger (PA_POWER_MODEL_DECISION.md). "constant"
% (default) forces P_0=0 regardless of what scenario.P_0 holds, so
% P_PA stays exactly the original, scale-invariant formula (Model A) -
% switching paPowerModel back to "constant" can never be silently
% undermined by a leftover P_0 value. "affine" requires a real,
% non-NaN P_0 (fixed per-PA overhead, Watts) or fails loudly here
% rather than quietly running with P_0=0 (indistinguishable from
% "constant").
if cs.paPowerModel == "affine"
    assert(~isnan(cs.P_0), 'gearboxphy:qam:missingP0', ...
        'scenario.paPowerModel="affine" requires scenario.P_0 (fixed per-PA overhead, Watts) to be set - see PA_POWER_MODEL_DECISION.md.');
    hw.P_0 = cs.P_0;
else
    hw.P_0 = 0;
end
end

function fun = makeObjective(ctx, R)
fun = @(x) objective(x, ctx, R);
end

function out = objective(x, ctx, R)
core = computeCore(x, ctx, R);
if ~core.feasible
    out = inf; return
end
hw = ctx.hw;
gamma = core.gamma;
if ctx.abf.enabled
    % phase shifters ride along with the chain they sit in
    out = (1/R) * ( (gamma+hw.epsilon_trans*(1-gamma))*(core.P_PA+core.P_DAC+ctx.P_LO_Tx+core.P_Mix_Tx+ctx.abf.P_PS_Tx) ...
                  + (gamma+hw.epsilon_rec*(1-gamma))*(core.P_ADC+core.P_LNA+ctx.P_LO_Rx+core.P_Mix_Rx+ctx.abf.P_PS_Rx) );
    return
end
out = (1/R) * ( (gamma+hw.epsilon_trans*(1-gamma))*(core.P_PA+core.P_DAC+ctx.P_LO_Tx+core.P_Mix_Tx) ...
              + (gamma+hw.epsilon_rec*(1-gamma))*(core.P_ADC+core.P_LNA+ctx.P_LO_Rx+core.P_Mix_Rx) );
end

function budget = computeBudget(ctx, x, R)
core = computeCore(x, ctx, R);
hw = ctx.hw;
gamma = core.gamma;
budget.PA     = (1/R)*(gamma+hw.epsilon_trans*(1-gamma))*core.P_PA;
budget.DAC    = (1/R)*(gamma+hw.epsilon_trans*(1-gamma))*core.P_DAC;
budget.LO_Tx  = (1/R)*(gamma+hw.epsilon_trans*(1-gamma))*ctx.P_LO_Tx;
budget.Mix_Tx = (1/R)*(gamma+hw.epsilon_trans*(1-gamma))*core.P_Mix_Tx;
budget.LNA    = (1/R)*(gamma+hw.epsilon_rec*(1-gamma))*core.P_LNA;
budget.LO_Rx  = (1/R)*(gamma+hw.epsilon_rec*(1-gamma))*ctx.P_LO_Rx;
budget.Mix_Rx = (1/R)*(gamma+hw.epsilon_rec*(1-gamma))*core.P_Mix_Rx;
budget.ADC    = (1/R)*(gamma+hw.epsilon_rec*(1-gamma))*core.P_ADC;
% Only in analog mode, so a digital budget keeps exactly its eight fields.
if ctx.abf.enabled
    budget.PS_Tx = (1/R)*(gamma+hw.epsilon_trans*(1-gamma))*ctx.abf.P_PS_Tx;
    budget.PS_Rx = (1/R)*(gamma+hw.epsilon_rec*(1-gamma))*ctx.abf.P_PS_Rx;
end
end

function core = computeCore(x, ctx, R)
%COMPUTECORE Shared feasibility check + power-term computation between
%   objective() and computeBudget().
hw = ctx.hw;
B = 10^x(1);
gamma = x(2);
core.gamma = gamma;
core.B = B;

if gamma<0 || gamma>1 || B>ctx.B_max || B<0
    core.feasible = false; return
end

S = R/(gamma*B);
SNR_rec = gearboxphy.optimize.snrLookup(S, ctx.mui_vec, ctx.SNR_vec);
SNR_transmitter = SNR_rec + ctx.L_dB;
P_t = 10^(SNR_transmitter/10) * hw.N_0 * B;
if P_t > hw.Maximum_P_T
    core.feasible = false; return
end

core.feasible = true;

% --- MIMO hardware power scaling (MIMO_EXTENSION.md section 2) ---
% ADC/LNA/DAC/mixer are FIXED per-chain circuit-power terms (functions of
% B/bit-width only, never of P_t) - exactly the "one converter+mixer+
% filter block per antenna" component Bjornson et al. (2015, Sec.
% II-B-1) describe, and exactly the pattern this codebase's own ZXM gear
% already uses for its M_tx multiplicity. These scale linearly with
% antenna count: ADC/LNA/mixer with N_r (receive chains), DAC/mixer with
% N_t (transmit chains). The LO stays a single shared value regardless of
% antenna count or Tx/Rx role (decision 2).
%
% P_PA's N_t-scaling is a scenario-level trigger, not hardcoded here -
% see PA_POWER_MODEL_DECISION.md for the full derivation of both models.
% Default (hw.P_0=0, forced whenever scenario.paPowerModel="constant"):
% Model A, scale-invariant in N_t - splitting the same total P_t across
% N_t equally-efficient PAs sums back to exactly the original,
% unscaled dissertation formula. Setting scenario.paPowerModel="affine"
% with a real scenario.P_0 switches to Model B (Auer et al. 2011): each
% PA also draws a fixed per-chain overhead, adding N_t*P_0 on top.
if ctx.abf.enabled
    % --- analog beamforming: ONE converter/mixer chain per side, N PAs
    % and N LNAs. The driver that makes up the phase-shifter loss scales
    % the RF-dependent PA power only, not a fixed per-PA overhead P_0.
    P_PA_rf = gearboxphy.physics.powerAmplifier(P_t, ctx.sqrt_fc, ctx.papr, hw.c_PA, 1, 0);
    core.P_PA = ctx.N_t * hw.P_0 + ctx.abf.kappa_Tx * P_PA_rf;
    core.P_ADC = ctx.abf.nChainsRx * gearboxphy.physics.adcPower(B, ctx.pow2_b_ADC, hw.f_b, hw.c_ADC);
    core.P_LNA = ctx.N_r * ctx.abf.lnaFactor * gearboxphy.physics.lnaPowerFor(hw.lna, B);
    core.P_DAC = ctx.abf.nChainsTx * gearboxphy.physics.dacPower(B, ctx.b_DAC, ctx.pow2_b_DAC, hw.DAC_VDD, hw.DAC_I0, hw.DAC_Cp);
    core.P_Mix_Tx = ctx.abf.nChainsTx * hw.P_Mix;
    core.P_Mix_Rx = ctx.abf.nChainsRx * hw.P_Mix;
    return
end
core.P_PA = gearboxphy.physics.powerAmplifier(P_t, ctx.sqrt_fc, ctx.papr, hw.c_PA, ctx.N_t, hw.P_0);
core.P_ADC = ctx.N_r * gearboxphy.physics.adcPower(B, ctx.pow2_b_ADC, hw.f_b, hw.c_ADC);
core.P_LNA = ctx.N_r * gearboxphy.physics.lnaPowerFor(hw.lna, B);
core.P_DAC = ctx.N_t * gearboxphy.physics.dacPower(B, ctx.b_DAC, ctx.pow2_b_DAC, hw.DAC_VDD, hw.DAC_I0, hw.DAC_Cp);
core.P_Mix_Tx = ctx.N_t * hw.P_Mix;
core.P_Mix_Rx = ctx.N_r * hw.P_Mix;
end
