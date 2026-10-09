function abf = analogBeamformingParams(cs, antennaConfig)
%ANALOGBEAMFORMINGPARAMS Everything the analog-beamforming architecture
%   changes for one antenna configuration, bundled for the gear
%   (docs/ANALOG_BEAMFORMING.md, docs/PHASE_SHIFTER_POWER_MODEL.md).
%
%   abf = analogBeamformingParams(carrierScenario, antennaConfig)
%
%   Architecture (one stream):
%       Tx:  2 x DAC -> mixer -> split 1:N_t -> [PS -> PA] -> antenna
%       Rx:  antenna -> [LNA -> PS] -> combine N_r:1 -> mixer -> 2 x ADC
%   So ONE DAC pair, ONE ADC pair and ONE mixer per side, whatever N is,
%   and one phase shifter per element. Splitter and combiner are ideal.
%   A side with a single antenna has no phase shifter: N_t = N_r = 1 is
%   exactly the digital SISO link.
%
%   MIXED CASES: cs.beamformingArchTx / cs.beamformingArchRx set the
%   architecture per side. A digital side keeps N converter/mixer chains
%   and has no phase shifters, no loss and no quantisation loss; only the
%   analog side gets the single chain and the N phase shifters. With a
%   digital receiver "passive_compensated" and "passive_penalty" coincide
%   (their difference is on the receive side).
%
%   abf.enabled is false for cs.beamformingArch = "digital" (the default,
%   also for a hand-built scenario without the field); the gear then
%   takes its unchanged per-chain path and reads nothing else from abf.
%
%   Fields when enabled:
%     nChainsTx, nChainsRx  1, 1   converter/mixer chains per side
%     P_PS_Tx, P_PS_Rx      [W]    DC power of ALL phase shifters per side
%     kappa_Tx              factor on the PA's RF-dependent power: a
%                           driver makes up the phase-shifter loss ahead
%                           of the PA (phaseShifterPenalty.m)
%     lnaFactor             factor on the LNA power. 1, except for
%                           "passive_compensated": LNA gain is raised by
%                           L_PS, and LNA power is taken as proportional
%                           to gain (as in lnaPower.m) - an ASSUMPTION
%                           under the survey-envelope LNA model.
%     extra_L_dB            added to the link budget [dB]: receive-side
%                           noise penalty of the lossy phase shifter
%                           (Friis) plus the array-gain loss from phase
%                           quantisation on both sides
%     quantLoss_dB, deltaRx_dB   the two parts of extra_L_dB
%     psType, L_PS_dB, P_PS, b_PS
%
%   Phase-shifter types (cs.psType):
%     "active"               P_PS per element, no loss
%     "passive_penalty"      no DC power; loss as driver power (Tx) and
%                            noise-figure penalty (Rx) - optimistic bound
%     "passive_compensated"  no DC power in the shifter; Tx as above, Rx
%                            loss made up by LNA gain (lnaFactor = L_PS)
%
%   Phase quantisation with b bits: phase errors uniform on +-pi/2^b,
%   independent across elements, give a MEAN array power gain of
%       G(N,b) = 1 + (N-1)*(sin(pi/2^b)/(pi/2^b))^2      instead of N.
%   The loss N/G enters once per side with more than one element. It is
%   the loss of the mean SNR; cs.psBits = Inf switches it off.
abf.enabled = false;
% Architecture per side: cs.beamformingArchTx/Rx override cs.beamformingArch
% for that side ("" or missing = follow it). A scenario built by hand
% without any of the fields is digital on both sides.
arch = "digital";
if isfield(cs, 'beamformingArch'), arch = string(cs.beamformingArch); end
assert(any(arch == ["digital" "analog"]), 'gearboxphy:beamformingArch', ...
    'Unknown beamformingArch "%s".', arch);
archTx = arch; archRx = arch;
if isfield(cs, 'beamformingArchTx') && string(cs.beamformingArchTx) ~= "", archTx = string(cs.beamformingArchTx); end
if isfield(cs, 'beamformingArchRx') && string(cs.beamformingArchRx) ~= "", archRx = string(cs.beamformingArchRx); end
txAnalog = archTx == "analog"; rxAnalog = archRx == "analog";
if ~txAnalog && ~rxAnalog
    return
end

mode = "multiplexing";
if isfield(cs, 'antennaMode'), mode = string(cs.antennaMode); end
carry = isfield(cs, 'analogCurvesCarryArrayGain') && cs.analogCurvesCarryArrayGain;
% Analog beamforming carries ONE stream. In "multiplexing" mode the gear
% loads one SE curve per antenna configuration - fine for single-stream
% curves that already contain the array gain (SE_data_bfideal_*, SE_data_abf_*),
% wrong for genuine multi-stream curves. The gear cannot tell the two
% apart, so the scenario has to say it.
assert(mode == "beamforming" || carry, 'gearboxphy:analogNeedsSingleStream', ...
    ['beamformingArch="analog" needs antennaMode="beamforming", or ' ...
     'analogCurvesCarryArrayGain=true together with single-stream curves ' ...
     'that already contain the array gain.']);

N_t = antennaConfig.N_t; N_r = antennaConfig.N_r;
psType = string(cs.psType);
if psType == "active", baseType = "active"; else, baseType = "passive"; end
[P_def, L_def] = gearboxphy.physics.phaseShifterParams(cs.f_c, baseType);
P_PS = P_def; L_PS = L_def;
if isfield(cs, 'psPower')  && ~isnan(cs.psPower),  P_PS = cs.psPower; end
if isfield(cs, 'psLossDb') && ~isnan(cs.psLossDb), L_PS = 10^(cs.psLossDb/10); end
if psType ~= "active", P_PS = 0; end

G_PA = 100; G_LNA = 32; F_LNA = 3;
if isfield(cs, 'psGainPA'),         G_PA  = cs.psGainPA;  end
if isfield(cs, 'psGainLNA'),        G_LNA = cs.psGainLNA; end
if isfield(cs, 'psNoiseFactorLNA'), F_LNA = cs.psNoiseFactorLNA; end

abf.enabled   = true;
abf.txAnalog  = txAnalog;
abf.rxAnalog  = rxAnalog;
% a digital side keeps one converter/mixer chain per antenna
if txAnalog, abf.nChainsTx = 1; else, abf.nChainsTx = N_t; end
if rxAnalog, abf.nChainsRx = 1; else, abf.nChainsRx = N_r; end
abf.psType    = psType;
abf.P_PS      = P_PS;
abf.L_PS_dB   = 10*log10(L_PS);
abf.b_PS      = cs.psBits;

% --- transmit side (phase shifters only if this side is analog)
if N_t > 1 && txAnalog
    abf.P_PS_Tx = N_t * P_PS;
    abf.kappa_Tx = gearboxphy.physics.phaseShifterPenalty(L_PS, G_PA, G_LNA, F_LNA);
else
    abf.P_PS_Tx = 0;
    abf.kappa_Tx = 1;
end

% --- receive side
abf.lnaFactor = 1;
abf.deltaRx_dB = 0;
if N_r > 1 && rxAnalog
    abf.P_PS_Rx = N_r * P_PS;
    switch psType
        case "active"
            % no loss
        case "passive_penalty"
            [~, abf.deltaRx_dB] = gearboxphy.physics.phaseShifterPenalty(L_PS, G_PA, G_LNA, F_LNA);
        case "passive_compensated"
            abf.lnaFactor = L_PS;
            [~, abf.deltaRx_dB] = gearboxphy.physics.phaseShifterPenalty(L_PS, G_PA, G_LNA * L_PS, F_LNA);
        otherwise
            error('gearboxphy:psType', 'Unknown psType "%s".', psType);
    end
else
    abf.P_PS_Rx = 0;
end

% --- phase quantisation, both sides
% only an analog side has quantised phases; a digital side weights exactly
abf.quantLoss_dB = txAnalog * localQuantLossDb(N_t, cs.psBits) + rxAnalog * localQuantLossDb(N_r, cs.psBits);
abf.extra_L_dB = abf.deltaRx_dB + abf.quantLoss_dB;
end

function L = localQuantLossDb(N, b)
if N <= 1 || isinf(b)
    L = 0; return
end
x = pi / 2^b;
kappa = (sin(x) / x)^2;
L = -10*log10((1 + (N - 1) * kappa) / N);
end
