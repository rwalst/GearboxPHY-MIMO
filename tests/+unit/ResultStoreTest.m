classdef ResultStoreTest < matlab.unittest.TestCase
    %RESULTSTORETEST  Der Ergebnisspeicher: gleiche Rechnung -> gleicher
    %   Schluessel -> Datei wird uebernommen statt neu gerechnet
    %   (+data/fingerprint.m, comboFingerprint.m, gridFingerprint.m,
    %   fetchFromStore.m, publishToStore.m).
    %
    %   DIE ZWEI WICHTIGSTEN TESTS sind die mit echten Daten:
    %
    %   sisoGaengeSindUeberAlleVariantenEinSchluessel haelt den gemessenen
    %   Befund fest, der den ganzen Umbau begruendet: die sieben SISO-
    %   Schluessel von 3a sind in allen sechs BF/MUX-Varianten dieselbe
    %   Rechnung (E_bit stimmt auf 2e-9 ueberein), werden heute aber
    %   sechsmal gerechnet -- 21,6 % der Rechenzeit von 3a.
    %
    %   nutzlastEntscheidetNichtDerDateiinhalt haelt fest, warum nicht
    %   einfach die Datei gehasht wird: SE_4_QAM.mat hat in allen 36
    %   SE_data*-Ordnern einen ANDEREN Byte-Inhalt, waehrend SNR_vec,
    %   SE_vec und sourceB bitgleich sind -- ein Datei-Hash wuerde kein
    %   einziges echtes Duplikat finden.
    %
    %   Alle Tests, die schreiben, lenken die Ergebniswurzel per
    %   GEARBOXPHY_RESULTS_ROOT in einen temporaeren Ordner -- der Speicher
    %   des Repos wird nicht angefasst.

    properties
        tmp
    end

    methods (TestClassSetup)
        function addPaths(testCase)
            root = frameworkRoot();
            if ~any(strcmp(strsplit(path, pathsep), root))
                addpath(root);
                testCase.addTeardown(@() rmpath(root));
            end
        end
    end

    methods (TestMethodSetup)
        function redirectResults(testCase)
            testCase.tmp = fullfile(tempdir, sprintf('gbxstore_%d_%s', ...
                feature('getpid'), char(matlab.lang.makeValidName(string(rand)))));
            mkdir(testCase.tmp);
            alt = getenv('GEARBOXPHY_RESULTS_ROOT');
            setenv('GEARBOXPHY_RESULTS_ROOT', testCase.tmp);
            testCase.addTeardown(@() setenv('GEARBOXPHY_RESULTS_ROOT', alt));
            testCase.addTeardown(@() rmdir(testCase.tmp, 's'));
        end
    end

    methods (Test)
        % ---------- der Fingerabdruck selbst ----------
        function feldreihenfolgeIstGleichgueltig(testCase)
            a = struct('x', 1, 'y', [1 2 3]);
            b = struct('y', [1 2 3], 'x', 1);
            testCase.verifyEqual(gearboxphy.data.fingerprint(a), ...
                                 gearboxphy.data.fingerprint(b));
        end

        function kleinsteAenderungAendertDenSchluessel(testCase)
            a = struct('v', [1 2 3]);
            b = struct('v', [1 2 3 + eps(3)]);
            testCase.verifyNotEqual(gearboxphy.data.fingerprint(a), ...
                                    gearboxphy.data.fingerprint(b));
        end

        function klasseUndFormGehenEin(testCase)
            f = @gearboxphy.data.fingerprint;
            testCase.verifyNotEqual(f(1), f(true));          % 1 ist nicht true
            testCase.verifyNotEqual(f([1 2]), f([1; 2]));    % Zeile ist nicht Spalte
            testCase.verifyNotEqual(f("1"), f(1));           % Text ist nicht Zahl
        end

        function funktionshandleIstEinFehler(testCase)
            % Lieber abbrechen als einen Schluessel bilden, der zwei
            % verschiedene Rechnungen fuer gleich erklaert.
            testCase.verifyError(@() gearboxphy.data.fingerprint(struct('f', @sin)), ...
                'gearboxphy:data:fingerprintUnhashable');
        end

        function schluesselIstStabil(testCase)
            % Derselbe Aufruf zweimal -- sonst traegt der Speicher nie.
            x = struct('a', pi, 'b', "text", 'c', {{1, [2 3]}});
            testCase.verifyEqual(gearboxphy.data.fingerprint(x), ...
                                 gearboxphy.data.fingerprint(x));
        end

        % ---------- der Speicher ----------
        function treffenUndVerfehlen(testCase)
            src = fullfile(testCase.tmp, 'quelle.mat');
            zahl = 42; save(src, 'zahl');
            ziel = fullfile(testCase.tmp, 'ziel.mat');

            testCase.verifyFalse(gearboxphy.data.fetchFromStore("0123456789abcdef", ziel));
            gearboxphy.data.publishToStore("0123456789abcdef", src);
            testCase.verifyTrue(gearboxphy.data.fetchFromStore("0123456789abcdef", ziel));
            S = load(ziel);
            testCase.verifyEqual(S.zahl, 42);
        end

        function leererSchluesselIstKeinSpeicher(testCase)
            % Der Ausstieg fuer einen Aufrufer, der keinen Schluessel bilden
            % kann: es wird gerechnet, nicht abgebrochen.
            ziel = fullfile(testCase.tmp, 'ziel.mat');
            testCase.verifyFalse(gearboxphy.data.fetchFromStore("", ziel));
            testCase.verifyWarningFree(@() gearboxphy.data.publishToStore("", ziel));
        end

        function speicherLiegtUnterDerErgebniswurzel(testCase)
            % Damit er mit GEARBOXPHY_RESULTS_ROOT in den ZIH-Workspace wandert.
            testCase.verifyEqual(gearboxphy.data.storeDir(), ...
                fullfile(testCase.tmp, '_store'));
        end

        % ---------- die gemessenen Befunde, mit echten Daten ----------
        function nutzlastEntscheidetNichtDerDateiinhalt(testCase)
            % Die Aussage, auf der der ganze Entwurf beruht: die DATEIEN
            % unterscheiden sich, die NUTZLAST nicht. Ein Hash ueber die
            % Datei wuerde deshalb kein einziges echtes Duplikat finden.
            %
            % Geprueft wird das an den Bytes und an loadSECurve, nicht an
            % einem einzelnen Metadatenfeld. Erste Fassung dieses Tests
            % verglich generatedOn -- das ging schief, sobald beide Ordner
            % in EINEM Exportlauf entstanden: dann ist der Zeitstempel
            % gleich, und die Dateien unterscheiden sich stattdessen in
            % source und srcSnrStep. Der Zeuge war falsch gewaehlt, die
            % Aussage stimmte.
            dA = gearboxphy.paths.dataDir('SE_data_mux_fixedB');
            dB = gearboxphy.paths.dataDir('SE_data_mux_scaledB');
            a = fullfile(dA, 'SE_4_QAM.mat');
            b = fullfile(dB, 'SE_4_QAM.mat');
            testCase.assumeTrue(isfile(a) && isfile(b), 'Kurvenordner fehlen.');

            % (1) Die Dateien sind NICHT byte-gleich.
            testCase.verifyFalse(isequal(localBytesOf(a), localBytesOf(b)), ...
                ['Die beiden Kurvendateien sind byte-gleich. Dann waere ein ' ...
                 'Datei-Hash als Schluessel brauchbar, und die Begruendung ' ...
                 'fuer +data/fingerprint.m haette sich geaendert.']);

            % (2) Was loadSECurve nach aussen gibt -- und nur das sieht die
            %     Optimierung -- ist identisch.
            cfg = struct('N_t', 1, 'N_r', 1);
            seA = gearboxphy.data.loadSECurve("QAM", 4, cfg, dA, "multiplexing");
            seB = gearboxphy.data.loadSECurve("QAM", 4, cfg, dB, "multiplexing");
            testCase.verifyEqual(seB, seA, ...
                'Die Nutzlast muss identisch sein -- sonst ist es kein Duplikat.');

            % (3) Und damit auch der Fingerabdruck darueber.
            testCase.verifyEqual(gearboxphy.data.fingerprint(seB), ...
                                 gearboxphy.data.fingerprint(seA));
        end

        function analogeVariantenBeiderStudienTeilenDenSchluessel(testCase)
            % FALL 2 aus docs/RESULT_NAMING.md: run_analog_bf_distance und
            % run_dbf_dac_distance rechnen sechs analoge Varianten beide.
            % Seit der Vereinigung des Variablensatzes (Form
            % "abf_analog/v2") muessen sie denselben Schluessel bilden --
            % sonst rechnet die eine Studie weiter, was die andere schon hat.
            %
            % Die zwei Wege unterscheiden sich in den Argumenten:
            % die Analog-Studie ruft bf_arch_scenario mit SECHS Argumenten
            % (Vorgaben fuer DAC- und LNA-Modell), die DAC-Studie mit ACHT
            % (dieselben Modelle, nur ausgeschrieben). Genau das prueft
            % dieser Test: dass die Vorgaben und die ausgeschriebenen Werte
            % wirklich dasselbe Szenario ergeben. Seit 2026-10-15 sind die
            % Vorgaben der neue Satz (DAC survey, LNA fom_floor); vorher
            % fiel bf_arch_scenario auf analytic/fom_bandwidth zurueck.
            CFG = struct('rates', [1e6 1e9], 'distances', logspace(1,4,5), ...
                'fcGHz', 28, 'Ms', [4 64], 'Ns', [1 2 4], 'psBits', 6, ...
                'psPower', NaN, 'psLossDb', NaN);
            testCase.assumeTrue(isfolder(gearboxphy.paths.dataDir("SE_data_bfideal_fixedB")), ...
                'Kurvenordner SE_data_bfideal_fixedB fehlt.');
            cfgs = arrayfun(@(n) struct('N_t', n, 'N_r', n), CFG.Ns, 'UniformOutput', false);
            v = struct('name', "abf_active", 'data', "SE_data_bfideal_fixedB", ...
                'mode', "beamforming", 'arch', "analog", 'ps', "active", ...
                'lo', "", 'loPower', NaN);
            dd = gearboxphy.paths.dataDir(v.data);

            fpAnalogStudie = gearboxphy.data.gridFingerprint("abf_analog/v2", ...
                @(d) bf_arch_scenario(d, CFG, v, dd, "envelope", cfgs), CFG);
            fpDacStudie = gearboxphy.data.gridFingerprint("abf_analog/v2", ...
                @(d) bf_arch_scenario(d, CFG, v, dd, "envelope", cfgs, ...
                    "survey", "fom_floor"), CFG);

            testCase.verifyEqual(fpDacStudie, fpAnalogStudie, ...
                ['Die analogen Varianten der beiden Studien muessen denselben ' ...
                 'Schluessel haben -- sonst bleibt Fall 2 aus RESULT_NAMING.md offen.']);
        end

        function sisoGaengeSindUeberAlleVariantenEinSchluessel(testCase)
            V = ["mux_fixedB" "mux_scaledB" "bf_fixedB" "bf_scaledB" ...
                 "bfideal_fixedB" "bfideal_scaledB"];
            for v = V
                testCase.assumeTrue(isfolder(gearboxphy.paths.dataDir("SE_data_" + v)), ...
                    'Kurvenordner der 3a-Varianten fehlen.');
            end

            [fpZxm, fpQam] = localFingerprintsPerVariant(V);

            % ZXM liest in jeder Variante dieselbe Kurve -> EIN Schluessel.
            testCase.verifyNumElements(unique(fpZxm), 1, ...
                ['Die SISO-Gaenge muessen ueber alle sechs Varianten denselben ' ...
                 'Schluessel haben -- sonst rechnet 3a sie weiter sechsmal.']);

            % QAM ist der eigentliche Vergleich -> sechs verschiedene.
            testCase.verifyNumElements(unique(fpQam), 6, ...
                ['QAM darf NICHT zusammenfallen: das ist der Vergleich, den die ' ...
                 'Studie messen will.']);
        end
    end
end

% =====================================================================
function [fpZxm, fpQam] = localFingerprintsPerVariant(V)
%LOCALFINGERPRINTSPERVARIANT  Je Variante der Schluessel von ZXM (SISO) und
%   QAM M=4 (der Vergleich), auf dem 3a-Raster.
RVec = logspace(3, 11, 100); fc = 28e9;
configs = arrayfun(@(n) struct('N_t', n, 'N_r', n), [1 2 4 8 16], 'UniformOutput', false);
gears = gearboxphy.gears.gearRegistry();
zxm = gears{find(cellfun(@(g) g.name == "ZXM", gears), 1)};
qam = gears{find(cellfun(@(g) g.name == "QAM", gears), 1)};
fpZxm = strings(1, numel(V)); fpQam = strings(1, numel(V));
for i = 1:numel(V)
    oldModels = gearboxphy.sweep.oldModelArgs();   % Modellsatz vor 2026-10-15, damit gespeicherte Ergebnisse gueltig bleiben
    sc = gearboxphy.sweep.makeScenarioConfig(oldModels{:}, 'distance', 50, 'RVec', RVec, 'fcVec', fc, ...
        'antennaMode', "multiplexing", 'qamMimoConfigs', configs, ...
        'dataDir', gearboxphy.paths.dataDir("SE_data_" + V(i)));
    cs = gearboxphy.sweep.resolveScenarioForCarrier(sc, fc);
    op = struct('tolerance', sc.tolerance, 'maxiters', sc.maxiters, ...
                'numtriesPerOpt', sc.numtriesPerOpt);
    fpZxm(i) = localOne(zxm, zxm.orders(1), cs, fc, RVec, op);
    fpQam(i) = localOne(qam, 4, cs, fc, RVec, op);
end
end

function fp = localOne(gear, order, cs, fc, RVec, op)
acs = gear.antennaConfigs(order, cs);
ctxList = cell(1, numel(acs));
for ci = 1:numel(acs), ctxList{ci} = gear.prepare(order, cs, acs{ci}); end
fp = gearboxphy.data.comboFingerprint(gear.name, order, fc, RVec, op, ...
    gear.initialGuess(order, cs), gear.optimizerBounds(order, cs), ctxList);
end

function b = localBytesOf(file)
%LOCALBYTESOF  Roher Dateiinhalt, fuer den Byte-Vergleich.
fid = fopen(file, 'r');
closeIt = onCleanup(@() fclose(fid)); %#ok<NASGU>
b = fread(fid, Inf, '*uint8');
end

function p = frameworkRoot()
p = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
