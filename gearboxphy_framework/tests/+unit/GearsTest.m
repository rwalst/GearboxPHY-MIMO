classdef GearsTest < matlab.unittest.TestCase
    %GEARSTEST Unit tests for the gear registry/struct-of-handles design,
    %   the boundary/infeasibility behavior of each gear's objective
    %   (gamma outside [0,1], B>B_max), and the MIMO antenna-config
    %   plumbing (MIMO_EXTENSION.md).

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath("/workspace/gearboxphy_framework");
            addpath("/workspace/gearboxphy_framework/tests/+goldenmaster/shim"); % obw() stub
            testCase.addTeardown(@() rmpath("/workspace/gearboxphy_framework"));
            testCase.addTeardown(@() rmpath("/workspace/gearboxphy_framework/tests/+goldenmaster/shim"));
        end
    end

    methods (Test)
        function registryGearsAllValidate(testCase)
            gears = gearboxphy.gears.gearRegistry();
            testCase.verifyGreaterThan(numel(gears), 0);
            for i = 1:numel(gears)
                testCase.verifyWarningFree(@() gearboxphy.gears.validateGear(gears{i}));
            end
        end

        function registryHasExpectedGears(testCase)
            gears = gearboxphy.gears.gearRegistry();
            names = cellfun(@(g) g.name, gears);
            testCase.verifyTrue(any(names == "QAM"));
            testCase.verifyTrue(any(names == "NA-QAM"));
            testCase.verifyTrue(any(names == "ZXM"));
            testCase.verifyTrue(any(names == "Pulse-Energy"));
            testCase.verifyTrue(any(names == "Pulse-Arbitrary"));
        end

        function validateGearRejectsMissingField(testCase)
            badGear.name = "Broken";
            badGear.orders = 1;
            % missing prepare/initialGuess/optimizerBounds/makeObjective/
            % computeBudget/antennaConfigs
            testCase.verifyError(@() gearboxphy.gears.validateGear(badGear), ...
                'gearboxphy:invalidGear');
        end

        function nonQamGearsAreSisoOnly(testCase)
            % MIMO_EXTENSION.md decision 2: only QAM has a MIMO variant.
            gears = gearboxphy.gears.gearRegistry();
            cs = testScenario(28e9);
            for i = 1:numel(gears)
                gear = gears{i};
                if gear.name == "QAM"
                    continue
                end
                configs = gear.antennaConfigs(gear.orders(1), cs);
                testCase.verifyEqual(numel(configs), 1);
                testCase.verifyEqual(configs{1}.N_t, 1);
                testCase.verifyEqual(configs{1}.N_r, 1);
            end
        end

        function nonQamGearRejectsMimoAntennaConfig(testCase)
            cs = testScenario(28e9);
            mimoConfig = struct('N_t', 2, 'N_r', 2);
            testCase.verifyError(@() gearboxphy.data.loadSECurve("ZXM", 1, mimoConfig, cs.dataDir), ...
                'gearboxphy:mimoNotSupported');
        end

        function qamInfeasibleGammaReturnsInf(testCase)
            gear = gearboxphy.gears.qamGear();
            cs = testScenario(28e9);
            ctx = gear.prepare(16, cs, siso());
            fun = gear.makeObjective(ctx, 1e7);
            testCase.verifyEqual(fun([log10(1e7), -0.1]), inf);   % gamma<0
            testCase.verifyEqual(fun([log10(1e7), 1.1]), inf);    % gamma>1
        end

        function qamInfeasibleBandwidthReturnsInf(testCase)
            gear = gearboxphy.gears.qamGear();
            cs = testScenario(28e9);
            ctx = gear.prepare(16, cs, siso());
            fun = gear.makeObjective(ctx, 1e7);
            tooWide = log10(ctx.B_max * 10);
            testCase.verifyEqual(fun([tooWide, 0.5]), inf);
        end

        function naQamInfeasibleGammaReturnsInf(testCase)
            gear = gearboxphy.gears.naQamGear();
            cs = testScenario(28e9);
            ctx = gear.prepare(1024, cs, siso());
            fun = gear.makeObjective(ctx, 1e7);
            testCase.verifyEqual(fun(-0.1), inf);
            testCase.verifyEqual(fun(1.1), inf);
        end

        function qamAntennaConfigsSkipsMissingMimoCurveWithWarning(testCase)
            % QAM order=4 has no SE_4_QAM_2x2.mat file - a globally
            % configured 2x2 candidate should be dropped for THIS order
            % (with a warning), while SISO always remains, and order=16
            % (which DOES have a matching curve, generated for testing)
            % keeps both candidates.
            cs = testScenario(28e9);
            cs.qamMimoConfigs = {struct('N_t',1,'N_r',1), struct('N_t',2,'N_r',2)};
            gear = gearboxphy.gears.qamGear();

            testCase.verifyWarning(@() gearboxphy.data.filterAvailableAntennaConfigs( ...
                "QAM", 4, cs.qamMimoConfigs, cs.dataDir), 'gearboxphy:mimoCurveMissing');
            configs4 = gear.antennaConfigs(4, cs);
            testCase.verifyEqual(numel(configs4), 1);
            testCase.verifyEqual(configs4{1}.N_t, 1);

            if isfile(fullfile(cs.dataDir, "SE_16_QAM_2x2.mat"))
                configs16 = gear.antennaConfigs(16, cs);
                testCase.verifyEqual(numel(configs16), 2);
            end
        end

        function qamConstantModelForcesZeroP0RegardlessOfSetting(testCase)
            % Even if scenario.P_0 is left at some stale non-NaN value,
            % paPowerModel="constant" (the default) must force hw.P_0=0 -
            % "constant" can never be silently undermined by a leftover
            % P_0 (PA_POWER_MODEL_DECISION.md Model A).
            base = gearboxphy.sweep.makeScenarioConfig( ...
                'dataDir', "/workspace/gearboxphy_framework/SE_data", ...
                'paPowerModel', "constant", 'P_0', 5);   % P_0 set but should be ignored
            cs = gearboxphy.sweep.resolveScenarioForCarrier(base, 28e9);
            gear = gearboxphy.gears.qamGear();
            ctx = gear.prepare(16, cs, siso());
            testCase.verifyEqual(ctx.hw.P_0, 0);
        end

        function qamAffineModelWithoutP0Errors(testCase)
            base = gearboxphy.sweep.makeScenarioConfig( ...
                'dataDir', "/workspace/gearboxphy_framework/SE_data", ...
                'paPowerModel', "affine");   % P_0 left at its NaN default
            cs = gearboxphy.sweep.resolveScenarioForCarrier(base, 28e9);
            gear = gearboxphy.gears.qamGear();
            testCase.verifyError(@() gear.prepare(16, cs, siso()), 'gearboxphy:qam:missingP0');
        end

        function qamAffineModelAddsNtTimesP0ToBudget(testCase)
            % Isolate the N_t*P_0 effect by overriding ctx.N_t on ONE
            % already-prepared context (same SE curve, same everything
            % else) rather than comparing SISO vs. a different MIMO
            % curve - which would also change the required SNR/P_t and
            % confound the comparison.
            base = gearboxphy.sweep.makeScenarioConfig( ...
                'dataDir', "/workspace/gearboxphy_framework/SE_data", ...
                'paPowerModel', "affine", 'P_0', 1e-3);
            cs = gearboxphy.sweep.resolveScenarioForCarrier(base, 28e9);
            gear = gearboxphy.gears.qamGear();
            ctx = gear.prepare(16, cs, siso());
            testCase.verifyEqual(ctx.hw.P_0, 1e-3);

            x = [log10(0.99*cs.eta*cs.f_c), 0.5];
            budgetNt1 = gear.computeBudget(ctx, x, 1e9);
            ctxNt3 = ctx; ctxNt3.N_t = 3;
            budgetNt3 = gear.computeBudget(ctxNt3, x, 1e9);

            gamma = x(2);
            expectedExtra = (1/1e9)*(gamma + cs.epsilon_trans*(1-gamma)) * (3-1) * cs.P_0;
            testCase.verifyEqual(budgetNt3.PA - budgetNt1.PA, expectedExtra, 'RelTol', 1e-9);
        end

        function qamSisoContextCarriesUnitAntennaCounts(testCase)
            % Every gear's ctx.N_t/ctx.N_r should be 1 for a SISO config,
            % so the MIMO power scaling (ctx.N_t * ..., ctx.N_r * ...)
            % reduces to exactly the original SISO formulas.
            gear = gearboxphy.gears.qamGear();
            cs = testScenario(28e9);
            ctx = gear.prepare(16, cs, siso());
            testCase.verifyEqual(ctx.N_t, 1);
            testCase.verifyEqual(ctx.N_r, 1);
        end
    end
end

function cs = testScenario(f_c)
base = gearboxphy.sweep.makeScenarioConfig( ...
    'dataDir', "/workspace/gearboxphy_framework/SE_data");
cs = gearboxphy.sweep.resolveScenarioForCarrier(base, f_c);
end

function ac = siso()
ac = struct('N_t', 1, 'N_r', 1);
end
