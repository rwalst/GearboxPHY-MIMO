classdef PhysicsTest < matlab.unittest.TestCase
    %PHYSICSTEST Unit tests for the shared +physics power/path-loss
    %   formulas - functions that previously had zero test coverage
    %   (inline copy-pasted formulas across four e_bit_fct_*.m files).

    methods (TestClassSetup)
        function addPaths(testCase)
            root = frameworkRoot();
            addpath(root);
            testCase.addTeardown(@() rmpath(root));
        end
    end

    methods (Test)
        function powerAmplifierMatchesFormula(testCase)
            P = gearboxphy.physics.powerAmplifier(0.01, sqrt(28e9), 2.5, 4.32e-5);
            expected = 4.32e-5 * 0.01 * sqrt(28e9) * 2.5;
            testCase.verifyEqual(P, expected, 'RelTol', 1e-12);
        end

        function powerAmplifierDefaultsMatchModelA(testCase)
            % Called with only 4 args (as every non-QAM gear does), N_t/P_0
            % must default to 1/0 - i.e. exactly the original formula,
            % scale-invariant, no affine overhead (PA_POWER_MODEL_DECISION.md
            % Model A).
            P4arg = gearboxphy.physics.powerAmplifier(0.01, sqrt(28e9), 2.5, 4.32e-5);
            P6arg = gearboxphy.physics.powerAmplifier(0.01, sqrt(28e9), 2.5, 4.32e-5, 1, 0);
            testCase.verifyEqual(P4arg, P6arg, 'RelTol', 1e-12);
        end

        function powerAmplifierAffineModelAddsNtTimesP0(testCase)
            % Model B (PA_POWER_MODEL_DECISION.md): total PA power gains
            % N_t*P_0 on top of the same scale-invariant linear term.
            P_t = 0.01; sqrt_fc = sqrt(28e9); papr = 2.5; c_PA = 4.32e-5;
            P_0 = 1e-3; N_t = 4;
            P = gearboxphy.physics.powerAmplifier(P_t, sqrt_fc, papr, c_PA, N_t, P_0);
            expected = N_t*P_0 + c_PA*P_t*sqrt_fc*papr;
            testCase.verifyEqual(P, expected, 'RelTol', 1e-12);
        end

        function adcPowerMatchesFormula(testCase)
            B = 1e7; pow2_b = 16; f_b = 560e6; c_ADC = 0.67e-15;
            P = gearboxphy.physics.adcPower(B, pow2_b, f_b, c_ADC);
            expected = 2*c_ADC*pow2_b*B*sqrt(1+(B/f_b)^2);
            testCase.verifyEqual(P, expected, 'RelTol', 1e-12);
        end

        function dacPowerMatchesFormula(testCase)
            B = 1e7; b = 4; pow2_b = 16;
            DAC_VDD = 3; DAC_I0 = 10e-6; DAC_Cp = 0.5e-12;
            P = gearboxphy.physics.dacPower(B, b, pow2_b, DAC_VDD, DAC_I0, DAC_Cp);
            expected = 2*(1/2*DAC_VDD*DAC_I0*(pow2_b-1) + DAC_Cp*DAC_VDD^2*b*B);
            testCase.verifyEqual(P, expected, 'RelTol', 1e-12);
        end

        function lnaPowerMatchesFormula(testCase)
            B = 1e7; N_0 = 1.380649e-23*295;
            P = gearboxphy.physics.lnaPower(B, N_0);
            FoM_LNA = 1e-7;
            expected = 32*B*N_0/((3-1)*FoM_LNA);
            testCase.verifyEqual(P, expected, 'RelTol', 1e-12);
        end

        function pathLossDbMatchesFormula(testCase)
            f_c = 28e9; distance = 50; D_r = 6; D_t = 6; beta = 2; c = 3e8;
            L_dB = gearboxphy.physics.pathLossDb(f_c, distance, D_r, D_t, beta, c);
            lambda = c/f_c;
            L = (D_r*D_t*(lambda/(4*pi*distance))^beta)^(-1);
            testCase.verifyEqual(L_dB, 10*log10(L), 'RelTol', 1e-12);
        end

        function bandHardwareParamsKnownBands(testCase)
            [P_Mix, P_LO, etaOverride] = gearboxphy.physics.bandHardwareParams(28e9);
            testCase.verifyEqual(P_Mix, 8.4e-3);
            testCase.verifyEqual(P_LO, 26.9e-3);
            testCase.verifyTrue(isnan(etaOverride));
        end

        function bandHardwareParamsUnsupportedErrors(testCase)
            testCase.verifyError(@() gearboxphy.physics.bandHardwareParams(99e9), ...
                'gearboxphy:unsupportedBand');
        end
    end
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
