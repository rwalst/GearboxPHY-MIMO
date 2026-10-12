classdef DacCapTest < matlab.unittest.TestCase
    %DACCAPTEST The DAC-curve clamp (capDacCurvesAgainstIdeal, decision E4).
    %   The clamp REWRITES exported curve files, so it is covered here rather
    %   than only exercised by a full export run. Every test builds its own
    %   pair of folders in a temporary directory - no repo data is touched.

    methods (Access = private)
        function [dacDir, refDir] = makePair(tc, snrRef, seRef, snrDac, seDac)
            root = tempname;
            dacDir = fullfile(root, 'dac');
            refDir = fullfile(root, 'ref');
            mkdir(dacDir); mkdir(refDir);
            tc.addTeardown(@() rmdir(root, 's'));
            localSave(fullfile(refDir, 'SE_16_QAM_2x2.mat'), snrRef, seRef);
            localSave(fullfile(dacDir, 'SE_16_QAM_2x2.mat'), snrDac, seDac);
        end
    end

    methods (Test)
        function clampsOnlyWhereAbove(tc)
            % Drei Punkte darueber, zwei darunter: nur die drei duerfen fallen.
            snr = 0:4;
            ref = [1.0 2.0 3.0 4.0 5.0];
            dac = [1.5 2.5 3.5 3.0 4.0];
            [d, r] = tc.makePair(snr, ref, snr, dac);
            s = gearboxphy.data.capDacCurvesAgainstIdeal(d, r, "dac", "ref");
            tc.verifyEqual(s.points, 3);
            tc.verifyEqual(s.files, 1);
            tc.verifyEqual(s.maxBit, 0.5, 'AbsTol', 1e-12);
            got = load(fullfile(d, 'SE_16_QAM_2x2.mat'), 'SE_vec');
            tc.verifyEqual(got.SE_vec, [1.0 2.0 3.0 3.0 4.0], 'AbsTol', 1e-12);
        end

        function neverRaisesACurve(tc)
            % Liegt die DAC-Kurve ueberall darunter, bleibt die Datei gleich.
            snr = 0:4;
            ref = [1.0 2.0 3.0 4.0 5.0];
            dac = ref - 0.3;
            [d, r] = tc.makePair(snr, ref, snr, dac);
            s = gearboxphy.data.capDacCurvesAgainstIdeal(d, r, "dac", "ref");
            tc.verifyEqual(s.points, 0);
            tc.verifyEqual(s.files, 0);
            got = load(fullfile(d, 'SE_16_QAM_2x2.mat'), 'SE_vec');
            tc.verifyEqual(got.SE_vec, dac, 'AbsTol', 1e-12);
        end

        function writesProvenance(tc)
            snr = 0:4;
            [d, r] = tc.makePair(snr, [1 2 3 4 5], snr, [1.2 2 3 4 5]);
            gearboxphy.data.capDacCurvesAgainstIdeal(d, r, "dac", "myref");
            got = load(fullfile(d, 'SE_16_QAM_2x2.mat'));
            tc.verifyEqual(got.dacCapRef, 'myref');
            tc.verifyEqual(got.dacCapPoints, 1);
            tc.verifyEqual(got.dacCapMaxBit, 0.2, 'AbsTol', 1e-12);
            tc.verifyEqual(got.dacCapUncovered, 0);
        end

        function countsUncoveredInsteadOfClamping(tc)
            % Referenz deckt nur 0..2 ab; die Punkte 3 und 4 bleiben stehen
            % und werden gezaehlt, statt still durchzurutschen.
            [d, r] = tc.makePair(0:2, [1 2 3], 0:4, [1.5 2 3 9 9]);
            s = gearboxphy.data.capDacCurvesAgainstIdeal(d, r, "dac", "ref");
            tc.verifyEqual(s.uncovered, 2);
            tc.verifyEqual(s.points, 1);
            got = load(fullfile(d, 'SE_16_QAM_2x2.mat'), 'SE_vec');
            tc.verifyEqual(got.SE_vec(4:5), [9 9], 'AbsTol', 1e-12);
        end

        function warnsWhenReferenceFolderMissing(tc)
            [d, r] = tc.makePair(0:2, [1 2 3], 0:2, [2 3 4]);
            rmdir(r, 's');
            tc.verifyWarning(@() gearboxphy.data.capDacCurvesAgainstIdeal(d, r, "dac", "ref"), ...
                'export:noDacCapRef');
            got = load(fullfile(d, 'SE_16_QAM_2x2.mat'), 'SE_vec');
            tc.verifyEqual(got.SE_vec, [2 3 4], 'AbsTol', 1e-12);
        end

        function warnsWhenSingleReferenceCurveMissing(tc)
            [d, r] = tc.makePair(0:2, [1 2 3], 0:2, [2 3 4]);
            delete(fullfile(r, 'SE_16_QAM_2x2.mat'));
            tc.verifyWarning(@() gearboxphy.data.capDacCurvesAgainstIdeal(d, r, "dac", "ref"), ...
                'export:dacCapRefIncomplete');
        end

        function leavesSisoCurveAlone(tc)
            % Die SISO-Kurve des Ordners traegt ohnehin die ideale Auflosung.
            [d, r] = tc.makePair(0:2, [1 2 3], 0:2, [1 2 3]);
            localSave(fullfile(d, 'SE_16_QAM.mat'), 0:2, [9 9 9]);
            gearboxphy.data.capDacCurvesAgainstIdeal(d, r, "dac", "ref");
            got = load(fullfile(d, 'SE_16_QAM.mat'), 'SE_vec');
            tc.verifyEqual(got.SE_vec, [9 9 9], 'AbsTol', 1e-12);
        end
    end
end

function localSave(f, SNR_vec, SE_vec)
snrReference = 'total';
save(f, 'SNR_vec', 'SE_vec', 'snrReference');
end
