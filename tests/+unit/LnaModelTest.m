classdef LnaModelTest < matlab.unittest.TestCase
    %LNAMODELTEST The LNA model switch (lnaPowerFor/lnaParams), the survey
    %   envelope (lnaPowerEnvelope) and the per-carrier B_max override in
    %   resolveScenarioForCarrier. See LNA_POWER_MODEL.md.
    %
    %   Paths are resolved relative to this file (the older tests still
    %   point at the pre-rename /workspace/gearboxphy_framework).

    properties
        Root
    end

    methods (TestClassSetup)
        function addPaths(testCase)
            testCase.Root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            % only undo what this test did - never remove a path the
            % caller (startup.m, job script, validate_lna_comparison) set
            if ~any(strcmp(strsplit(path, pathsep), testCase.Root))
                addpath(testCase.Root);
                testCase.addTeardown(@() rmpath(testCase.Root));
            end
        end
    end

    methods (Test)
        function defaultIsDissertationFormulaExactly(testCase)
            % The default must call lnaPower with the unmodified B - bit
            % for bit, not just within a tolerance.
            lna = gearboxphy.physics.lnaParams(struct('f_c', 28e9, 'N_0', 1.380649e-23*295));
            testCase.verifyEqual(lna.model, "fom_bandwidth");
            for B = [1e3 1e6 2.5e7 1e9 3e9]
                testCase.verifyEqual(gearboxphy.physics.lnaPowerFor(lna, B), ...
                    gearboxphy.physics.lnaPower(B, lna.N_0));
            end
        end

        function scenarioDefaultsLeaveEverythingUnchanged(testCase)
            s = gearboxphy.sweep.makeScenarioConfig();
            testCase.verifyEqual(s.lnaPowerModel, "fom_bandwidth");
            testCase.verifyEmpty(s.B_maxByCarrier);
            cs = gearboxphy.sweep.resolveScenarioForCarrier(s, 28e9);
            testCase.verifyEqual(cs.eta, 0.1);
            testCase.verifyEqual(gearboxphy.physics.lnaParams(cs).model, "fom_bandwidth");
        end

        function floorOnlyActsBelowBetaFc(testCase)
            lna = struct('model', "fom_floor", 'f_c', 28e9, 'N_0', 1.380649e-23*295, 'beta_min', 0.05);
            Bfloor = 0.05 * 28e9;
            % above the floor: identical to the dissertation formula
            for B = [Bfloor 2*Bfloor 1e10]
                testCase.verifyEqual(gearboxphy.physics.lnaPowerFor(lna, B), ...
                    gearboxphy.physics.lnaPower(B, lna.N_0));
            end
            % below: constant at the floor value
            for B = [1e3 1e6 0.5*Bfloor]
                testCase.verifyEqual(gearboxphy.physics.lnaPowerFor(lna, B), ...
                    gearboxphy.physics.lnaPower(Bfloor, lna.N_0));
            end
        end

        function envelopeMatchesDocumentedValues(testCase)
            % LNA_POWER_MODEL.md section 5, values at the floor B = 0.05 f_c
            fc = [2.4 8 28 60] * 1e9;
            expected_mW = [0.376 0.914 2.301 4.034];   % rounded to 0.38/0.91/2.30/4.04 there
            for i = 1:numel(fc)
                P = gearboxphy.physics.lnaPowerEnvelope(fc(i), 1e3);
                testCase.verifyEqual(P*1e3, expected_mW(i), 'RelTol', 2e-3);
            end
        end

        function envelopeIsFlatBelowFloorAndSqrtLikeAbove(testCase)
            lna = struct('model', "envelope", 'f_c', 8e9, 'N_0', 1.380649e-23*295, 'beta_min', 0.05);
            Pfloor = gearboxphy.physics.lnaPowerFor(lna, 0.4e9);
            testCase.verifyEqual(gearboxphy.physics.lnaPowerFor(lna, 1e6), Pfloor);
            % doubling B above the floor scales by 2^0.457
            testCase.verifyEqual(gearboxphy.physics.lnaPowerFor(lna, 2e9) / ...
                gearboxphy.physics.lnaPowerFor(lna, 1e9), 2^0.457, 'RelTol', 1e-12);
        end

        function modelsOrderedInNarrowbandRegime(testCase)
            % For B below the floor: envelope > fom_floor > fom_bandwidth.
            % This ordering is what validate_lna_comparison checks end to end.
            for fc = [2.4 8 28] * 1e9
                base = struct('f_c', fc, 'N_0', 1.380649e-23*295, 'beta_min', 0.05);
                B = 0.01 * fc;
                P = zeros(1, 3); m = ["fom_bandwidth" "fom_floor" "envelope"];
                for k = 1:3
                    lna = base; lna.model = m(k);
                    P(k) = gearboxphy.physics.lnaPowerFor(lna, B);
                end
                testCase.verifyTrue(P(3) > P(2) && P(2) > P(1));
            end
        end

        function unknownModelErrors(testCase)
            lna = struct('model', "nope", 'f_c', 28e9, 'N_0', 1, 'beta_min', 0.05);
            testCase.verifyError(@() gearboxphy.physics.lnaPowerFor(lna, 1e6), 'gearboxphy:lnaModel');
        end

        function scenarioRejectsUnknownModel(testCase)
            % any error - the identifier of an arguments-block failure is
            % a MATLAB implementation detail
            testCase.verifyError(@() gearboxphy.sweep.makeScenarioConfig('lnaPowerModel', "nope"), ...
                ?MException);
        end

        function bMaxByCarrierSetsEta(testCase)
            tbl = [2.4e9 20e6; 8e9 100e6; 28e9 400e6];
            s = gearboxphy.sweep.makeScenarioConfig('B_maxByCarrier', tbl);
            for i = 1:size(tbl, 1)
                cs = gearboxphy.sweep.resolveScenarioForCarrier(s, tbl(i,1));
                testCase.verifyEqual(cs.eta * cs.f_c, tbl(i,2), 'RelTol', 1e-12);
            end
        end

        function bMaxByCarrierMissingRowErrors(testCase)
            s = gearboxphy.sweep.makeScenarioConfig('B_maxByCarrier', [2.4e9 20e6]);
            testCase.verifyError(@() gearboxphy.sweep.resolveScenarioForCarrier(s, 28e9), ...
                'gearboxphy:B_maxByCarrier');
        end

        function gearsPickUpModelAndBmax(testCase)
            % Needs SE_data and obw() (Signal Processing Toolbox) - the same
            % requirements as a real sweep.
            s = gearboxphy.sweep.makeScenarioConfig('lnaPowerModel', "envelope", ...
                'B_maxByCarrier', [28e9 400e6], 'fcVec', 28e9, ...
                'dataDir', string(fullfile(testCase.Root, 'data', 'SE_data')));
            cs = gearboxphy.sweep.resolveScenarioForCarrier(s, 28e9);
            ac = struct('N_t', 1, 'N_r', 1);
            q = gearboxphy.gears.qamGear();
            ctx = q.prepare(16, cs, ac);
            testCase.verifyEqual(ctx.hw.lna.model, "envelope");
            testCase.verifyEqual(ctx.B_max, 400e6, 'RelTol', 1e-12);
            n = gearboxphy.gears.naQamGear();
            ctxN = n.prepare(1024, cs, ac);
            testCase.verifyEqual(ctxN.B, 400e6, 'RelTol', 1e-12);
            testCase.verifyEqual(ctxN.P_LNA, gearboxphy.physics.lnaPowerEnvelope(28e9, 400e6), 'RelTol', 1e-12);
        end
    end
end
