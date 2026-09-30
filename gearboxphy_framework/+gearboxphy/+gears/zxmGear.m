function gear = zxmGear()
%ZXMGEAR Run-length-limited ZXM line code (Neuhaus et al.). Optimizes 2-D
%   (log10 B, gamma), fixed orders M_tx=1/2/3. Ported from
%   get_min_E_bit_ZXM.m + e_bit_fct_ZXM.m.
gear.name = "ZXM";
gear.orders = [1 2 3];
% No spatial-MULTIPLEXING variant exists (MIMO_EXTENSION.md decision 2):
% there is no ZXM MIMO SE curve. BEAMFORMING is different - it reuses the
% SISO curve and only buys path-loss gain, so it needs no new data and is
% available here (BEAMFORMING_EXTENSION.md).
gear.antennaConfigs = @(order, cs) localAntennaConfigs(cs);
gear.prepare = @prepare;
gear.initialGuess = @(order, cs) [log10(0.99*cs.eta*cs.f_c), 1];
gear.optimizerBounds = @(order, cs) [];
gear.makeObjective = @makeObjective;
gear.computeBudget = @computeBudget;
end

function ctx = prepare(order, cs, antennaConfig)
M_tx = order;
seData = gearboxphy.data.loadSECurve("ZXM", M_tx, antennaConfig, cs.dataDir, localMode(cs));
ctx.N_t = antennaConfig.N_t;
ctx.N_r = antennaConfig.N_r;
bwFactor = gearboxphy.physics.containmentBandwidthZXM(cs.alpha, 99, M_tx);
rawSE = seData.SE_vec ./ bwFactor;
[ctx.SE_vec, ctx.SNR_vec] = gearboxphy.optimize.trimCurve(rawSE, seData.SNR_vec);
ctx.M_tx = M_tx;

if max(ctx.SE_vec) > 4
    warning('gearboxphy:zxm:seOutOfRange', ...
        'ZXM SE curve for M_tx=%d exceeds 4 - check SE_data table.', M_tx);
end

ctx.B_max = cs.eta * cs.f_c;
ctx.L_dB = gearboxphy.physics.linkBudgetDb(cs, antennaConfig);
ctx.sqrt_fc = sqrt(cs.f_c);
% ZXM has a roughly-constant PAPR regardless of order (Neuhaus OJCOMS) -
% not derived from M_tx like QAM's PAPR is.
ctx.papr = 10^((3.63+3)/10);
ctx.b = 1;   % ZXM's per-symbol bit count is fixed
ctx.pow2_b = 2^ctx.b;

ctx.hw = narrowHwParams(cs);
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

% Same PA-model trigger as qamGear.m (PA_POWER_MODEL_DECISION.md):
% "constant" forces P_0=0 so P_PA stays the original scale-invariant
% formula; "affine" demands a real P_0 rather than silently using 0.
if isfield(cs,'paPowerModel') && cs.paPowerModel == "affine"
    assert(~isnan(cs.P_0), 'gearboxphy:zxm:missingP0', ...
        'scenario.paPowerModel="affine" requires scenario.P_0 - see PA_POWER_MODEL_DECISION.md.');
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
out = (1/R) * ( (gamma+hw.epsilon_trans*(1-gamma))*(core.P_PA+core.P_DAC+hw.P_LO+core.P_Mix_Tx) ...
              + (gamma+hw.epsilon_rec*(1-gamma))*(core.P_ADC+core.P_LNA+hw.P_LO+core.P_Mix_Rx) );
end

function budget = computeBudget(ctx, x, R)
core = computeCore(x, ctx, R);
hw = ctx.hw;
gamma = core.gamma;
budget.PA     = (1/R)*(gamma+hw.epsilon_trans*(1-gamma))*core.P_PA;
budget.DAC    = (1/R)*(gamma+hw.epsilon_trans*(1-gamma))*core.P_DAC;
budget.LO_Tx  = (1/R)*(gamma+hw.epsilon_trans*(1-gamma))*hw.P_LO;
budget.Mix_Tx = (1/R)*(gamma+hw.epsilon_trans*(1-gamma))*core.P_Mix_Tx;
budget.LNA    = (1/R)*(gamma+hw.epsilon_rec*(1-gamma))*core.P_LNA;
budget.LO_Rx  = (1/R)*(gamma+hw.epsilon_rec*(1-gamma))*hw.P_LO;
budget.Mix_Rx = (1/R)*(gamma+hw.epsilon_rec*(1-gamma))*core.P_Mix_Rx;
budget.ADC    = (1/R)*(gamma+hw.epsilon_rec*(1-gamma))*core.P_ADC;
end

function core = computeCore(x, ctx, R)
%COMPUTECORE Shared feasibility check + power-term computation between
%   objective() and computeBudget() (code review finding #7).
hw = ctx.hw;
M_tx = ctx.M_tx;
B = 10^x(1);
gamma = x(2);
core.gamma = gamma;
core.B = B;

if gamma<0 || gamma>1 || B>ctx.B_max || B<0
    core.feasible = false; return
end

S = R/(gamma*B);
SNR_rec = gearboxphy.optimize.snrLookup(S, ctx.SE_vec, ctx.SNR_vec);
SNR_transmitter = SNR_rec + ctx.L_dB;
P_t = 10^(SNR_transmitter/10) * hw.N_0 * B;
if P_t > hw.Maximum_P_T
    core.feasible = false; return
end

core.feasible = true;
% B is optimized here (unlike NA-QAM), so P_ADC/P_DAC still depend on it
% and stay evaluated per-call; only the M_tx multiplicity and b=1 are
% gear constants pulled from ctx.
%
% TWO INDEPENDENT MULTIPLICITIES, do not confuse them:
%   M_tx  - ZXM's FTN oversampling factor, i.e. samples per symbol. Was
%           already here and is unrelated to antennas.
%   N_t/N_r - antenna chains, identical per-chain scaling as qamGear.m
%           (ADC/LNA/Rx-mixer with N_r, DAC/Tx-mixer with N_t, LO shared).
% In multiplexing mode N_t=N_r=1, so this reduces exactly to the previous
% formula and no existing ZXM result changes.
core.P_PA = gearboxphy.physics.powerAmplifier(P_t, ctx.sqrt_fc, ctx.papr, hw.c_PA, ctx.N_t, hw.P_0);
core.P_ADC = ctx.N_r * M_tx * gearboxphy.physics.adcPower(B, ctx.pow2_b, hw.f_b, hw.c_ADC);
core.P_LNA = ctx.N_r * gearboxphy.physics.lnaPowerFor(hw.lna, B);
core.P_DAC = ctx.N_t * M_tx * gearboxphy.physics.dacPower(B, ctx.b, ctx.pow2_b, hw.DAC_VDD, hw.DAC_I0, hw.DAC_Cp);
core.P_Mix_Tx = ctx.N_t * hw.P_Mix;
core.P_Mix_Rx = ctx.N_r * hw.P_Mix;
end
