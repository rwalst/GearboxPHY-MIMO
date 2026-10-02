function c = lna_comparison_case(cfg, study, bw, model, distance)
%LNA_COMPARISON_CASE  Scenario, results directory and stamp for ONE case of
%   the LNA comparison (see lna_comparison_config.m).
%
%   c = lna_comparison_case(cfg, "siso", cfg.bw(2), "envelope", 50)
%
%   c.name      "<study>_<bw>_<model>_d<d>"
%   c.dir       <cfg.root>/<c.name>
%   c.scenario  makeScenarioConfig(...) for runSweep
%   c.stamp     everything that determines the results. runSweep's own
%               skip check (hasAllResults) only compares RVec, distance
%               and antenna configs - NOT the LNA model or B_max - so a
%               directory must never be reused for another case. The
%               driver writes this stamp into the directory and refuses to
%               run if an existing one differs.
arguments
    cfg (1,1) struct
    study (1,1) string {mustBeMember(study, ["siso" "beamforming"])}
    bw (1,1) struct
    model (1,1) string
    distance (1,1) double {mustBePositive}
end
c.name = sprintf('%s_%s_%s_d%g', study, bw.name, model, distance);
c.dir  = fullfile(cfg.root, c.name);

if study == "beamforming"
    configs = arrayfun(@(n) struct('N_t', n, 'N_r', n), cfg.bfN, 'UniformOutput', false);
    antennaArgs = {'antennaMode', "beamforming", 'beamformingConfigs', configs};
else
    antennaArgs = {'antennaMode', "multiplexing"};   % SISO default configs
end
c.scenario = gearboxphy.sweep.makeScenarioConfig( ...
    'distance', distance, 'RVec', cfg.RVec, 'fcVec', cfg.fcVec, ...
    'lnaPowerModel', model, 'lnaBetaMin', cfg.lnaBetaMin, ...
    'B_maxByCarrier', bw.B_maxByCarrier, antennaArgs{:});

s = c.scenario;
c.stamp = struct('study', study, 'bw', bw.name, 'B_maxByCarrier', bw.B_maxByCarrier, ...
    'lnaPowerModel', s.lnaPowerModel, 'lnaBetaMin', s.lnaBetaMin, ...
    'distance', s.distance, 'fcVec', s.fcVec, 'RVec', s.RVec, ...
    'antennaMode', s.antennaMode, 'beamformingConfigs', {s.beamformingConfigs});
end
