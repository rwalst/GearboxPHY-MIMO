function c = hw_comparison_case(cfg, variant, distance)
%HW_COMPARISON_CASE  Scenario, results directory and stamp for ONE case of
%   the hardware-model comparison (see hw_comparison_config.m).
%
%   c = hw_comparison_case(cfg, "new", 50)
%
%   c.name      "siso_<variant>_d<d>"
%   c.dir       <cfg.root>/<c.name>
%   c.label     legend text of the variant
%   c.scenario  makeScenarioConfig(...) for runSweep (SISO, default configs)
%   c.stamp     everything that determines the results. runSweep's own
%               skip check (hasAllResults) only compares RVec, distance
%               and antenna configs - NOT the hardware models - so a
%               directory must never be reused for another case. The
%               driver writes this stamp into the directory and refuses to
%               run if an existing one differs.
arguments
    cfg (1,1) struct
    variant (1,1) string
    distance (1,1) double {mustBePositive}
end
k = find([cfg.variants.name] == variant);
assert(isscalar(k), 'hw:unknownVariant', 'Unknown variant "%s" (known: %s).', ...
    variant, strjoin([cfg.variants.name], ', '));
v = cfg.variants(k);
c.name  = sprintf('siso_%s_d%g', variant, distance);
c.dir   = fullfile(cfg.root, c.name);
c.label = v.label;
c.scenario = gearboxphy.sweep.makeScenarioConfig( ...
    'distance', distance, 'RVec', cfg.RVec, 'fcVec', cfg.fcVec, ...
    'antennaMode', "multiplexing", v.args{:});

s = c.scenario;
c.stamp = struct('variant', variant, 'hardwareModel', s.hardwareModel, ...
    'lnaPowerModel', s.lnaPowerModel, 'lnaBetaMin', s.lnaBetaMin, ...
    'adcPowerModel', s.adcPowerModel, 'dacPowerModel', s.dacPowerModel, ...
    'paPowerModel', s.paPowerModel, 'loDistributionModel', s.loDistributionModel, ...
    'distance', s.distance, 'fcVec', s.fcVec, 'RVec', s.RVec, ...
    'antennaMode', s.antennaMode, 'qamMimoConfigs', {s.qamMimoConfigs});
end
