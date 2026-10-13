function preset = hardwareModelPreset(model)
%HARDWAREMODELPRESET Component power models behind the collective switch
%   hardwareModel of makeScenarioConfig.m (docs/HARDWARE_MODEL_SWITCH.md).
%   Returns a struct whose fields are the single switches the preset sets;
%   empty for "custom", which leaves every single switch to the caller.
%     "old" - the dissertation's models, i.e. the defaults of the single
%             switches: LNA figure of merit over the signal bandwidth
%             (LNA_POWER_MODEL.md), ADC survey envelope 0.67 fJ
%             (ADC_POWER_MODEL.md), DAC with Cui's 3 V constants
%             (DAC_POWER_MODEL.md). Byte-identical to every existing result.
%     "new" - the 5 % quantiles of the three hardware surveys: LNA
%             "envelope", ADC "quantile5" (3.17 fJ), DAC "survey"
%             (1.2 uW per LSB, 0.25 pJ per bit and sample).
%   PA, mixer, LO and phase shifter have no old/new pair and are not
%   touched: paPowerModel, loDistributionModel and psType stay the caller's.
switch string(model)
    case "custom"
        preset = struct();
    case "old"
        preset = struct('lnaPowerModel', "fom_bandwidth", 'adcPowerModel', "envelope", 'dacPowerModel', "analytic");
    case "new"
        preset = struct('lnaPowerModel', "envelope", 'adcPowerModel', "quantile5", 'dacPowerModel', "survey");
    otherwise
        error('gearboxphy:hardwareModel', 'Unknown hardwareModel "%s".', string(model));
end
end
