classdef StaleCheckpointTest < matlab.unittest.TestCase
    %STALECHECKPOINTTEST Checkpoints and finished results are only reused
    %   by a run with the same inputs (+data/claimCheckpoints.m, runSweep's
    %   skip check). Guards the switch of all studies to the new hardware
    %   models on 2026-10-15: a resumed run in an old results directory
    %   must not take over points computed with the old models.

    properties
        Root
    end

    methods (TestClassSetup)
        function addPaths(testCase)
            testCase.Root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            if ~any(strcmp(strsplit(path, pathsep), testCase.Root))
                addpath(testCase.Root);
                testCase.addTeardown(@() rmpath(testCase.Root));
            end
        end
    end

    methods (Test)
        function foreignCheckpointsAreDiscardedOwnAreKept(testCase)
            rd = string(tempname); mkdir(rd);
            testCase.addTeardown(@() rmdir(rd, 's'));
            key = "qam_M4_fc28GHz";
            save1 = @() gearboxphy.data.savePointCheckpoint(rd, key, 1, 1e-9, 1e8, 0.5, struct('PA', 1));
            % checkpoints of an old run without a stamp: discarded
            save1();
            testCase.verifyWarning(@() gearboxphy.data.claimCheckpoints(rd, key, "fpNEW"), ...
                'gearboxphy:data:staleCheckpoints');
            testCase.verifyFalse(gearboxphy.data.hasPointCheckpoint(rd, key, 1));
            % our own: kept
            save1();
            testCase.verifyWarningFree(@() gearboxphy.data.claimCheckpoints(rd, key, "fpNEW"));
            testCase.verifyTrue(gearboxphy.data.hasPointCheckpoint(rd, key, 1));
            % another run's stamp: discarded
            testCase.verifyWarning(@() gearboxphy.data.claimCheckpoints(rd, key, "fpOTHER"), ...
                'gearboxphy:data:staleCheckpoints');
            testCase.verifyFalse(gearboxphy.data.hasPointCheckpoint(rd, key, 1));
        end

        function modelChangeChangesTheComboFingerprint(testCase)
            % the key runSweep compares must see the hardware models
            fp = @(varargin) localFp(varargin{:});
            old = gearboxphy.sweep.oldModelArgs();
            testCase.verifyNotEqual(fp(old{:}), fp());
            testCase.verifyNotEqual(fp(old{:}), fp(old{:}, 'adcPowerModel', "quantile5"));
            testCase.verifyEqual(fp(), fp());
        end
    end
end

function f = localFp(varargin)
s = gearboxphy.sweep.makeScenarioConfig(varargin{:}, 'distance', 50, 'RVec', [1e6 1e8], ...
    'fcVec', 28e9, 'dataDir', string(fullfile(gearboxphy.paths.root(), 'data', 'SE_data')));
cs = gearboxphy.sweep.resolveScenarioForCarrier(s, 28e9);
gear = gearboxphy.gears.qamGear();
cfgs = gear.antennaConfigs(4, cs);
ctx = {gear.prepare(4, cs, cfgs{1})};
op = struct('tolerance', s.tolerance, 'maxiters', s.maxiters, 'numtriesPerOpt', s.numtriesPerOpt);
f = gearboxphy.data.comboFingerprint(gear.name, 4, 28e9, s.RVec, op, ...
    gear.initialGuess(4, cs), gear.optimizerBounds(4, cs), ctx);
end
