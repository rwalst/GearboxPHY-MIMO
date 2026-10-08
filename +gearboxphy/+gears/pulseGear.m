function gear = pulseGear(pulseType)
%PULSEGEAR Pulse/impulse-radio gear. pulseType is "Energy" or
%   "Arbitrary" - construct one of each and register both (see
%   gearRegistry.m). Order is kept fixed at 1 (M_tx is never varied for
%   Pulse schemes in the dissertation data) per decision
%   (ARCHITECTURE_PLAN.md section 6, item 6). Ported from
%   get_min_E_bit_Pulse.m + e_bit_fct_Pulse.m.
arguments
    pulseType (1,1) string {mustBeMember(pulseType,["Energy","Arbitrary"])}
end
gear.name = "Pulse-" + pulseType;
gear.orders = 1;
% In MULTIPLEXING mode this gear stays SISO - there is no MIMO SE curve
% for it (MIMO_EXTENSION.md decision 2). In BEAMFORMING mode the array
% buys path-loss gain on the unchanged SISO curve, so every gear can take
% the scenario's candidate list; denying it to the pulse gears would
% exclude exactly the low-rate regime from the comparison.
gear.antennaConfigs = @(order, cs) localAntennaConfigs(cs);
gear.prepare = @(order, cs, antennaConfig) prepare(pulseType, cs, antennaConfig);
gear.initialGuess = @(order, cs) [log10(0.99*cs.eta*cs.f_c), 1];
gear.optimizerBounds = @(order, cs) [];
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

function ctx = prepare(pulseType, cs, antennaConfig)
gearboxphy.physics.assertDigitalArch(cs, antennaConfig, pulseType);
seData = gearboxphy.data.loadSECurve("Pulse-" + pulseType, 1, antennaConfig, cs.dataDir, localMode(cs));
ctx.N_t = antennaConfig.N_t;
ctx.N_r = antennaConfig.N_r;
[ctx.SE_vec, ctx.SNR_vec] = gearboxphy.optimize.trimCurve(seData.SE_vec, seData.SNR_vec);

if max(ctx.SE_vec) > 2
    warning('gearboxphy:pulse:seOutOfRange', ...
        'Pulse-%s SE curve exceeds 2 - check SE_data table.', pulseType);
end

if pulseType == "Energy"
    ctx.b = 1;
else
    ctx.b = 1.59;
end
ctx.pow2_b = 2^ctx.b;
ctx.pulseType = pulseType;
ctx.B_max = cs.eta * cs.f_c;
ctx.sqrt_fc = sqrt(cs.f_c);
% Einzige Stelle, an der die Antennenzahl ins Linkbudget eingeht; in
% "multiplexing" liefert linkBudgetDb exakt den bisherigen Pfadverlust.
ctx.L_dB = gearboxphy.physics.linkBudgetDb(cs, antennaConfig);
% PAPR comes from the dk-coded lookup table, not a closed-form formula.
paprDb = gearboxphy.data.loadPulsePAPR(pulseType, 1, cs.pulseFilter, cs.dataDir);
ctx.papr = 10^(paprDb/10);

ctx.hw = narrowHwParams(cs);
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
hw.P_ED = cs.P_ED;

% PA-Modellschalter wie in qamGear.m (PA_POWER_MODEL_DECISION.md):
% "constant" erzwingt P_0=0, "affine" verlangt ein echtes P_0.
if cs.paPowerModel == "affine"
    assert(~isnan(cs.P_0), 'gearboxphy:pulse:missingP0', ...
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
if ctx.pulseType == "Energy"
    out = (1/R) * ( (gamma+hw.epsilon_trans*(1-gamma))*(core.P_PA+core.P_DAC+core.P_LO) ...
                   + (gamma+hw.epsilon_rec*(1-gamma))*(core.P_ADC+core.P_LNA+core.P_ED) );
else % "Arbitrary"
    out = (1/R) * ( (gamma+hw.epsilon_trans*(1-gamma))*(core.P_PA+core.P_DAC+core.P_LO) ...
                   + (gamma+hw.epsilon_rec*(1-gamma))*(core.P_ADC+core.P_LNA+core.P_LO+core.P_Mix_Rx) );
end
end

function budget = computeBudget(ctx, x, R)
core = computeCore(x, ctx, R);
hw = ctx.hw;
gamma = core.gamma;
budget.PA = (1/R)*(gamma+hw.epsilon_trans*(1-gamma))*core.P_PA;
budget.DAC = (1/R)*(gamma+hw.epsilon_trans*(1-gamma))*core.P_DAC;
budget.LO_Tx = (1/R)*(gamma+hw.epsilon_trans*(1-gamma))*core.P_LO;
budget.Mix_Tx = 0;
budget.LNA = (1/R)*(gamma+hw.epsilon_rec*(1-gamma))*core.P_LNA;
if ctx.pulseType == "Energy"
    budget.EnergyDetector = (1/R)*(gamma+hw.epsilon_rec*(1-gamma))*core.P_ED;
else
    budget.LO_Rx = (1/R)*(gamma+hw.epsilon_rec*(1-gamma))*core.P_LO;
    budget.Mix_Rx = (1/R)*(gamma+hw.epsilon_rec*(1-gamma))*core.P_Mix_Rx;
end
budget.ADC = (1/R)*(gamma+hw.epsilon_rec*(1-gamma))*core.P_ADC;
end

function core = computeCore(x, ctx, R)
%COMPUTECORE Shared feasibility check + power-term computation between
%   objective() and computeBudget() (code review finding #7). The
%   Energy/Arbitrary branch stays in objective()/computeBudget() (the
%   final combination differs), but the power terms themselves - common
%   to both pulse types - are computed exactly once here.
hw = ctx.hw;
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
% Skalierung je Kette wie in qamGear.m/zxmGear.m: DAC mit N_t, ADC/LNA
% und der Empfangsmischer mit N_r, der Energiedetektor ebenfalls mit N_r
% (er sitzt je Empfangskette). Der LO bleibt EINMAL gezaehlt - ein
% gemeinsamer Verteilbaum, unabhaengig von der Antennenzahl.
core.P_PA = gearboxphy.physics.powerAmplifier(P_t, ctx.sqrt_fc, ctx.papr, hw.c_PA, ctx.N_t, hw.P_0);
core.P_ADC = ctx.N_r * gearboxphy.physics.adcPower(B, ctx.pow2_b, hw.f_b, hw.c_ADC);
core.P_LNA = ctx.N_r * gearboxphy.physics.lnaPowerFor(hw.lna, B);
core.P_DAC = ctx.N_t * gearboxphy.physics.dacPower(B, ctx.b, ctx.pow2_b, hw.DAC_VDD, hw.DAC_I0, hw.DAC_Cp);
core.P_ED = ctx.N_r * hw.P_ED;
core.P_Mix_Rx = ctx.N_r * hw.P_Mix;
% "Single-ended" LO heuristic (x0.7) - flagged as an explicit
% approximation in the original code, kept as-is per decision
% (ARCHITECTURE_PLAN.md section 6, item 3): unverified TODO, not
% silently re-derived or dropped.
core.P_LO = hw.P_LO * 0.7;   % TODO(unverified): single-ended LO approximation
end
