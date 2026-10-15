classdef OperatingPointTest < matlab.unittest.TestCase
    %OPERATINGPOINTTEST Der Arbeitspunkt je Optimierungspunkt: SE, der von
    %   der Kurve geforderte SNR, der sendeseitige SNR, P_t, B und gamma
    %   (+gears/operatingPointFrom.m).
    %
    %   DER ERSTE TEST IST DER WICHTIGSTE. Das Budget traegt eine
    %   ungeschriebene Invariante -- die Summe ALLER seiner Felder ist
    %   E_bit -- und vier Auswertungen sowie zwei Tests verlassen sich
    %   darauf ueber sum(struct2array(pb)). Genau deshalb liegt der
    %   Arbeitspunkt NICHT im Budget, und genau das prueft budgetStillSumsToEbit.

    methods (TestClassSetup)
        function addPaths(testCase)
            root = frameworkRoot();
            shim = fullfile(root, 'tests', '+goldenmaster', 'shim');
            addpath(root); addpath(shim);
            testCase.addTeardown(@() rmpath(root));
            testCase.addTeardown(@() rmpath(shim));
        end
    end

    methods (Test)
        function budgetStillSumsToEbit(testCase)
            [gear, ctx, R, x] = localSetup();
            [b, ~] = gear.computeBudget(ctx, x, R);
            f = gear.makeObjective(ctx, R);
            testCase.verifyEqual(f(x), sum(struct2array(b)), 'RelTol', 1e-12);
        end

        function budgetHasNoOperatingPointFields(testCase)
            % Haette jemand SE/SNR doch ins Budget gelegt, faellt es hier auf.
            [gear, ctx, R, x] = localSetup();
            [b, ~] = gear.computeBudget(ctx, x, R);
            fn = fieldnames(b);
            for k = ["SE" "SNR_rx_dB" "SNR_tx_dB" "P_t_W" "B_Hz" "gamma"]
                testCase.verifyFalse(any(strcmp(fn, k)), ...
                    sprintf('%s gehoert nicht ins Budget - dessen Felder summieren sich zu E_bit.', k));
            end
        end

        function seIsRateOverBandwidthAndDutyCycle(testCase)
            [gear, ctx, R, x] = localSetup();
            B = 10^x(1); gamma = x(2);
            [~, op] = gear.computeBudget(ctx, x, R);
            testCase.verifyEqual(op.SE, R/(gamma*B), 'RelTol', 1e-12);
            testCase.verifyEqual(op.B_Hz, B, 'RelTol', 1e-12);
            testCase.verifyEqual(op.gamma, gamma, 'RelTol', 1e-12);
        end

        function transmitSnrIsReceiveSnrPlusLinkBudget(testCase)
            [gear, ctx, R, x] = localSetup();
            [~, op] = gear.computeBudget(ctx, x, R);
            testCase.verifyEqual(op.SNR_tx_dB, op.SNR_rx_dB + ctx.L_dB, 'RelTol', 1e-12);
            % und P_t gehoert zu diesem SNR
            testCase.verifyEqual(op.P_t_W, 10^(op.SNR_tx_dB/10) * ctx.hw.N_0 * op.B_Hz, 'RelTol', 1e-12);
        end

        function infeasiblePointGivesNanStructOfSameShape(testCase)
            % NICHT ueber computeBudget: das setzt einen ZULAESSIGEN Punkt
            % voraus und greift sonst auf core.P_PA zu, das die
            % Abbruchkante von computeCore nie setzt. Das ist Bestand und
            % kein Fehler -- computeBudget wird nur am konvergierten
            % Optimum gerufen (optimizeOnePoint ruft es im else-Zweig gar
            % nicht). Geprueft wird deshalb die Quelle des NaN-Structs.
            for bad = {[], struct('feasible', false), struct('gamma', 0.5)}
                op = gearboxphy.gears.operatingPointFrom(bad{1});
                testCase.verifyEqual(sort(fieldnames(op)), ...
                    sort({'SE';'SNR_rx_dB';'SNR_tx_dB';'P_t_W';'B_Hz';'gamma'}));
                testCase.verifyTrue(all(isnan(struct2array(op))));
            end
        end

        function unreachableRateGivesNanOperatingPoint(testCase)
            % Ende zu Ende: eine Rate, die kein (B, gamma) traegt, muss
            % einen Arbeitspunkt derselben Form mit NaN liefern -- nicht
            % NaN statt Struct, sonst braucht jede Auswertung einen
            % Sonderfall.
            [gear, ctx, ~] = localSetup();
            cs = localScenario();
            [e, ~, ~, ~, op] = gearboxphy.sweep.optimizeOnePoint( ...
                gear, ctx, 1e12, gear.initialGuess(16, cs), ...
                gear.optimizerBounds(16, cs), localOptParams());
            testCase.verifyTrue(isnan(e));
            testCase.verifyTrue(isstruct(op) && all(isnan(struct2array(op))));
        end

        function optimizeOnePointReturnsTheSameOperatingPoint(testCase)
            [gear, ctx, R] = localSetup();
            cs = localScenario();
            [~, ~, ~, ~, op] = gearboxphy.sweep.optimizeOnePoint( ...
                gear, ctx, R, gear.initialGuess(16, cs), gear.optimizerBounds(16, cs), ...
                localOptParams());
            testCase.verifyTrue(isfinite(op.SE) && isfinite(op.SNR_rx_dB));
            % Am Optimum muss dieselbe Rechnung herauskommen wie direkt
            % ueber computeBudget mit (B, gamma) des Arbeitspunkts.
            [~, op2] = gear.computeBudget(ctx, [log10(op.B_Hz), op.gamma], R);
            testCase.verifyEqual(op2.SE, op.SE, 'RelTol', 1e-10);
            testCase.verifyEqual(op2.SNR_rx_dB, op.SNR_rx_dB, 'RelTol', 1e-10);
        end

        function everyGearReturnsAnOperatingPoint(testCase)
            % Die Erweiterung darf keinen Gang auslassen - sonst faellt sie
            % erst beim Speichern auf, und dann als leeres Feld.
            gears = gearboxphy.gears.gearRegistry();
            for i = 1:numel(gears)
                g = gears{i};
                testCase.verifyEqual(nargout(g.computeBudget), 2, ...
                    sprintf('%s: computeBudget muss den Arbeitspunkt als zweites Argument liefern.', g.name));
            end
        end
    end
end

function cs = localScenario()
oldModels = gearboxphy.sweep.oldModelArgs();   % Modellsatz vor 2026-10-15, damit gespeicherte Ergebnisse gueltig bleiben
base = gearboxphy.sweep.makeScenarioConfig(oldModels{:},  ...
    'dataDir', string(fullfile(frameworkRoot(), 'data', 'SE_data')), ...
    'distance', 500, 'RVec', 1e9, 'fcVec', 28e9);
cs = gearboxphy.sweep.resolveScenarioForCarrier(base, 28e9);
end

function [gear, ctx, R, x] = localSetup()
cs = localScenario();
gear = gearboxphy.gears.qamGear();
ctx = gear.prepare(16, cs, struct('N_t', 1, 'N_r', 1));
R = 1e9;
% ZULAESSIGER Arbeitspunkt: SE = R/(gamma*B) = 2 bit/s/Hz. Bei 16-QAM ist
% schon SE = 4 unerreichbar (die Kurve saettigt knapp darunter, snrLookup
% gibt dort Inf), und computeBudget gilt nur fuer zulaessige Punkte.
x = [log10(1e9), 0.5];
end

function op = localOptParams()
op = struct('tolerance', 1e-8, 'maxiters', 400, 'numtriesPerOpt', 3);
end

function p = frameworkRoot()
p = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
