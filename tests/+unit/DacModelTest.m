classdef DacModelTest < matlab.unittest.TestCase
    %DACMODELTEST The DAC power model switch (dacPowerModel -> dacConstants
    %   -> cs.DAC_* in resolveScenarioForCarrier), the DAC resolution taken
    %   from a curve file (sourceBdac, qamGear) and minOverDacLevels.
    %   See docs/DAC_POWER_MODEL.md and docs/DAC_QUANTISATION_SPEC.md.

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
        function defaultLeavesConstantsUnchanged(testCase)
            s = gearboxphy.sweep.makeScenarioConfig();
            testCase.verifyEqual(s.dacPowerModel, "analytic");
            for f_c = s.fcVec
                cs = gearboxphy.sweep.resolveScenarioForCarrier(s, f_c);
                testCase.verifyEqual(cs.DAC_VDD, 3);            % bit for bit
                testCase.verifyEqual(cs.DAC_I0, 10e-6);
                testCase.verifyEqual(cs.DAC_Cp, 1e-12*1/2);
            end
        end

        function analyticKeepsHandSetConstants(testCase)
            s = gearboxphy.sweep.makeScenarioConfig('DAC_VDD', 1.8, 'DAC_I0', 5e-6);
            cs = gearboxphy.sweep.resolveScenarioForCarrier(s, 28e9);
            testCase.verifyEqual(cs.DAC_VDD, 1.8);
            testCase.verifyEqual(cs.DAC_I0, 5e-6);
        end

        function oneVoltChangesOnlyTheSupply(testCase)
            s = gearboxphy.sweep.makeScenarioConfig('dacPowerModel', "analytic_1V");
            cs = gearboxphy.sweep.resolveScenarioForCarrier(s, 28e9);
            testCase.verifyEqual(cs.DAC_VDD, 1);
            testCase.verifyEqual(cs.DAC_I0, 10e-6);
            testCase.verifyEqual(cs.DAC_Cp, 1e-12*1/2);
        end

        function surveyGivesTheFittedProducts(testCase)
            % one DAC: 1.2 uW per LSB static, 0.25 pJ per bit and sample dynamic
            s = gearboxphy.sweep.makeScenarioConfig('dacPowerModel', "survey");
            cs = gearboxphy.sweep.resolveScenarioForCarrier(s, 28e9);
            for B = [1e6 4e8 2.8e9]
                for b = [1 2 4 7]
                    pair = gearboxphy.physics.dacPower(B, b, 2^b, cs.DAC_VDD, cs.DAC_I0, cs.DAC_Cp);
                    testCase.verifyEqual(pair, 2*(1.2e-6*(2^b - 1) + 0.25e-12*b*B), 'RelTol', 1e-12);
                end
            end
        end

        function modelsAreOrdered(testCase)
            % analytic (3 V) > analytic_1V > survey, for every b and B
            c = cell(1, 3); names = ["analytic", "analytic_1V", "survey"];
            for i = 1:3
                [v, i0, cp] = gearboxphy.physics.dacConstants(names(i), 3, 10e-6, 0.5e-12);
                c{i} = @(B, b) gearboxphy.physics.dacPower(B, b, 2^b, v, i0, cp);
            end
            for B = [1e4 1e7 4e8 3e9]
                for b = [1 3 6]
                    testCase.verifyGreaterThan(c{1}(B, b), c{2}(B, b));
                    testCase.verifyGreaterThan(c{2}(B, b), c{3}(B, b));
                end
            end
            % the numbers quoted in the deck: I/Q pair at 400 MHz, 1 bit
            testCase.verifyEqual(c{1}(4e8, 1), 3.63e-3, 'RelTol', 1e-12);
            testCase.verifyEqual(c{3}(4e8, 1), 0.2024e-3, 'RelTol', 1e-12);
        end

        function scenarioWithoutFieldIsUntouched(testCase)
            s = rmfield(gearboxphy.sweep.makeScenarioConfig(), 'dacPowerModel');
            cs = gearboxphy.sweep.resolveScenarioForCarrier(s, 8e9);
            testCase.verifyEqual(cs.DAC_VDD, 3);
            testCase.verifyEqual(cs.DAC_Cp, 1e-12*1/2);
        end

        function unknownModelFailsLoudly(testCase)
            testCase.verifyError(@() gearboxphy.physics.dacConstants("typo", 3, 1e-5, 5e-13), 'gearboxphy:dacPowerModel');
            testCase.verifyError(@() gearboxphy.sweep.makeScenarioConfig('dacPowerModel', "typo"), ?MException);
        end

        function digitalTransmitterPaysTheDacResolutionOfTheCurve(testCase)
            [dirPlain, dirDac] = localCurveDirs(testCase, 4);      % 16-QAM 4x4, sourceBdac = 4
            cfg = struct('N_t', 4, 'N_r', 4); x = [log10(2e8), 0.7]; R = 1e8; B = 2e8;
            gear = gearboxphy.gears.qamGear();
            csP = localCs(dirPlain); csD = localCs(dirDac);
            bP = gear.computeBudget(gear.prepare(16, csP, cfg), x, R);
            bD = gear.computeBudget(gear.prepare(16, csD, cfg), x, R);
            p = @(b) gearboxphy.physics.dacPower(B, b, 2^b, csP.DAC_VDD, csP.DAC_I0, csP.DAC_Cp);
            testCase.verifyEqual(bD.DAC / bP.DAC, p(4) / p(2), 'RelTol', 1e-12);
            % nothing else moves: same curve, same operating point
            for f = ["PA","LO_Tx","Mix_Tx","LNA","LO_Rx","Mix_Rx","ADC"]
                testCase.verifyEqual(bD.(f), bP.(f), 'RelTol', 1e-12, sprintf('%s', f));
            end
            % and a curve without the field behaves exactly as before
            ctx = gear.prepare(16, csP, cfg);
            testCase.verifyEqual(ctx.b_DAC, 2);
        end

        function analogTransmitterNeverPaysMore(testCase)
            [dirPlain, dirDac] = localCurveDirs(testCase, 4);
            cfg = struct('N_t', 4, 'N_r', 4); x = [log10(2e8), 0.7]; R = 1e8;
            gear = gearboxphy.gears.qamGear();
            extra = {'beamformingArchTx', "analog", 'analogCurvesCarryArrayGain', true};
            bP = gear.computeBudget(gear.prepare(16, localCs(dirPlain, extra{:}), cfg), x, R);
            bD = gear.computeBudget(gear.prepare(16, localCs(dirDac, extra{:}), cfg), x, R);
            testCase.verifyEqual(bD.DAC, bP.DAC);                  % one DAC at 1/2*log2(M)
            ctx = gear.prepare(16, localCs(dirDac, extra{:}), cfg);
            testCase.verifyEqual(ctx.b_DAC, 2);
        end

        function minOverDacLevelsPicksTheCheapestFeasibleLevel(testCase)
            E = nan(2, 3, 4);                        % [points x M x levels]
            E(1, 1, :) = [5 3 4 6];
            E(1, 2, :) = [NaN 2 NaN 1];
            E(2, 3, :) = [7 NaN NaN NaN];
            A = 10 * E;
            [best, k, a] = gearboxphy.sweep.minOverDacLevels(E, A);
            testCase.verifySize(best, [2 3]);
            testCase.verifyEqual(best(1, 1), 3); testCase.verifyEqual(k(1, 1), 2);
            testCase.verifyEqual(best(1, 2), 1); testCase.verifyEqual(k(1, 2), 4);
            testCase.verifyEqual(best(2, 3), 7); testCase.verifyEqual(k(2, 3), 1);
            testCase.verifyTrue(isnan(best(2, 1)) && isnan(k(2, 1)) && isnan(a(2, 1)));
            testCase.verifyEqual(a(1, 1), 30); testCase.verifyEqual(a(1, 2), 10);
            % a 2-D input: its columns are the levels
            [b1, k1] = gearboxphy.sweep.minOverDacLevels(E(:, :, 1));
            testCase.verifySize(b1, [2 1]); testCase.verifyEqual(k1(1), 1);
            testCase.verifyError(@() gearboxphy.sweep.minOverDacLevels(E, A(:, :, 1:2)), ...
                'gearboxphy:minOverDacLevels:size');
        end
    end
end

function [dirPlain, dirDac] = localCurveDirs(testCase, bdac)
%LOCALCURVEDIRS Two temporary data folders with the same 16-QAM curves; in
%   the second one the 4x4 curve carries sourceBdac.
src = gearboxphy.paths.dataDir("SE_data_bfideal_fixedB");
dirPlain = tempname; dirDac = tempname;
for d = {dirPlain, dirDac}
    mkdir(d{1});
    testCase.addTeardown(@() rmdir(d{1}, 's'));
    copyfile(fullfile(src, 'SE_16_QAM.mat'), d{1});
    copyfile(fullfile(src, 'SE_16_QAM_4x4.mat'), d{1});
end
S = load(fullfile(dirDac, 'SE_16_QAM_4x4.mat'));
S.sourceBdac = bdac;
save(fullfile(dirDac, 'SE_16_QAM_4x4.mat'), '-struct', 'S');
end

function cs = localCs(dataDir, varargin)
cfgs = {struct('N_t', 1, 'N_r', 1), struct('N_t', 4, 'N_r', 4)};
s = gearboxphy.sweep.makeScenarioConfig('dataDir', string(dataDir), 'qamMimoConfigs', cfgs, ...
    'distance', 200, varargin{:});
cs = gearboxphy.sweep.resolveScenarioForCarrier(s, 28e9);
end
