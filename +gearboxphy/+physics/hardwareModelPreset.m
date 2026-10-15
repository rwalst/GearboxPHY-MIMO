function preset = hardwareModelPreset(model)
%HARDWAREMODELPRESET Component models behind the collective switch
%   hardwareModel of makeScenarioConfig.m (docs/HARDWARE_MODEL_SWITCH.md).
%   Returns a struct whose fields are the single switches the preset sets;
%   empty for "custom", which leaves every single switch to the caller.
%     "old" - the dissertation's models, the defaults until 2026-10-15:
%             LNA figure of merit over the signal bandwidth
%             (LNA_POWER_MODEL.md), ADC survey envelope 0.67 fJ
%             (ADC_POWER_MODEL.md), DAC with Cui's 3 V constants
%             (DAC_POWER_MODEL.md), one LO per side whatever the number of
%             mixers, B_max = eta*f_c. Reproduces every result computed
%             before 2026-10-15 (gearboxphy.sweep.oldModelArgs).
%     "new" - the models decided on 2026-10-15, which are also the
%             DEFAULTS of makeScenarioConfig: LNA "fom_floor" (bandwidth
%             floored at lnaBetaMin*f_c), ADC "quantile5" (3.17 fJ), DAC
%             "survey" (1.2 uW per LSB, 0.25 pJ per bit and sample), an LO
%             buffer for every mixer beyond the first ("per_mixer": 3 / 7 /
%             12.5 / 10 mW at 2.4 / 8 / 28 / 60 GHz), and one standard
%             channel as B_max ("channel": 20 MHz / 100 MHz / 400 MHz /
%             2.16 GHz, +physics/channelBandwidth.m).
%   P_LO itself, PA, mixer and phase shifter have no old/new pair and are
%   not touched: paPowerModel, psType and loDistPowerPerMixer stay the
%   caller's. The phase shifter deliberately has no decided model; studies
%   keep all three psType variants.
switch string(model)
    case "custom"
        preset = struct();
    case "old"
        preset = struct('lnaPowerModel', "fom_bandwidth", 'adcPowerModel', "envelope", ...
            'dacPowerModel', "analytic", 'loDistributionModel', "shared", 'bandwidthModel', "eta");
    case "new"
        preset = struct('lnaPowerModel', "fom_floor", 'adcPowerModel', "quantile5", ...
            'dacPowerModel', "survey", 'loDistributionModel', "per_mixer", 'bandwidthModel', "channel");
    otherwise
        error('gearboxphy:hardwareModel', 'Unknown hardwareModel "%s".', string(model));
end
end
