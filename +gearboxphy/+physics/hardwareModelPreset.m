function preset = hardwareModelPreset(model)
%HARDWAREMODELPRESET Component power models behind the collective switch
%   hardwareModel of makeScenarioConfig.m (docs/HARDWARE_MODEL_SWITCH.md).
%   Returns a struct whose fields are the single switches the preset sets;
%   empty for "custom", which leaves every single switch to the caller.
%     "old" - the dissertation's models, i.e. the defaults of the single
%             switches: LNA figure of merit over the signal bandwidth
%             (LNA_POWER_MODEL.md), ADC survey envelope 0.67 fJ
%             (ADC_POWER_MODEL.md), DAC with Cui's 3 V constants
%             (DAC_POWER_MODEL.md), one LO per side whatever the number of
%             mixers (loDistributionModel "shared"). Byte-identical to
%             every existing result.
%     "new" - the 5 % quantiles of the three hardware surveys: LNA
%             "envelope", ADC "quantile5" (3.17 fJ), DAC "survey"
%             (1.2 uW per LSB, 0.25 pJ per bit and sample); and an LO
%             buffer for every mixer beyond the first
%             (loDistributionModel "per_mixer": 3 / 7 / 12.5 mW at 2.4 /
%             8 / 28 GHz, +physics/loDistributionPower.m; other carriers
%             need loDistPowerPerMixer as soon as a side has two mixers).
%             A link with one mixer per side (SISO, analog beamforming)
%             is not affected by the LO part.
%   P_LO itself, PA, mixer and phase shifter have no old/new pair and are
%   not touched: paPowerModel, psType and loDistPowerPerMixer stay the
%   caller's.
switch string(model)
    case "custom"
        preset = struct();
    case "old"
        preset = struct('lnaPowerModel', "fom_bandwidth", 'adcPowerModel', "envelope", 'dacPowerModel', "analytic", ...
            'loDistributionModel', "shared");
    case "new"
        preset = struct('lnaPowerModel', "envelope", 'adcPowerModel', "quantile5", 'dacPowerModel', "survey", ...
            'loDistributionModel', "per_mixer");
    otherwise
        error('gearboxphy:hardwareModel', 'Unknown hardwareModel "%s".', string(model));
end
end
