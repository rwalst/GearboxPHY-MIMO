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
        function defaultIsCustomAndChangesNothing(testCase)
            s = gearboxphy.sweep.makeScenarioConfig();
            testCase.verifyEqual(s.hardwareModel, "custom");
            testCase.verifyEqual(s.lnaPowerModel, "fom_bandwidth");
            testCase.verifyEqual(s.adcPowerModel, "envelope");
            testCase.verifyEqual(s.dacPowerModel, "analytic");
            testCase.verifyEqual(s.loDistributionModel, "shared");
        end

        function oldEqualsTheDefaultScenario(testCase)
            % bit for bit: only the label differs
            sOld = gearboxphy.sweep.makeScenarioConfig('hardwareModel', "old");
            sDef = gearboxphy.sweep.makeScenarioConfig();
            testCase.verifyEqual(rmfield(sOld, 'hardwareModel'), rmfield(sDef, 'hardwareModel'));
            for f_c = sDef.fcVec
                csOld = gearboxphy.sweep.resolveScenarioForCarrier(sOld, f_c);
                csDef = gearboxphy.sweep.resolveScenarioForCarrier(sDef, f_c);
                testCase.verifyEqual(rmfield(csOld, 'hardwareModel'), rmfield(csDef, 'hardwareModel'));
            end
        end

        function newSetsTheSurveyModelsAndTheLoBuffers(testCase)
            s = gearboxphy.sweep.makeScenarioConfig('hardwareModel', "new");
            testCase.verifyEqual(s.lnaPowerModel, "envelope");
            testCase.verifyEqual(s.adcPowerModel, "quantile5");
            testCase.verifyEqual(s.dacPowerModel, "survey");
            testCase.verifyEqual(s.loDistributionModel, "per_mixer");
            cs = gearboxphy.sweep.resolveScenarioForCarrier(s, 28e9);
            testCase.verifyEqual(gearboxphy.physics.loDistributionPower(cs, 1), 0);       % SISO unchanged
            testCase.verifyEqual(gearboxphy.physics.loDistributionPower(cs, 4), 3 * 12.5e-3, 'RelTol', 1e-12);
            sOld = gearboxphy.sweep.makeScenarioConfig('hardwareModel', "old");
            csOld = gearboxphy.sweep.resolveScenarioForCarrier(sOld, 28e9);
            testCase.verifyEqual(gearboxphy.physics.loDistributionPower(csOld, 4), 0);
            testCase.verifyEqual(cs.c_ADC, 3.17e-15);
            testCase.verifyEqual(cs.DAC_VDD * cs.DAC_I0 / 2, 1.2e-6, 'RelTol', 1e-12);
            testCase.verifyEqual(cs.DAC_Cp * cs.DAC_VDD^2, 0.25e-12, 'RelTol', 1e-12);
        end

        function newEqualsTheFourSingleSwitches(testCase)
            sNew = gearboxphy.sweep.makeScenarioConfig('hardwareModel', "new");
            sCus = gearboxphy.sweep.makeScenarioConfig('lnaPowerModel', "envelope", ...
                'adcPowerModel', "quantile5", 'dacPowerModel', "survey", ...
                'loDistributionModel', "per_mixer");
            testCase.verifyEqual(rmfield(sNew, 'hardwareModel'), rmfield(sCus, 'hardwareModel'));
        end

        function customKeepsAnyMix(testCase)
            s = gearboxphy.sweep.makeScenarioConfig('hardwareModel', "custom", ...
                'lnaPowerModel', "fom_floor", 'dacPowerModel', "analytic_1V");
            testCase.verifyEqual(s.lnaPowerModel, "fom_floor");
            testCase.verifyEqual(s.adcPowerModel, "envelope");
            testCase.verifyEqual(s.dacPowerModel, "analytic_1V");
        end

        function repeatingThePresetIsAllowed(testCase)
            s = gearboxphy.sweep.makeScenarioConfig('hardwareModel', "new", 'dacPowerModel', "survey");
            testCase.verifyEqual(s.dacPowerModel, "survey");
        end

        function contradictingThePresetFailsLoudly(testCase)
            mk = @(varargin) @() gearboxphy.sweep.makeScenarioConfig(varargin{:});
            testCase.verifyError(mk('hardwareModel', "new", 'dacPowerModel', "analytic_1V"), 'gearboxphy:hardwareModelConflict');
            testCase.verifyError(mk('hardwareModel', "new", 'lnaPowerModel', "fom_floor"), 'gearboxphy:hardwareModelConflict');
            testCase.verifyError(mk('hardwareModel', "old", 'adcPowerModel', "quantile5"), 'gearboxphy:hardwareModelConflict');
            testCase.verifyError(mk('hardwareModel', "old", 'dacPowerModel', "survey"), 'gearboxphy:hardwareModelConflict');
            testCase.verifyError(mk('hardwareModel', "old", 'loDistributionModel', "per_mixer"), 'gearboxphy:hardwareModelConflict');
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
        end
    end
end
