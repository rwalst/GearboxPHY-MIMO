function cfg = hw_comparison_config()
%HW_COMPARISON_CONFIG  Single source of truth for the comparison of the old
%   and the new component power models in the SISO gearbox
%   (docs/HARDWARE_MODEL_SWITCH.md). Read by run_hw_comparison and
%   analyze_hw_comparison, so the two can never disagree about a directory
%   name or a parameter.
%
%   A CASE is one runSweep call:  variant x distance
%   and writes to  results/hardware_models_newhw/siso_<variant>_d<d>/.
%
%   Variants (makeScenarioConfig arguments)
%     "old"       hardwareModel = "old":  LNA fom_bandwidth, ADC envelope,
%                 DAC analytic (3 V), shared LO, B_max = 0.1*f_c - the
%                 dissertation's models
%     "new"       hardwareModel = "new" (the defaults since 2026-10-15):
%                 LNA fom_floor, ADC quantile5, DAC survey, LO buffer per
%                 additional mixer, B_max 20 / 100 / 400 MHz
%     "lna_only" / "adc_only" / "dac_only" / "bw_only"
%                 the old set with ONE switch taken from the new set -
%                 shows which decision moves the result. Not run by
%                 default (run_hw_comparison, VARIANTS).
%   PA, mixer and P_LO are the same in every variant. "new" also charges an
%   LO buffer per additional mixer, but SISO has one mixer per side, so
%   that part is zero here.

% Own root since 2026-10-15: results/hardware_models/ holds a run with the
% earlier "new" (LNA envelope, B_max 0.1*f_c); its stamps do not match the
% decided set and are kept as reference, never mixed.
cfg.root      = gearboxphy.paths.resultsDir('hardware_models_newhw');
cfg.fcVec     = [2.4 8 28] * 1e9;
cfg.RVec      = logspace(3, 11, 100);
cfg.distances = 50;                      % [m], the dissertation setting
cfg.reference = "old";                   % ratios are taken against this variant

% Single-model variants: the old set with exactly ONE switch taken from the
% new set (oldModelArgs first, the later name wins in makeScenarioConfig).
old = gearboxphy.sweep.oldModelArgs();
new = gearboxphy.physics.hardwareModelPreset("new");
cfg.variants = struct( ...
    'name',  {"old", "new", "lna_only", "adc_only", "dac_only", "bw_only"}, ...
    'label', {"old models", "new models", "new LNA only", "new ADC only", "new DAC only", "new B_{max} only"}, ...
    'args',  {{'hardwareModel', "old"}, ...
              {'hardwareModel', "new"}, ...
              [old, {'lnaPowerModel', new.lnaPowerModel}], ...
              [old, {'adcPowerModel', new.adcPowerModel}], ...
              [old, {'dacPowerModel', new.dacPowerModel}], ...
              [old, {'bandwidthModel', new.bandwidthModel}]});
end
