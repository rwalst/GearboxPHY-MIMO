classdef GoldenMasterTest < matlab.unittest.TestCase
    %GOLDENMASTERTEST Compares the new framework's gear computations
    %   against the original codebase's get_min_E_bit_*.m/e_bit_fct_*.m
    %   functions for sample points, using the same technique proven
    %   earlier in this project's history (a baseline-vs-current
    %   comparison harness) - see ARCHITECTURE_PLAN.md section 7.
    %
    %   NOTE: matlab.unittest test classes are themselves classdef by
    %   necessity (that's how the MATLAB testing framework works) - this
    %   is unrelated to the framework-under-test's own design choice to
    %   use plain functions/structs instead of classdef (see
    %   ARCHITECTURE_PLAN.md section 4.1).
    %
    %   Requires: the original codebase at /workspace on the path, this
    %   framework's root on the path, and the test-only obw() shim (see
    %   shim/obw.m) since this sandbox has no Signal Processing Toolbox.
    %
    %   (Self-references use plain literals/unqualified sibling-method
    %   calls rather than `GoldenMasterTest.something` - a package
    %   classdef's short name doesn't resolve that way from inside its
    %   own body; only the fully-qualified `goldenmaster.GoldenMasterTest`
    %   would, which is more fragile than just not doing it.)

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath("/workspace");
            addpath("/workspace/gearboxphy_framework");
            addpath("/workspace/gearboxphy_framework/tests/+goldenmaster/shim");
            testCase.addTeardown(@() rmpath("/workspace"));
            testCase.addTeardown(@() rmpath("/workspace/gearboxphy_framework"));
            testCase.addTeardown(@() rmpath("/workspace/gearboxphy_framework/tests/+goldenmaster/shim"));
        end
    end

    methods (Test)
        function qamMatchesOriginal(testCase)
            for f_c = [2.4e9, 28e9]
                for R = [1e5, 1e7]
                    [oldE, oldB, oldG] = runOldQAM(R, 16, f_c);
                    [newE, newB, newG] = runNewGear("QAM", 16, R, f_c);
                    testCase.verifyEqual(isfinite(newE), isfinite(oldE));
                    if isfinite(oldE)
                        testCase.verifyEqual(newE, oldE, 'RelTol', 1e-6);
                        testCase.verifyEqual(newB, oldB, 'RelTol', 1e-6);
                        testCase.verifyEqual(newG, oldG, 'RelTol', 1e-3);
                    end
                end
            end
        end

        function naQamMatchesOriginal(testCase)
            for f_c = [2.4e9, 28e9]
                for R = [1e5, 1e7]
                    [oldE, oldB, oldG] = runOldNAQAM(R, 1024, f_c);
                    [newE, newB, newG] = runNewGear("NA-QAM", 1024, R, f_c);
                    testCase.verifyEqual(isfinite(newE), isfinite(oldE));
                    if isfinite(oldE)
                        % Both sides use fminbnd for NA-QAM's scalar bounded
                        % gamma (the original codebase already had this swap
                        % applied in an earlier round of this project's
                        % history, before this new framework was written) -
                        % so this is a same-algorithm comparison, held to the
                        % same tight tolerance as the other three gears
                        % (previously loosened here on the mistaken belief
                        % that the old side still used fminsearch+penalty -
                        % code review finding #8).
                        testCase.verifyEqual(newE, oldE, 'RelTol', 1e-6);
                        testCase.verifyEqual(newB, oldB, 'RelTol', 1e-6);
                        testCase.verifyEqual(newG, oldG, 'RelTol', 1e-3);
                    end
                end
            end
        end

        function zxmMatchesOriginal(testCase)
            for f_c = [2.4e9, 28e9]
                for R = [1e5, 1e7]
                    [oldE, oldB, oldG] = runOldZXM(R, 1, f_c);
                    [newE, newB, newG] = runNewGear("ZXM", 1, R, f_c);
                    testCase.verifyEqual(isfinite(newE), isfinite(oldE));
                    if isfinite(oldE)
                        testCase.verifyEqual(newE, oldE, 'RelTol', 1e-6);
                        testCase.verifyEqual(newB, oldB, 'RelTol', 1e-6);
                        testCase.verifyEqual(newG, oldG, 'RelTol', 1e-3);
                    end
                end
            end
        end

        function pulseEnergyMatchesOriginal(testCase)
            for f_c = [2.4e9, 28e9]
                for R = [1e5, 1e7]
                    [oldE, oldB, oldG] = runOldPulse(R, f_c, "Energy");
                    [newE, newB, newG] = runNewGear("Pulse-Energy", 1, R, f_c);
                    testCase.verifyEqual(isfinite(newE), isfinite(oldE));
                    if isfinite(oldE)
                        testCase.verifyEqual(newE, oldE, 'RelTol', 1e-6);
                        testCase.verifyEqual(newB, oldB, 'RelTol', 1e-6);
                        testCase.verifyEqual(newG, oldG, 'RelTol', 1e-3);
                    end
                end
            end
        end
    end
end

function cs = baseParams(f_c)
cs.maxiters = 1000;
cs.tolerance = 1e-8;
cs.numtriesPerOpt = 4;
cs.eta = 0.1;
cs.epsilon_trans = 0.01;
cs.epsilon_rec = 0.5;
cs.alpha = 0.5;
cs.N_0 = 1.380649e-23*295;
cs.beta = 2;
cs.c = 3e8;
cs.c_PA = 4.32e-5;
cs.c_ADC = 0.67e-15;
cs.f_b = 560e6;
cs.NoiseFigure = 10;
cs.Maximum_P_T = 10;
cs.D_r = 6;
cs.D_t = 6;
cs.gamma_MOS = 1;
cs.DAC_VDD = 3;
cs.DAC_Cp = 1e-12*1/2;
cs.DAC_I0 = 10e-6;
cs.P_ED = 2.4e-3;
cs.distance = 50;
cs.pulseFilter = "rc";
cs.f_c = f_c;
if f_c == 2.4e9
    cs.P_Mix = 1.57e-3; cs.P_LO = 6e-3;
elseif f_c == 28e9
    cs.P_Mix = 8.4e-3; cs.P_LO = 26.9e-3;
else
    error('unsupported f_c for this test');
end
end

function [E, B, G] = runOldQAM(R, M, f_c)
cs = baseParams(f_c);
SE_data = load(sprintf('/workspace/SE_data/SE_%d_QAM.mat', M));
cs.bw_factor = get_p_containment_bw(cs.alpha, 99);
cs.SNR_vec = SE_data.SNR_vec;
cs.mui_vec = SE_data.SE_vec ./ cs.bw_factor;
[op, ~] = get_min_E_bit_QAM(R, M, cs);
E = op.E_per_bit; B = op.Optimal_B; G = op.Optimal_gamma;
end

function [E, B, G] = runOldNAQAM(R, M, f_c)
cs = baseParams(f_c);
SE_data = load(sprintf('/workspace/SE_data/SE_%d_QAM.mat', M));
cs.bw_factor = get_p_containment_bw(cs.alpha, 99);
cs.SNR_vec = SE_data.SNR_vec;
cs.mui_vec = SE_data.SE_vec ./ cs.bw_factor;
[op, ~] = get_min_E_bit_NA_QAM(R, M, cs);
E = op.E_per_bit; B = op.Optimal_B; G = op.Optimal_gamma;
end

function [E, B, G] = runOldZXM(R, M_tx, f_c)
cs = baseParams(f_c);
SE_data = load(sprintf('/workspace/SE_data/MUI_ZXM_Mtx=%d_sigmaPN=-5.mat', M_tx));
cs.bw_factorZXM = get_p_containment_bw_ZXM(cs.alpha, 99, M_tx);
cs.SNR_vec = SE_data.SNR_dB_vec;
cs.SE_vec = SE_data.I_vec ./ cs.bw_factorZXM;
[op, ~] = get_min_E_bit_ZXM(R, M_tx, cs);
E = op.E_per_bit; B = op.Optimal_B; G = op.Optimal_gamma;
end

function [E, B, G] = runOldPulse(R, f_c, pulseType)
cs = baseParams(f_c);
SE_data = load('/workspace/SE_data/SE_Unipolar_IR.mat');
cs.SNR_vec = SE_data.SNR;
cs.SE_vec = SE_data.SE;
raw = load('/workspace/SE_data/dkEnergyRX_ArbSign_SE99.mat');
T_PAPR = struct2table(raw.groupVal);
logicmap = (T_PAPR.hTxName=="rc") & (T_PAPR.modultn=="dkEnergyRX") & (T_PAPR.Mtx==1);
cs.PulsePAPR = T_PAPR.PAPR_dB(logicmap);
modulation.type = pulseType;
modulation.order = 1;
[op, ~] = get_min_E_bit_Pulse(R, modulation, cs);
E = op.E_per_bit; B = op.Optimal_B; G = op.Optimal_gamma;
end

function [E, B, G] = runNewGear(gearName, order, R, f_c)
baseScenario = gearboxphy.sweep.makeScenarioConfig( ...
    'maxiters', 1000, 'tolerance', 1e-8, 'numtriesPerOpt', 4, ...
    'distance', 50, ...
    'dataDir', "/workspace/gearboxphy_framework/SE_data");
cs = gearboxphy.sweep.resolveScenarioForCarrier(baseScenario, f_c);

gears = gearboxphy.gears.gearRegistry();
gear = [];
for gi = 1:numel(gears)
    if gears{gi}.name == gearName
        gear = gears{gi};
    end
end
assert(~isempty(gear), 'gear "%s" not found', gearName);

ctx = gear.prepare(order, cs, struct('N_t', 1, 'N_r', 1));   % SISO - all golden-master comparisons are against the original (SISO-only) codebase
x0 = gear.initialGuess(order, cs);
bounds = gear.optimizerBounds(order, cs);
optParams = struct('tolerance', cs.tolerance, 'maxiters', cs.maxiters, ...
    'numtriesPerOpt', cs.numtriesPerOpt);

[E, B, G, ~] = gearboxphy.sweep.optimizeOnePoint(gear, ctx, R, x0, bounds, optParams);
end
