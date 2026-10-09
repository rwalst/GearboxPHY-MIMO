classdef AnalogBeamformingTest < matlab.unittest.TestCase
    %ANALOGBEAMFORMINGTEST The analog-beamforming architecture switch:
    %   analogBeamformingParams.m and its use in qamGear.m.
    %   See docs/ANALOG_BEAMFORMING.md.

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
        function defaultIsDigitalAndDisabled(testCase)
            s = gearboxphy.sweep.makeScenarioConfig();
            testCase.verifyEqual(s.beamformingArch, "digital");
            cs = gearboxphy.sweep.resolveScenarioForCarrier(s, 28e9);
            abf = gearboxphy.physics.analogBeamformingParams(cs, struct('N_t', 4, 'N_r', 4));
            testCase.verifyFalse(abf.enabled);
            % a hand-built scenario without the field is digital, too
            abf = gearboxphy.physics.analogBeamformingParams(rmfield(cs, 'beamformingArch'), struct('N_t', 4, 'N_r', 4));
            testCase.verifyFalse(abf.enabled);
        end

        function digitalResultsDoNotDependOnTheNewFields(testCase)
            % Same point, scenario with and without the analog fields: bit for bit.
            [gear, csD] = localGear("digital", "active");
            fn = {'beamformingArch','beamformingArchTx','beamformingArchRx','analogCurvesCarryArrayGain','psType','psPower','psLossDb','psBits', ...
                  'psGainPA','psGainLNA','psNoiseFactorLNA','loDistributionModel','loDistPowerPerMixer'};
            csOld = rmfield(csD, fn);
            cfg = struct('N_t', 4, 'N_r', 4);
            x = [log10(2e8), 0.7]; R = 1e8;
            a = gear.makeObjective(gear.prepare(16, csD, cfg), R);
            b = gear.makeObjective(gear.prepare(16, csOld, cfg), R);
            testCase.verifyEqual(a(x), b(x));
            ba = gear.computeBudget(gear.prepare(16, csD, cfg), x, R);
            testCase.verifyEqual(sort(string(fieldnames(ba)))', ...
                sort(["PA","DAC","LO_Tx","Mix_Tx","LNA","LO_Rx","Mix_Rx","ADC"]));
        end

        function sisoAnalogEqualsSisoDigital(testCase)
            x = [log10(2e8), 0.7]; R = 1e8; cfg = struct('N_t', 1, 'N_r', 1);
            for ps = ["active","passive_penalty","passive_compensated"]
                [gear, csA] = localGear("analog", ps);
                [~, csD] = localGear("digital", ps);
                a = gear.makeObjective(gear.prepare(16, csA, cfg), R);
                d = gear.makeObjective(gear.prepare(16, csD, cfg), R);
                testCase.verifyEqual(a(x), d(x), sprintf('psType %s', ps));
            end
        end

        function activeCountsOneChainAndNPhaseShifters(testCase)
            x = [log10(2e8), 0.7]; R = 1e8; N = 8;
            [gear, csA] = localGear("analog", "active", 'psBits', Inf);
            [~, csD] = localGear("digital", "active");
            bA = gear.computeBudget(gear.prepare(16, csA, struct('N_t', N, 'N_r', N)), x, R);
            bD = gear.computeBudget(gear.prepare(16, csD, struct('N_t', N, 'N_r', N)), x, R);
            % with psBits = Inf and an active shifter the link budget is the digital one
            testCase.verifyEqual(bA.PA, bD.PA, 'RelTol', 1e-12);
            testCase.verifyEqual(bA.ADC, bD.ADC / N, 'RelTol', 1e-12);
            testCase.verifyEqual(bA.DAC, bD.DAC / N, 'RelTol', 1e-12);
            testCase.verifyEqual(bA.Mix_Rx, bD.Mix_Rx / N, 'RelTol', 1e-12);
            testCase.verifyEqual(bA.Mix_Tx, bD.Mix_Tx / N, 'RelTol', 1e-12);
            testCase.verifyEqual(bA.LNA, bD.LNA, 'RelTol', 1e-12);
            % N shifters of 20 mW per side, weighted like their chain
            g = x(2);
            testCase.verifyEqual(bA.PS_Rx, (1/R) * (g + csA.epsilon_rec * (1 - g)) * N * 20e-3, 'RelTol', 1e-12);
            testCase.verifyEqual(bA.PS_Tx, (1/R) * (g + csA.epsilon_trans * (1 - g)) * N * 20e-3, 'RelTol', 1e-12);
            % objective = sum of the budget
            f = gear.makeObjective(gear.prepare(16, csA, struct('N_t', N, 'N_r', N)), R);
            testCase.verifyEqual(f(x), sum(struct2array(bA)), 'RelTol', 1e-12);
        end

        function passivePenaltyHasNoDcPowerButLoss(testCase)
            cs = localScenario("analog", "passive_penalty", 'psBits', Inf, 'psLossDb', 7.5);
            abf = gearboxphy.physics.analogBeamformingParams(cs, struct('N_t', 4, 'N_r', 4));
            L = 10^(7.5/10);
            testCase.verifyEqual(abf.P_PS_Tx, 0); testCase.verifyEqual(abf.P_PS_Rx, 0);
            testCase.verifyEqual(abf.kappa_Tx, 1 + (L - 1) / 100, 'RelTol', 1e-12);
            testCase.verifyEqual(abf.deltaRx_dB, 10*log10(1 + (L - 1) / (32 * 3)), 'RelTol', 1e-12);
            testCase.verifyEqual(abf.lnaFactor, 1);
            testCase.verifyEqual(abf.extra_L_dB, abf.deltaRx_dB);
        end

        function passiveCompensatedPaysInLnaGain(testCase)
            cs = localScenario("analog", "passive_compensated", 'psBits', Inf, 'psLossDb', 7.5);
            abf = gearboxphy.physics.analogBeamformingParams(cs, struct('N_t', 4, 'N_r', 4));
            L = 10^(7.5/10);
            testCase.verifyEqual(abf.lnaFactor, L, 'RelTol', 1e-12);
            testCase.verifyEqual(abf.deltaRx_dB, 10*log10(1 + (L - 1) / (32 * L * 3)), 'RelTol', 1e-12);
            pen = gearboxphy.physics.analogBeamformingParams( ...
                localScenario("analog", "passive_penalty", 'psBits', Inf, 'psLossDb', 7.5), struct('N_t', 4, 'N_r', 4));
            testCase.verifyLessThan(abf.deltaRx_dB, pen.deltaRx_dB);
        end

        function defaultParametersAt28GHz(testCase)
            abf = gearboxphy.physics.analogBeamformingParams(localScenario("analog", "active"), struct('N_t', 2, 'N_r', 2));
            testCase.verifyEqual(abf.P_PS, 20e-3);
            abf = gearboxphy.physics.analogBeamformingParams(localScenario("analog", "passive_penalty"), struct('N_t', 2, 'N_r', 2));
            testCase.verifyEqual(abf.L_PS_dB, 7.5, 'AbsTol', 1e-12);
        end

        function quantisationLoss(testCase)
            q = @(N, b) getfield(gearboxphy.physics.analogBeamformingParams( ...
                localScenario("analog", "active", 'psBits', b), struct('N_t', N, 'N_r', 1)), 'quantLoss_dB'); %#ok<GFLD>
            testCase.verifyEqual(q(1, 3), 0);
            testCase.verifyEqual(q(16, Inf), 0);
            k1 = (2/pi)^2;                       % b = 1: errors uniform on +-pi/2
            testCase.verifyEqual(q(16, 1), -10*log10((1 + 15*k1)/16), 'RelTol', 1e-12);
            testCase.verifyLessThan(q(16, 6), 0.01);
            testCase.verifyGreaterThan(q(16, 2), q(16, 3));
            % both sides add
            both = gearboxphy.physics.analogBeamformingParams(localScenario("analog", "active", 'psBits', 2), struct('N_t', 8, 'N_r', 8));
            testCase.verifyEqual(both.quantLoss_dB, 2 * q(8, 2), 'RelTol', 1e-12);
        end

        function loDistributionDefaultIsZero(testCase)
            s = gearboxphy.sweep.makeScenarioConfig();
            testCase.verifyEqual(s.loDistributionModel, "shared");
            cs = gearboxphy.sweep.resolveScenarioForCarrier(s, 28e9);
            testCase.verifyEqual(gearboxphy.physics.loDistributionPower(cs, 16), 0);
            testCase.verifyEqual(gearboxphy.physics.loDistributionPower(rmfield(cs, 'loDistributionModel'), 16), 0);
        end

        function loDistributionChargesMixersBeyondTheFirst(testCase)
            cs = localScenario("digital", "active", 'loDistributionModel', "per_mixer");
            testCase.verifyEqual(gearboxphy.physics.loDistributionPower(cs, 1), 0);
            testCase.verifyEqual(gearboxphy.physics.loDistributionPower(cs, 8), 7 * 16.6e-3, 'RelTol', 1e-12);
            cs.loDistPowerPerMixer = 50e-3;
            testCase.verifyEqual(gearboxphy.physics.loDistributionPower(cs, 4), 3 * 50e-3, 'RelTol', 1e-12);
            % no default away from 28 GHz
            cs8 = gearboxphy.sweep.resolveScenarioForCarrier( ...
                gearboxphy.sweep.makeScenarioConfig('loDistributionModel', "per_mixer"), 8e9);
            testCase.verifyError(@() gearboxphy.physics.loDistributionPower(cs8, 4), 'gearboxphy:loDistPower');
        end

        function loDistributionHitsDigitalNotAnalog(testCase)
            x = [log10(2e8), 0.7]; R = 1e8; N = 8; cfg = struct('N_t', N, 'N_r', N);
            [gear, dS] = localGear("digital", "active");
            [~, dP] = localGear("digital", "active", 'loDistributionModel', "per_mixer");
            [~, aS] = localGear("analog", "active");
            [~, aP] = localGear("analog", "active", 'loDistributionModel', "per_mixer");
            b = @(cs) gear.computeBudget(gear.prepare(16, cs, cfg), x, R);
            g = x(2);
            % digital: 7 extra buffers per side, everything else untouched
            bS = b(dS); bP = b(dP);
            testCase.verifyEqual(bP.LO_Rx - bS.LO_Rx, (1/R) * (g + dS.epsilon_rec * (1 - g)) * 7 * 16.6e-3, 'RelTol', 1e-9);
            testCase.verifyEqual(bP.LO_Tx - bS.LO_Tx, (1/R) * (g + dS.epsilon_trans * (1 - g)) * 7 * 16.6e-3, 'RelTol', 1e-9);
            for f = ["PA","DAC","Mix_Tx","LNA","Mix_Rx","ADC"]
                testCase.verifyEqual(bP.(f), bS.(f));
            end
            fP = gear.makeObjective(gear.prepare(16, dP, cfg), R);
            testCase.verifyEqual(fP(x), sum(struct2array(bP)), 'RelTol', 1e-12);
            % analog: one mixer per side, bit for bit unchanged
            testCase.verifyEqual(b(aP), b(aS));
            % SISO: unchanged in the digital architecture, too
            c1 = struct('N_t', 1, 'N_r', 1);
            testCase.verifyEqual(gear.computeBudget(gear.prepare(16, dP, c1), x, R), ...
                                 gear.computeBudget(gear.prepare(16, dS, c1), x, R));
        end

        function perSideOverridesFollowAndOverride(testCase)
            cfg = struct('N_t', 8, 'N_r', 4);
            % both overrides analog == beamformingArch analog
            a = gearboxphy.physics.analogBeamformingParams(localScenario("analog", "active"), cfg);
            b = gearboxphy.physics.analogBeamformingParams( ...
                localScenario("digital", "active", 'beamformingArchTx', "analog", 'beamformingArchRx', "analog"), cfg);
            testCase.verifyEqual(a, b);
            % analog overridden to digital on both sides == disabled
            c = gearboxphy.physics.analogBeamformingParams( ...
                localScenario("analog", "active", 'beamformingArchTx', "digital", 'beamformingArchRx', "digital"), cfg);
            testCase.verifyFalse(c.enabled);
        end

        function mixedTxAnalogRxDigital(testCase)
            cs = localScenario("digital", "passive_penalty", 'beamformingArchTx', "analog", 'psBits', 2, 'psLossDb', 7.5);
            abf = gearboxphy.physics.analogBeamformingParams(cs, struct('N_t', 8, 'N_r', 8));
            L = 10^(7.5/10);
            testCase.verifyTrue(abf.enabled);
            testCase.verifyEqual([abf.nChainsTx abf.nChainsRx], [1 8]);
            testCase.verifyEqual(abf.kappa_Tx, 1 + (L - 1)/100, 'RelTol', 1e-12);
            % nothing happens on the digital receive side
            testCase.verifyEqual(abf.P_PS_Rx, 0);
            testCase.verifyEqual(abf.lnaFactor, 1);
            testCase.verifyEqual(abf.deltaRx_dB, 0);
            % quantisation loss of ONE side only
            one = gearboxphy.physics.analogBeamformingParams( ...
                localScenario("analog", "active", 'psBits', 2), struct('N_t', 8, 'N_r', 1));
            testCase.verifyEqual(abf.quantLoss_dB, one.quantLoss_dB, 'RelTol', 1e-12);
            % compensated == penalty when the receiver is digital
            csC = localScenario("digital", "passive_compensated", 'beamformingArchTx', "analog", 'psBits', 2, 'psLossDb', 7.5);
            testCase.verifyEqual(gearboxphy.physics.analogBeamformingParams(csC, struct('N_t', 8, 'N_r', 8)).extra_L_dB, abf.extra_L_dB);
        end

        function mixedBudgetsCountChainsPerSide(testCase)
            x = [log10(2e8), 0.7]; R = 1e8; N = 8; cfg = struct('N_t', N, 'N_r', N);
            [gear, dD] = localGear("digital", "active", 'psBits', Inf);
            [~, aA] = localGear("analog", "active", 'psBits', Inf);
            [~, aD] = localGear("digital", "active", 'psBits', Inf, 'beamformingArchTx', "analog");
            [~, dA] = localGear("digital", "active", 'psBits', Inf, 'beamformingArchRx', "analog");
            b = @(cs) gear.computeBudget(gear.prepare(16, cs, cfg), x, R);
            bDD = b(dD); bAA = b(aA); bAD = b(aD); bDA = b(dA);
            % Tx analog, Rx digital: transmit side as all-analog, receive side as all-digital
            for f = ["DAC","Mix_Tx","LO_Tx","PS_Tx"], testCase.verifyEqual(bAD.(f), bAA.(f), 'RelTol', 1e-12); end
            for f = ["ADC","Mix_Rx","LO_Rx","LNA"],   testCase.verifyEqual(bAD.(f), bDD.(f), 'RelTol', 1e-12); end
            testCase.verifyEqual(bAD.PS_Rx, 0);
            % Tx digital, Rx analog: the other way round
            for f = ["DAC","Mix_Tx","LO_Tx"],         testCase.verifyEqual(bDA.(f), bDD.(f), 'RelTol', 1e-12); end
            for f = ["ADC","Mix_Rx","LO_Rx","PS_Rx"], testCase.verifyEqual(bDA.(f), bAA.(f), 'RelTol', 1e-12); end
            testCase.verifyEqual(bDA.PS_Tx, 0);
            % same link budget in all four (active, no quantisation): same PA
            testCase.verifyEqual([bAD.PA bDA.PA bAA.PA], [bDD.PA bDD.PA bDD.PA], 'RelTol', 1e-12);
            % LO distribution charges only the digital side
            [~, aDlo] = localGear("digital", "active", 'psBits', Inf, 'beamformingArchTx', "analog", 'loDistributionModel', "per_mixer");
            bLo = b(aDlo); g = x(2);
            testCase.verifyEqual(bLo.LO_Tx, bAD.LO_Tx);
            testCase.verifyEqual(bLo.LO_Rx - bAD.LO_Rx, (1/R) * (g + aD.epsilon_rec * (1 - g)) * 7 * 16.6e-3, 'RelTol', 1e-9);
        end

        function analogNeedsASingleStream(testCase)
            testCase.verifyError(@() gearboxphy.sweep.makeScenarioConfig('beamformingArch', "analog"), ...
                'gearboxphy:analogNeedsSingleStream');
            s = gearboxphy.sweep.makeScenarioConfig('beamformingArch', "analog", 'analogCurvesCarryArrayGain', true);
            testCase.verifyEqual(s.antennaMode, "multiplexing");
            % one analog side is enough to need a single stream
            testCase.verifyError(@() gearboxphy.sweep.makeScenarioConfig('beamformingArchRx', "analog"), ...
                'gearboxphy:analogNeedsSingleStream');
        end

        function otherGearsRefuseMultiAntennaAnalog(testCase)
            cs = localScenario("analog", "active");
            testCase.verifyError(@() gearboxphy.physics.assertDigitalArch(cs, struct('N_t', 2, 'N_r', 2), "ZXM"), ...
                'gearboxphy:analogNotImplemented');
            testCase.verifyWarningFree(@() gearboxphy.physics.assertDigitalArch(cs, struct('N_t', 1, 'N_r', 1), "ZXM"));
        end
    end
end

function cs = localScenario(arch, psType, varargin)
s = gearboxphy.sweep.makeScenarioConfig('antennaMode', "beamforming", 'beamformingArch', arch, ...
    'psType', psType, 'distance', 200, varargin{:});
cs = gearboxphy.sweep.resolveScenarioForCarrier(s, 28e9);
end

function [gear, cs] = localGear(arch, psType, varargin)
cs = localScenario(arch, psType, varargin{:});
cs.dataDir = gearboxphy.paths.dataDir(cs.dataDir);
gear = gearboxphy.gears.qamGear();
end
