function gear = naQamGear()
%NAQAMGEAR Non-adaptive QAM: bandwidth fixed at eta*f_c, only gamma is
%   optimized (1-D, box-bounded [0,1] -> fminbnd). Fixed order 1024
%   (matches Wrapper.m's modulation.order=max(M_QAM_list)). Ported from
%   get_min_E_bit_NA_QAM.m + e_bit_fct_NA_QAM_v2.m.
%
%   isBaseline=true marks this as the designated savings/argmin baseline
%   gear that +report/plotOptimalGearReport.m and plotSavingsReport.m
%   compare every other gear against - checked via this explicit field
%   (see +gears/isBaselineGear.m) rather than a hardcoded "NA-QAM" string
%   duplicated across report files (code review finding #6).
gear.name = "NA-QAM";
gear.orders = 1024;
gear.isBaseline = true;
% MULTIPLEXING: SISO only - no MIMO SE curve exists for this gear
% (MIMO_EXTENSION.md decision 2). BEAMFORMING: the array buys path-loss
% gain on the unchanged SISO curve, so the scenario's candidate list
% applies here too. Important for the baseline gear specifically - if
% NA-QAM alone were denied antennas, every savings figure would compare
% a beamforming system against a SISO baseline and overstate the gain.
gear.antennaConfigs = @(order, cs) localAntennaConfigs(cs);
gear.prepare = @prepare;
gear.initialGuess = @(order, cs) 1;          % gamma_0 = 1 (scalar)
gear.optimizerBounds = @(order, cs) [0, 1];   % bounded -> fminbnd
gear.makeObjective = @makeObjective;
gear.computeBudget = @computeBudget;
end

function mode = localMode(cs)
mode = "multiplexing";
if isfield(cs,'antennaMode'), mode = cs.antennaMode; end
end

function cfgs = localAntennaConfigs(cs)
if localMode(cs) == "beamforming"
    cfgs = cs.beamformingConfigs;
else
    cfgs = {struct('N_t', 1, 'N_r', 1)};
end
end

function ctx = prepare(order, cs, antennaConfig)
gearboxphy.physics.assertDigitalArch(cs, antennaConfig, "NA-QAM");
M = order;
seData = gearboxphy.data.loadSECurve("NA-QAM", M, antennaConfig, cs.dataDir, localMode(cs));
ctx.N_t = antennaConfig.N_t;
ctx.N_r = antennaConfig.N_r;
bwFactor = gearboxphy.physics.containmentBandwidth(cs.alpha, 99);
rawMui = seData.SE_vec ./ bwFactor;
[ctx.mui_vec, ctx.SNR_vec] = gearboxphy.optimize.trimCurve(rawMui, seData.SNR_vec);
ctx.M = M;

if max(ctx.mui_vec) > log2(M)
    warning('gearboxphy:naqam:seOutOfRange', ...
        'NA-QAM SE curve for M=%d exceeds log2(M) - check SE_data table.', M);
end

ctx.B = cs.eta * cs.f_c;    % fixed bandwidth - NOT optimized
% ADC/DAC getrennt, Begruendung siehe qamGear.m: der DAC bleibt bei
% 1/2*log2(M), der ADC bezahlt die Aufloesung der Kurve (sourceB), ohne
% das Feld ebenfalls 1/2*log2(M) - bisherige Ergebnisse bleiben bitgenau.
ctx.b_DAC = log2(sqrt(M));
ctx.pow2_b_DAC = 2^ctx.b_DAC;
if isfinite(seData.sourceB)
    ctx.b_ADC = seData.sourceB;
else
    ctx.b_ADC = log2(sqrt(M));
end
ctx.pow2_b_ADC = 2^ctx.b_ADC;
ctx.sqrt_fc = sqrt(cs.f_c);
% Einzige Stelle, an der die Antennenzahl ins Linkbudget eingeht.
ctx.L_dB = gearboxphy.physics.linkBudgetDb(cs, antennaConfig);
% LO power per side, with the optional distribution to every mixer beyond
% the first (loDistributionPower.m; 0 by default).
ctx.P_LO_Tx = cs.P_LO + gearboxphy.physics.loDistributionPower(cs, ctx.N_t);
ctx.P_LO_Rx = cs.P_LO + gearboxphy.physics.loDistributionPower(cs, ctx.N_r);
PAPR_QAM_Linear = 3*(sqrt(M)-1)/(sqrt(M)+1);
ctx.papr = 10^((10*log10(PAPR_QAM_Linear)+3+3.17)/10);

ctx.hw = narrowHwParams(cs);

% B is fixed here (doesn't depend on gamma, the only optimization
% variable), so - unlike QAM/ZXM/Pulse - P_ADC/P_LNA/P_DAC are fully
% precomputed once too, not just their loop-invariant sub-terms.
% Skalierung je Kette wie in qamGear.m: ADC/LNA mit N_r, DAC mit N_t,
% Mischer je Seite mit N_t bzw. N_r. Der LO bleibt EINMAL gezaehlt.
ctx.P_ADC = ctx.N_r * gearboxphy.physics.adcPower(ctx.B, ctx.pow2_b_ADC, ctx.hw.f_b, ctx.hw.c_ADC);
ctx.P_LNA = ctx.N_r * gearboxphy.physics.lnaPowerFor(ctx.hw.lna, ctx.B);
ctx.P_DAC = ctx.N_t * gearboxphy.physics.dacPower(ctx.B, ctx.b_DAC, ctx.pow2_b_DAC, ctx.hw.DAC_VDD, ctx.hw.DAC_I0, ctx.hw.DAC_Cp);
ctx.P_Mix_Tx = ctx.N_t * ctx.hw.P_Mix;
ctx.P_Mix_Rx = ctx.N_r * ctx.hw.P_Mix;
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

% PA-Modellschalter wie in qamGear.m (PA_POWER_MODEL_DECISION.md).
if cs.paPowerModel == "affine"
    assert(~isnan(cs.P_0), 'gearboxphy:naqam:missingP0', ...
        'scenario.paPowerModel="affine" requires scenario.P_0 (fixed per-PA overhead, Watts).');
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
out = (1/R) * ( (gamma+hw.epsilon_trans*(1-gamma))*(core.P_PA+ctx.P_DAC+ctx.P_LO_Tx+ctx.P_Mix_Tx) ...
              + (gamma+hw.epsilon_rec*(1-gamma))*(ctx.P_ADC+ctx.P_LNA+ctx.P_LO_Rx+ctx.P_Mix_Rx) );
end

function budget = computeBudget(ctx, x, R)
core = computeCore(x, ctx, R);
hw = ctx.hw;
gamma = core.gamma;
budget.PA     = (1/R)*(gamma+hw.epsilon_trans*(1-gamma))*core.P_PA;
budget.DAC    = (1/R)*(gamma+hw.epsilon_trans*(1-gamma))*ctx.P_DAC;
budget.LO_Tx  = (1/R)*(gamma+hw.epsilon_trans*(1-gamma))*ctx.P_LO_Tx;
budget.Mix_Tx = (1/R)*(gamma+hw.epsilon_trans*(1-gamma))*ctx.P_Mix_Tx;
budget.LNA    = (1/R)*(gamma+hw.epsilon_rec*(1-gamma))*ctx.P_LNA;
budget.LO_Rx  = (1/R)*(gamma+hw.epsilon_rec*(1-gamma))*ctx.P_LO_Rx;
budget.Mix_Rx = (1/R)*(gamma+hw.epsilon_rec*(1-gamma))*ctx.P_Mix_Rx;
budget.ADC    = (1/R)*(gamma+hw.epsilon_rec*(1-gamma))*ctx.P_ADC;
end

function core = computeCore(x, ctx, R)
%COMPUTECORE Shared feasibility check + P_PA computation between
%   objective() and computeBudget() (code review finding #7). P_ADC/
%   P_LNA/P_DAC aren't part of this - they're fully precomputed in
%   prepare() since they don't depend on gamma (the only x here) at all.
hw = ctx.hw;
gamma = x(1);
B = ctx.B;
core.gamma = gamma;

if gamma<0 || gamma>1
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
core.P_PA = gearboxphy.physics.powerAmplifier(P_t, ctx.sqrt_fc, ctx.papr, hw.c_PA, ctx.N_t, hw.P_0);
end
