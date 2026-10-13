function cfg = hw_comparison_config()
%HW_COMPARISON_CONFIG  Single source of truth for the comparison of the old
%   and the new component power models in the SISO gearbox
%   (docs/HARDWARE_MODEL_SWITCH.md). Read by run_hw_comparison and
%   analyze_hw_comparison, so the two can never disagree about a directory
%   name or a parameter.
%
%   A CASE is one runSweep call:  variant x distance
%   and writes to  results/hardware_models/siso_<variant>_d<d>/.
%
%   Variants (makeScenarioConfig arguments)
%     "old"       hardwareModel = "old":  LNA fom_bandwidth, ADC envelope,
%                 DAC analytic (3 V) - the dissertation's models
%     "new"       hardwareModel = "new":  LNA envelope, ADC quantile5,
%                 DAC survey
%     "lna_only" / "adc_only" / "dac_only"
%                 hardwareModel = "custom" with ONE model switched to its
%                 new variant - shows which model moves the result. Not
%                 run by default (run_hw_comparison, VARIANTS).
%   PA, mixer and LO are the same in every variant; SISO has one mixer per
%   side, so the LO distribution does not enter.

cfg.root      = gearboxphy.paths.resultsDir('hardware_models');
cfg.fcVec     = [2.4 8 28] * 1e9;
cfg.RVec      = logspace(3, 11, 100);
cfg.distances = 50;                      % [m], the dissertation setting
cfg.reference = "old";                   % ratios are taken against this variant

cfg.variants = struct( ...
    'name',  {"old", "new", "lna_only", "adc_only", "dac_only"}, ...
    'label', {"old models", "new models", "new LNA only", "new ADC only", "new DAC only"}, ...
    'args',  {{'hardwareModel', "old"}, ...
              {'hardwareModel', "new"}, ...
              {'hardwareModel', "custom", 'lnaPowerModel', "envelope"}, ...
              {'hardwareModel', "custom", 'adcPowerModel', "quantile5"}, ...
              {'hardwareModel', "custom", 'dacPowerModel', "survey"}});
end
