classdef GearsTest < matlab.unittest.TestCase
    %GEARSTEST Unit tests for the gear registry/struct-of-handles design,
    %   the boundary/infeasibility behavior of each gear's objective
    %   (gamma outside [0,1], B>B_max), and the MIMO antenna-config
    %   plumbing (MIMO_EXTENSION.md).

    methods (TestClassSetup)
        function addPaths(testCase)
            root = frameworkRoot();
            shim = fullfile(root, 'tests', '+goldenmaster', 'shim');   % obw()-Ersatz
            addpath(root);
            addpath(shim);
            testCase.addTeardown(@() rmpath(root));
            testCase.addTeardown(@() rmpath(shim));
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

        function nonQamNonZxmGearRejectsMimoAntennaConfig(testCase)
            % ZXM gehoert seit der SISO-vs-MIMO-Studie NICHT mehr hierher:
            % QuantizedMimoMI/zxm rechnet ZXM ueber eine beliebige
            % Kanalmatrix, also ist die Schranke fuer ZXM aufgehoben (siehe
            % seCurveFilename.m). Fuer die uebrigen Nicht-QAM-Gaenge gilt
            % MIMO_EXTENSION.md Entscheidung 2 unveraendert weiter.
            cs = testScenario(28e9);
            mimoConfig = struct('N_t', 2, 'N_r', 2);
            for gearName = ["NA-QAM", "Pulse-Energy", "Pulse-Arbitrary"]
                testCase.verifyError(@() gearboxphy.data.loadSECurve(gearName, 1, mimoConfig, cs.dataDir), ...
                    'gearboxphy:mimoNotSupported', ...
                    sprintf('%s muesste MIMO weiterhin ablehnen', gearName));
            end
        end

        function zxmGearAcceptsMimoAntennaConfigName(testCase)
            % Nur die NAMENSBILDUNG wird geprueft, nicht das Laden: eine
            % ZXM-MIMO-Kurve existiert erst nach dem Rayleigh-Lauf. Der
            % Test faellt also auf "Datei fehlt" und NICHT mehr auf
            % "mimoNotSupported" - genau das ist die Aussage.
            cs = testScenario(28e9);
            mimoConfig = struct('N_t', 2, 'N_r', 2);
            [fn, isSISO] = gearboxphy.data.seCurveFilename("ZXM", 1, mimoConfig, cs.dataDir);
            testCase.verifyFalse(isSISO);
            testCase.verifySubstring(fn, 'MUI_ZXM_Mtx=1_sigmaPN=-5_2x2.mat');
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
            % Ein global konfigurierter 2x2-Kandidat muss fuer eine
            % Ordnung OHNE passende MIMO-Kurve wegfallen (mit Warnung),
            % waehrend SISO immer bleibt; eine Ordnung MIT Kurve behaelt
            % beide.
            %
            % Der Test stand urspruenglich auf order=4 als dem Fall ohne
            % Kurve. Inzwischen liegt SE_4_QAM_2x2.mat vor -- die
            % MIMO-Kurven wurden fuer M in {4,16,64} x {2x2,4x4,8x8}
            % gemeinsam erzeugt -- und die Annahme stimmte nicht mehr.
            % Aufgefallen ist das erst, als die festen /workspace-Pfade
            % repariert waren und die Suite ueberhaupt wieder lief;
            % mimo_smoke_test.m hatte dieselbe veraltete Annahme.
            % order=256 ist jetzt der echte Fall ohne MIMO-Kurve.
            cs = testScenario(28e9);
            cs.qamMimoConfigs = {struct('N_t',1,'N_r',1), struct('N_t',2,'N_r',2)};
            gear = gearboxphy.gears.qamGear();

            testCase.verifyWarning(@() gearboxphy.data.filterAvailableAntennaConfigs( ...
                "QAM", 256, cs.qamMimoConfigs, cs.dataDir), 'gearboxphy:mimoCurveMissing');
            configsNoMimo = gear.antennaConfigs(256, cs);
            testCase.verifyEqual(numel(configsNoMimo), 1);
            testCase.verifyEqual(configsNoMimo{1}.N_t, 1);

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
                'dataDir', string(fullfile(frameworkRoot(), 'data', 'SE_data')), ...
                'paPowerModel', "constant", 'P_0', 5);   % P_0 set but should be ignored
            cs = gearboxphy.sweep.resolveScenarioForCarrier(base, 28e9);
            gear = gearboxphy.gears.qamGear();
            ctx = gear.prepare(16, cs, siso());
            testCase.verifyEqual(ctx.hw.P_0, 0);
        end

        function qamAffineModelWithoutP0Errors(testCase)
            base = gearboxphy.sweep.makeScenarioConfig( ...
                'dataDir', string(fullfile(frameworkRoot(), 'data', 'SE_data')), ...
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
                'dataDir', string(fullfile(frameworkRoot(), 'data', 'SE_data')), ...
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
    'dataDir', string(fullfile(frameworkRoot(), 'data', 'SE_data')));
cs = gearboxphy.sweep.resolveScenarioForCarrier(base, f_c);
end

function ac = siso()
ac = struct('N_t', 1, 'N_r', 1);
end

function p = frameworkRoot()
%FRAMEWORKROOT  Der Ordner gearboxphy_framework/, abgeleitet aus dem Ort
%   DIESER Datei. Vorher standen hier feste "/workspace/gearboxphy_framework"-
%   Pfade; die zeigten nach dem Umbenennen des Repos ins Leere, und der
%   Testlauf brach schon beim Einsammeln der Suite ab.
%
%   Lokale Funktionen in einer classdef-Datei sind auch aus den Methoden
%   der Klasse aufrufbar -- deshalb genuegt diese eine Stelle fuer beides.
p = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
