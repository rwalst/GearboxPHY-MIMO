classdef AdcModelTest < matlab.unittest.TestCase
    %ADCMODELTEST The ADC model switch (adcPowerModel -> adcConstant ->
    %   cs.c_ADC in resolveScenarioForCarrier). See docs/ADC_POWER_MODEL.md.

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
        function defaultIsQuantile5(testCase)
            % default since 2026-10-15; the old models keep 0.67 fJ bit for bit
            s = gearboxphy.sweep.makeScenarioConfig();
            testCase.verifyEqual(s.adcPowerModel, "quantile5");
            old = gearboxphy.sweep.oldModelArgs();
            sOld = gearboxphy.sweep.makeScenarioConfig(old{:});
            for f_c = s.fcVec
                testCase.verifyEqual(gearboxphy.sweep.resolveScenarioForCarrier(s, f_c).c_ADC, 3.17e-15);
                testCase.verifyEqual(gearboxphy.sweep.resolveScenarioForCarrier(sOld, f_c).c_ADC, 0.67e-15);
            end
        end

        function envelopeKeepsAHandSetConstant(testCase)
            s = gearboxphy.sweep.makeScenarioConfig('adcPowerModel', "envelope", 'c_ADC', 1.5e-15);
            cs = gearboxphy.sweep.resolveScenarioForCarrier(s, 28e9);
            testCase.verifyEqual(cs.c_ADC, 1.5e-15);
        end

        function quantileReplacesConstant(testCase)
            s = gearboxphy.sweep.makeScenarioConfig('adcPowerModel', "quantile5");
            cs = gearboxphy.sweep.resolveScenarioForCarrier(s, 28e9);
            testCase.verifyEqual(cs.c_ADC, 3.17e-15);
            testCase.verifyEqual(cs.f_b, s.f_b);
        end

        function quantileScalesAdcPowerByTheSameFactorEverywhere(testCase)
            e = gearboxphy.physics.adcConstant("envelope", 0.67e-15);
            q = gearboxphy.physics.adcConstant("quantile5", 0.67e-15);
            for B = [1e4 1e7 4e8 3e9]
                for b = [1 5 8]
                    r = gearboxphy.physics.adcPower(B, 2^b, 560e6, q) / gearboxphy.physics.adcPower(B, 2^b, 560e6, e);
                    testCase.verifyEqual(r, 3.17/0.67, 'RelTol', 1e-12);
                end
            end
        end

        function scenarioWithoutFieldIsUntouched(testCase)
            % hand-built scenarios (golden master, older tests) have no adcPowerModel
            s = rmfield(gearboxphy.sweep.makeScenarioConfig(), 'adcPowerModel');
            cs = gearboxphy.sweep.resolveScenarioForCarrier(s, 8e9);
            testCase.verifyEqual(cs.c_ADC, 0.67e-15);
        end

        function unknownModelFailsLoudly(testCase)
            testCase.verifyError(@() gearboxphy.physics.adcConstant("typo", 0.67e-15), 'gearboxphy:adcPowerModel');
            testCase.verifyError(@() gearboxphy.sweep.makeScenarioConfig('adcPowerModel', "typo"), ?MException);
        end
    end
end
