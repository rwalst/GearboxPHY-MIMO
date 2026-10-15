function fp = gridFingerprint(shapeTag, scenarioForDistance, CFG)
%GRIDFINGERPRINT  The key of ONE distance-study result file.
%
%   fp = gearboxphy.data.gridFingerprint(shapeTag, @(d) localScenario(d, ...), CFG)
%
%   A distance study writes one .mat holding 4-D arrays over
%   (distance x rate x M x N). The whole file is therefore one unit, and its
%   key has to cover every cell. This walks the same grid the study walks
%   and hashes the ctx of each cell - the complete input of that cell's
%   optimisation, exactly as in +data/comboFingerprint.m.
%
%   shapeTag CARRIES THE VARIABLE SET, and that is not pedantry. Measured on
%   this repo: abf_distance_abf_active_envelope.mat and
%   abfdac_distance_abf_active_analytic.mat are the SAME computation (E
%   agrees to 1.4e-3, which is the unseeded optimiser's own spread), but
%   they store different variables - the first has Eadc, Eps, adcModel, the
%   second Edac, dacLevels, dacModel. Serving one for the other would hand
%   an analysis a file without the fields it reads. So two files may only be
%   exchanged when BOTH the computation and the recorded shape agree, and
%   the shape goes into the key as a plain string. Change what a study
%   saves, change its tag.
%
%   COST: one gear.prepare per cell of the (distance, M, N) grid - 500 for
%   the usual 25 x 4 x 5 - with the curves coming from the cached loader.
%   Seconds, against hours for the run it may replace.
%
%   scenarioForDistance is a function handle so each study keeps its own
%   scenario builder (localScenario, bf_arch_scenario, makeScenarioConfig)
%   and there is still ONE hashing implementation.
arguments
    shapeTag (1,1) string
    scenarioForDistance (1,1) function_handle
    CFG (1,1) struct
end

fc = CFG.fcGHz * 1e9;
gear = gearboxphy.gears.qamGear();
parts = {"gearboxphy/grid/v1", shapeTag, CFG.distances, CFG.rates, CFG.Ms, CFG.Ns, fc};

for d = CFG.distances
    scen = scenarioForDistance(d);
    cs = gearboxphy.sweep.resolveScenarioForCarrier(scen, fc);
    parts{end+1} = struct('tolerance', scen.tolerance, 'maxiters', scen.maxiters, ...
                          'numtriesPerOpt', scen.numtriesPerOpt);   %#ok<AGROW>
    for M = CFG.Ms
        cfgs = gear.antennaConfigs(M, cs);
        parts{end+1} = gear.initialGuess(M, cs);        %#ok<AGROW>
        parts{end+1} = gear.optimizerBounds(M, cs);     %#ok<AGROW>
        for c = 1:numel(cfgs)
            % N_t comes along separately: a cell that the study SKIPS
            % (because N_t is not in CFG.Ns) must not silently change the
            % key of a grid where it is present.
            parts{end+1} = cfgs{c}.N_t;                        %#ok<AGROW>
            parts{end+1} = gear.prepare(M, cs, cfgs{c});       %#ok<AGROW>
        end
    end
end

fp = gearboxphy.data.fingerprint(parts{:});
end
