classdef HardwareModelTest < matlab.unittest.TestCase
    %HARDWAREMODELTEST The collective switch hardwareModel (custom / old /
    %   new) of makeScenarioConfig and +physics/hardwareModelPreset.m.
    %   See docs/HARDWARE_MODEL_SWITCH.md.

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
        function defaultsAreTheNewPreset(testCase)
            % since 2026-10-15 the defaults ARE hardwareModel "new";
            % makeScenarioConfig's conflict check relies on that
            s = gearboxphy.sweep.makeScenarioConfig();
            testCase.verifyEqual(s.hardwareModel, "custom");
            new = gearboxphy.physics.hardwareModelPreset("new");
            for name = string(fieldnames(new))'
                testCase.verifyEqual(s.(name), new.(name), name);
            end
            sNew = gearboxphy.sweep.makeScenarioConfig('hardwareModel', "new");
            testCase.verifyEqual(rmfield(sNew, 'hardwareModel'), rmfield(s, 'hardwareModel'));
        end

        function newSetsTheDecidedModels(testCase)
            s = gearboxphy.sweep.makeScenarioConfig('hardwareModel', "new");
            testCase.verifyEqual(s.lnaPowerModel, "fom_floor");
            testCase.verifyEqual(s.adcPowerModel, "quantile5");
            testCase.verifyEqual(s.dacPowerModel, "survey");
            testCase.verifyEqual(s.loDistributionModel, "per_mixer");
            testCase.verifyEqual(s.bandwidthModel, "channel");
            cs = gearboxphy.sweep.resolveScenarioForCarrier(s, 28e9);
            testCase.verifyEqual(cs.eta * 28e9, 400e6, 'RelTol', 1e-12);
            testCase.verifyEqual(gearboxphy.physics.loDistributionPower(cs, 1), 0);       % SISO unchanged
            testCase.verifyEqual(gearboxphy.physics.loDistributionPower(cs, 4), 3 * 12.5e-3, 'RelTol', 1e-12);
            testCase.verifyEqual(cs.c_ADC, 3.17e-15);
            testCase.verifyEqual(cs.DAC_VDD * cs.DAC_I0 / 2, 1.2e-6, 'RelTol', 1e-12);
            testCase.verifyEqual(cs.DAC_Cp * cs.DAC_VDD^2, 0.25e-12, 'RelTol', 1e-12);
        end

        function oldReproducesTheDissertationModels(testCase)
            sOld = gearboxphy.sweep.makeScenarioConfig('hardwareModel', "old");
            testCase.verifyEqual(sOld.lnaPowerModel, "fom_bandwidth");
            testCase.verifyEqual(sOld.adcPowerModel, "envelope");
            testCase.verifyEqual(sOld.dacPowerModel, "analytic");
            testCase.verifyEqual(sOld.loDistributionModel, "shared");
            testCase.verifyEqual(sOld.bandwidthModel, "eta");
            for f_c = sOld.fcVec
                cs = gearboxphy.sweep.resolveScenarioForCarrier(sOld, f_c);
                testCase.verifyEqual(cs.c_ADC, 0.67e-15);
                testCase.verifyEqual([cs.DAC_VDD cs.DAC_I0 cs.DAC_Cp], [3 10e-6 0.5e-12]);
                testCase.verifyEqual(cs.eta, 0.1);
                testCase.verifyEqual(gearboxphy.physics.loDistributionPower(cs, 8), 0);
            end
        end

        function oldModelArgsEqualsThePresetOld(testCase)
            % what every pinned study passes is exactly hardwareModel "old"
            old = gearboxphy.sweep.oldModelArgs();
            sArgs = gearboxphy.sweep.makeScenarioConfig(old{:});
            sOld = gearboxphy.sweep.makeScenarioConfig('hardwareModel', "old");
            testCase.verifyEqual(rmfield(sArgs, 'hardwareModel'), rmfield(sOld, 'hardwareModel'));
            % and a study's own switch still wins (the later name counts)
            s = gearboxphy.sweep.makeScenarioConfig(old{:}, 'lnaPowerModel', "envelope");
            testCase.verifyEqual(s.lnaPowerModel, "envelope");
            testCase.verifyEqual(s.adcPowerModel, "envelope");
        end

        function customKeepsAnyMix(testCase)
            s = gearboxphy.sweep.makeScenarioConfig('hardwareModel', "custom", ...
                'lnaPowerModel', "envelope", 'dacPowerModel', "analytic_1V", 'loDistributionModel', "shared");
            testCase.verifyEqual(s.lnaPowerModel, "envelope");
            testCase.verifyEqual(s.adcPowerModel, "quantile5");
            testCase.verifyEqual(s.dacPowerModel, "analytic_1V");
            testCase.verifyEqual(s.loDistributionModel, "shared");
        end

        function repeatingThePresetIsAllowed(testCase)
            s = gearboxphy.sweep.makeScenarioConfig('hardwareModel', "old", 'dacPowerModel', "analytic");
            testCase.verifyEqual(s.dacPowerModel, "analytic");
        end

        function contradictingThePresetFailsLoudly(testCase)
            mk = @(varargin) @() gearboxphy.sweep.makeScenarioConfig(varargin{:});
            testCase.verifyError(mk('hardwareModel', "new", 'dacPowerModel', "analytic_1V"), 'gearboxphy:hardwareModelConflict');
            testCase.verifyError(mk('hardwareModel', "new", 'lnaPowerModel', "envelope"), 'gearboxphy:hardwareModelConflict');
            testCase.verifyError(mk('hardwareModel', "new", 'bandwidthModel', "eta"), 'gearboxphy:hardwareModelConflict');
            testCase.verifyError(mk('hardwareModel', "old", 'lnaPowerModel', "envelope"), 'gearboxphy:hardwareModelConflict');
            testCase.verifyError(mk('hardwareModel', "old", 'dacPowerModel', "analytic_1V"), 'gearboxphy:hardwareModelConflict');
        end

        function otherSwitchesAreNotTouched(testCase)
            s = gearboxphy.sweep.makeScenarioConfig('hardwareModel', "new", ...
                'loDistPowerPerMixer', 17e-3, 'psType', "passive_compensated");
            testCase.verifyEqual(s.loDistPowerPerMixer, 17e-3);
            testCase.verifyEqual(s.psType, "passive_compensated");
            testCase.verifyEqual(s.paPowerModel, "constant");
        end

        function unknownModelFailsLoudly(testCase)
            testCase.verifyError(@() gearboxphy.physics.hardwareModelPreset("typo"), 'gearboxphy:hardwareModel');
            testCase.verifyError(@() gearboxphy.sweep.makeScenarioConfig('hardwareModel', "typo"), ?MException);
            testCase.verifyError(@() gearboxphy.sweep.makeScenarioConfig('bandwidthModel', "typo"), ?MException);
        end
    end
end
