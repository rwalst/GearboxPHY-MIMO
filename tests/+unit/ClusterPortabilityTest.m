classdef ClusterPortabilityTest < matlab.unittest.TestCase
    %CLUSTERPORTABILITYTEST  Was den Lauf auf einem ZWEITEN Cluster traegt:
    %   das Clusterprofil (+sweep/poolProfile.m), der Worker-Deckel
    %   (+sweep/workerBudget.m) und die Ergebniswurzel
    %   (+paths/resultsDir.m, +paths/isAbsolutePath.m).
    %
    %   DER WICHTIGSTE TEST IST pfadeOhneVariableUnveraendert. Die
    %   Umlenkung ueber GEARBOXPHY_RESULTS_ROOT fasst alle 47 Aufrufstellen
    %   von resultsDir an, auch die lesenden. Wenn bei UNGESETZTER Variable
    %   ein anderer Pfad entsteht als vorher, findet jede Auswertung ihre
    %   73 MB Ergebnisse nicht mehr -- und zwar wortlos, denn ein fehlender
    %   Ordner sieht wie ein noch nicht gerechneter Lauf aus.
    %
    %   Alle Tests hier setzen Umgebungsvariablen und raeumen sie per
    %   addTeardown zurueck; sonst traegt die Suite ihren eigenen Zustand
    %   von Testdatei zu Testdatei weiter.

    methods (TestClassSetup)
        function addPaths(testCase)
            %ADDPATHS  Repo-Wurzel auf den Pfad -- aber nur, wenn sie noch
            %   nicht darauf liegt, und nur dann wieder herunter.
            %
            %   WARUM DIE PRUEFUNG: addpath auf einen schon vorhandenen Pfad
            %   legt ihn nur nach vorn, rmpath entfernt ihn danach GANZ. Ein
            %   bedingungsloses addpath/rmpath-Paar nimmt dem Rest der Suite
            %   also den Pfad weg, den setupGearboxPath gesetzt hat. Bei den
            %   aelteren Testdateien (GearsTest, OperatingPointTest,
            %   PhysicsTest) fiel das nie auf, weil sie alphabetisch am Ende
            %   stehen; diese Datei liegt vor DacCapTest, und ohne die
            %   Pruefung scheitern dort alle sieben Tests.
            root = frameworkRoot();
            if ~any(strcmp(strsplit(path, pathsep), root))
                addpath(root);
                testCase.addTeardown(@() rmpath(root));
            end
        end
    end

    methods (Test)
        % ---------- Pfade ----------
        function pfadeOhneVariableUnveraendert(testCase)
            testCase.applyEnv('GEARBOXPHY_RESULTS_ROOT', '');
            r = gearboxphy.paths.root();
            testCase.verifyEqual(gearboxphy.paths.resultsDir(), ...
                fullfile(r, 'results'));
            testCase.verifyEqual(gearboxphy.paths.resultsDir("cmp_mux_fixedB_d50"), ...
                fullfile(r, 'results', 'cmp_mux_fixedB_d50'));
        end

        function variableVerlegtDieWurzel(testCase)
            ws = fullfile(tempdir, 'ws_gearbox', 'results');
            testCase.applyEnv('GEARBOXPHY_RESULTS_ROOT', ws);
            testCase.verifyEqual(gearboxphy.paths.resultsDir(), ws);
            testCase.verifyEqual(gearboxphy.paths.resultsDir("cmp_x.mat"), ...
                fullfile(ws, 'cmp_x.mat'));
        end

        function kurvenordnerBleibtImRepo(testCase)
            % Die Kurven unter data/ sind versioniert und kommen per git auf
            % den Cluster -- die Ergebnisvariable darf sie NICHT mitnehmen.
            testCase.applyEnv('GEARBOXPHY_RESULTS_ROOT', fullfile(tempdir, 'ws_gearbox'));
            testCase.verifyEqual(gearboxphy.paths.dataDir("SE_data_mux_fixedB"), ...
                fullfile(gearboxphy.paths.root(), 'data', 'SE_data_mux_fixedB'));
        end

        function absoluterPfadGehtDurch(testCase)
            % Tests und Exporte zeigen in temporaere Ordner; das muss trotz
            % Umlenkung weiter ungebrochen durchgehen.
            testCase.applyEnv('GEARBOXPHY_RESULTS_ROOT', fullfile(tempdir, 'ws_gearbox'));
            abs1 = fullfile(tempdir, 'irgendwo');
            testCase.verifyEqual(gearboxphy.paths.resultsDir(string(abs1)), abs1);
            testCase.verifyEqual(gearboxphy.paths.dataDir(string(abs1)), abs1);
        end

        function isAbsolutePathBeidePlattformen(testCase)
            % Der Fehler, den das behebt: die Erkennung lief ueber filesep,
            % also je Plattform einseitig. Unter Linux galt "C:\..." nicht
            % als absolut, unter Windows nicht "/data/horse/...". Seit beide
            % Cluster benutzt werden, sind beide Formen gleichzeitig im Umlauf.
            f = @gearboxphy.paths.isAbsolutePath;
            testCase.verifyTrue(f('/data/horse/ws/gearbox'));
            testCase.verifyTrue(f('\\fileserver\share\x'));
            testCase.verifyTrue(f('C:\Users\x'));
            testCase.verifyTrue(f('\wurzelrelativ'));
            testCase.verifyFalse(f('SE_data_mux_fixedB'));
            testCase.verifyFalse(f(''));
        end

        function absoluteDirUnveraendertInDerWirkung(testCase)
            % +data/absoluteDir ruft jetzt isAbsolutePath auf statt die
            % Pruefung selbst zu fuehren. Die Checkpoint-Pfade haengen daran.
            testCase.verifyEqual(gearboxphy.data.absoluteDir('/data/horse/x'), "/data/horse/x");
            testCase.verifyEqual(gearboxphy.data.absoluteDir('C:\x'), "C:\x");
            rel = gearboxphy.data.absoluteDir('results/x');
            testCase.verifyTrue(gearboxphy.paths.isAbsolutePath(rel));
        end

        % ---------- Clusterprofil ----------
        function variableSchlaegtAllesAndere(testCase)
            % Der Notausgang: ein Cluster, dessen Profil anders heisst als
            % alles, was hier vorgesehen ist, braucht keine Codeaenderung.
            testCase.applyEnv('GEARBOXPHY_CLUSTER_PROFILE', 'IrgendeinProfil');
            testCase.applyEnv('SLURM_JOB_ID', '1234567');
            [p, src] = gearboxphy.sweep.poolProfile();
            testCase.verifyEqual(p, "IrgendeinProfil");
            testCase.verifyEqual(src, "GEARBOXPHY_CLUSTER_PROFILE");
        end

        function leereVariableWirdIgnoriert(testCase)
            % Eine gesetzte, aber leere Variable (haeufig in Jobskripten)
            % darf nicht als Profilname "" durchgehen -- parpool("") waere
            % ein Fehler ohne erkennbare Ursache.
            testCase.applyEnv('GEARBOXPHY_CLUSTER_PROFILE', '   ');
            testCase.applyEnv('SLURM_JOB_ID', '');
            p = gearboxphy.sweep.poolProfile();
            testCase.verifyGreaterThan(strlength(p), 0);
            testCase.verifyNotEqual(p, "   ");
        end

        % ---------- Worker-Deckel ----------
        function deckelGreiftUndWarnt(testCase)
            % Der konkrete Fall: runSweep verlangt min(400, 200) = 200
            % Worker, ein Barnard-Knoten hat 104.
            testCase.applyEnv('SLURM_CPUS_PER_TASK', '104');
            [w, cap, src] = testCase.verifyWarning( ...
                @() gearboxphy.sweep.workerBudget(200), 'gearboxphy:sweep:workerCap');
            testCase.verifyEqual(w, 104);
            testCase.verifyEqual(cap, 104);
            testCase.verifyEqual(src, "SLURM_CPUS_PER_TASK");
        end

        function deckelLaesstPassendenWunschDurch(testCase)
            % Die drei Distanzstudien wollen 25 Worker -- die muessen ohne
            % Warnung durchgehen, sonst ist jede Logdatei voll davon.
            testCase.applyEnv('SLURM_CPUS_PER_TASK', '104');
            w = testCase.verifyWarningFree(@() gearboxphy.sweep.workerBudget(25));
            testCase.verifyEqual(w, 25);
        end

        function deckelNimmtDieSlurmZahlNichtDieKernzahl(testCase)
            % feature('numcores') meldet in einem SLURM-Job den GANZEN
            % Knoten, nicht die zugeteilten Kerne. Wer die Zahl nimmt,
            % ueberbucht auf einem geteilten Knoten um ein Vielfaches.
            %
            % Geprueft wird deshalb, dass der Deckel die SLURM-Zahl nimmt,
            % AUCH wenn sie von der Kernzahl dieser Maschine abweicht --
            % genau das ist der Fall auf einem Knoten mit cgroup.
            kerne = double(feature('numcores'));
            fremd = kerne + 7;                 % garantiert != kerne
            testCase.applyEnv('SLURM_CPUS_PER_TASK', num2str(fremd));
            [~, cap, src] = testCase.verifyWarning( ...
                @() gearboxphy.sweep.workerBudget(fremd + 100), 'gearboxphy:sweep:workerCap');
            testCase.verifyEqual(cap, fremd);
            testCase.verifyNotEqual(cap, kerne);
            testCase.verifyEqual(src, "SLURM_CPUS_PER_TASK");
        end
    end

    methods (Access = private)
        function applyEnv(testCase, name, value)
            %APPLYENV  Variable fuer die Dauer EINES Tests setzen.
            alt = getenv(name);
            setenv(name, value);
            testCase.addTeardown(@() setenv(name, alt));
        end
    end
end

function p = frameworkRoot()
%FRAMEWORKROOT  Der Ordner dieses Repos, abgeleitet aus dem Ort DIESER Datei.
%   Wie in GearsTest/OperatingPointTest: lokale Funktionen einer
%   classdef-Datei sind auch aus den Methoden aufrufbar.
p = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
