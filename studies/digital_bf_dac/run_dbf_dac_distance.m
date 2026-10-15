function run_dbf_dac_distance(over)
%RUN_DBF_DAC_DISTANCE  Digitales Beamforming MIT DAC-Quantisierung gegen
%   analoges Beamforming: zwei feste Raten, Sweep ueber die Distanz, je
%   DAC-Stufe eine Kurve, drei DAC-Leistungsmodelle.
%
%   Aufruf: in GearboxPHY-MIMO/ einfach
%       setupGearboxPath; run_dbf_dac_distance
%   Vorher: export_dbf_dac_curves (und davor in QuantizedMimoMI
%   runQamSweepBfIdealDac, spaeter runQamSweepBfRayleighDac).
%
%   RESSOURCEN: 25 Worker, 64 GB, 24 h anfordern. Ein Knoten.
%   parfor ueber die 25 Distanzen; mehr als 25 Worker bringen nichts.
%
%   ZEITBEDARF, hochgerechnet am 2026-10-15 (nicht auf dem Cluster
%   gemessen): 315 Faelle x 1000 Optimierungen = 315 000, bei 0.169 s je
%   Optimierung rund 15 Kernstunden, auf 25 Workern etwa 36 min. Die
%   0.169 s sind an einem Mini-Raster gemessen (2 Distanzen, M = 4/16,
%   N = 1/2, ein Kanal, ein DAC-Modell, seriell: 336 Optimierungen in
%   56.9 s) und damit eine OBERE Schranke -- dort verteilt sich der Aufbau
%   des Szenarios je Distanz auf 4 Zellen statt auf 20.
%
%   Die 24 h bleiben als Anforderung stehen: zu wenig Walltime killt den
%   Job, zu viel kostet nur Warteschlangenpriorität. Laeuft es dagegen
%   zehnmal laenger als die 36 min, stimmt etwas nicht -- dann zuerst die
%   Checkpoint- und Dateiebene ansehen, nicht die Optimierung.
%
%   Fertige Dateien werden uebersprungen (SKIP_EXISTING): nach einem
%   Abbruch einfach noch einmal starten. Bei den analogen Varianten
%   entscheidet seit 2026-10-15 der Fingerabdruck darueber
%   (+data/fingerprintMatches.m) -- localDone konnte das dort nie.
%
%   ZIH-Cluster statt Windows: sbatch hpc/zih/submit_study.sbatch run_dbf_dac_distance
%   mit --cpus-per-task=26 (einer fuer den Client). Anleitung und
%   Schritt 0: docs/HPC_RUNBOOK_ZIH.md.
%
%   STUDIE studies/digital_bf_dac: was kostet die endliche DAC-Aufloesung das
%   digitale Beamforming. Die analogen Varianten laufen nur als Vergleich
%   mit (studies/analog_bf ist die Studie dazu). Uebersicht: README.md in
%   diesem Ordner.
%
%   WAS GERECHNET WIRD (alles QAM, 28 GHz, ADC-Modell "envelope", ADC-Regel
%   fixedB; Raster wie run_analog_bf_distance):
%     Kanal    "losd" (Rang 1, ein ADC je Empfangsantenne), "los" (Rang 1,
%              Kombinieren vor EINEM ADC) und "ray" (Rayleigh) -- jeweils
%              sobald die Kurvenordner existieren
%     LO       loShared und lo12p5mW (LO-Puffer je zusaetzlichem Mischer)
%     DAC-Leistungsmodell (makeScenarioConfig 'dacPowerModel'):
%              "analytic" (3 V, Stand des Codes), "analytic_1V"
%              (Dissertation Kap. 5/6), "survey" (DAC-Uebersicht)
%     Zusaetzlich waehlbar: "hw_new" -- die survey-gestuetzten Modelle fuer
%              LNA, ADC und DAC zusammen (localHw). Nicht in der Vorgabe;
%              run_dbf_dac_los_newhw.m rechnet damit den LOS-Vergleich.
%   Je (Kanal, LO, DAC-Modell) eine Datei mit der DIGITALEN Seite:
%     Eideal   Kurve mit idealem DAC, bezahlt 1/2*log2(M)
%              (SE_data_bflosd_fixedB, SE_data_bfideal_fixedB bzw.
%              SE_data_bf_fixedB)
%     E        Kurven mit DAC-Quantisierung, letzte Dimension = DAC-Stufe
%              (SE_data_..._dac<k>), der DAC bezahlt sourceBdac. Diese
%              Kurven sind beim Export an der Ideal-DAC-Kurve GEDECKELT
%              (Entscheidung E4, capDacCurvesAgainstIdeal) -- ohne das
%              liegt eine groebere Stufe stellenweise ueber der feineren,
%              und minOverDacLevels waehlte sie dann genau deswegen.
%     Ebest    Minimum ueber die Stufen (gearboxphy.sweep.minOverDacLevels),
%     kBest    Index der gewaehlten Stufe
%     Ecommon  Vergleichsfall gemeinsame Aussteuerung, soweit Ordner
%              ..._dac<k>_common existieren
%   Je (analoge Variante, DAC-Modell) eine Datei: der analoge Sender hat
%   EINEN DAC mit ungedrehtem Symbol und zahlt immer 1/2*log2(M); er wird
%   mitgerechnet, weil das DAC-Leistungsmodell auch ihn trifft.
%
%   AUSGABE:
%     results/dbfdac_distance_<kanal>_<lo>_<dacModell>.mat
%     results/abfdac_distance_<variante>_<dacModell>.mat
%   Felder J/bit: E, Etx, Erx, Epa, Edac (NaN = unerreichbar), dazu CFG,
%   dacLevels, dacModel und die Szenario-Einstellungen.
%
%   over (optional): struct, dessen Felder gleichnamige Einstellungen
%   unten ersetzen (nur fuer Tests gedacht, z.B. ein kleines Raster).

%% ===================== CONFIG =====================================
P.N_WORKERS     = 25;                   % feste Poolgroesse
P.rates         = [1e6 1e9];            % niedrig / hoch [bit/s]
P.distances     = logspace(1, 4, 25);   % 10 m .. 10 km
P.fcGHz         = 28;
P.Ms            = [4 16 64 256];
P.Ns            = [1 2 4 8 16];
P.psBits        = 6;
P.psPower       = NaN;                  % NaN = Vorgabe aus phaseShifterParams
P.psLossDb      = NaN;
P.DAC_LEVELS    = [0 1 2 3];            % Bit ueber 1/2*log2(M)
P.DAC_MODELS    = ["analytic" "analytic_1V" "survey"];   % auch "hw_new", siehe localHw
P.ADC_MODEL     = "envelope";
P.CHANNELS      = "";                   % "" = alle; sonst z.B. "losd" oder ["losd" "ray"]
P.LO_NAMES      = ["loShared" "lo12p5mW"];
P.LO_POWER      = [NaN 12.5e-3];        % [W] je zusaetzlichem Mischer, NaN = gemeinsamer LO
P.RESULT_PREFIX = "";                   % nur fuer Tests
P.SKIP_EXISTING = true;
%% ===================================================================
if nargin >= 1 && isstruct(over)
    for f = fieldnames(over).'
        assert(isfield(P, f{1}), 'run_dbf_dac_distance:over', 'Unbekannte Einstellung "%s".', f{1});
        P.(f{1}) = over.(f{1});
    end
end
CFG = struct('rates', P.rates, 'distances', P.distances, 'fcGHz', P.fcGHz, 'Ms', P.Ms, 'Ns', P.Ns, ...
             'psBits', P.psBits, 'psPower', P.psPower, 'psLossDb', P.psLossDb);

% ---- Kanaele: Ordner der digitalen Seite und der analogen Varianten ----
%   "losd" ist die LOS-Referenz mit dem Empfaenger des digitalen Beamformings
%   (ein ADC je Antenne, runQamSweepBfLosDigitalDac). "los" kombiniert vor
%   EINEM ADC -- das ist der analoge Empfaenger; als digitale Referenz ist
%   es eine Vereinfachung, die Kurven beschreiben "Sender digital,
%   Empfaenger analog". Die analogen Varianten sind fuer beide dieselben.
% RICE-KANAELE ray3/ray30 ergaenzt (2026-10-12): die DAC-Quantisierung war
% nur bei K = 0 und in den beiden LOS-Grenzfaellen gerechnet, der
% Schnittpunkt K* damit nur fuer einen idealen Sender-DAC bestimmt. Ihre
% Ordner entstehen aus runQamSweepRiceBfDac und export_dbf_dac_curves;
% solange sie fehlen, findet die lev-Erkennung unten nichts und der Kanal
% wird uebersprungen -- der Lauf bricht also nicht ab, wenn nur der
% K=0-Teil vorliegt.
CH = struct( ...
  'name',       {"losd", "los", "ray", "ray3", "ray30"}, ...
  'digBase',    {"SE_data_bflosd_fixedB", "SE_data_bfideal_fixedB", "SE_data_bf_fixedB", ...
                 "SE_data_bf_fixedB_K3", "SE_data_bf_fixedB_K30"}, ...
  'anaData',    {"SE_data_bfideal_fixedB", "SE_data_bfideal_fixedB", "SE_data_abf_fixedB", ...
                 "SE_data_abf_fixedB_K3", "SE_data_abf_fixedB_K30"}, ...
  'anaMode',    {"beamforming", "beamforming", "multiplexing", "multiplexing", "multiplexing"}, ...
  'anaPrefix',  {"abf", "abf", "abfray", "abfray3", "abfray30"});
PS_NAMES = ["active" "passive_comp" "passive_pen"];
PS_TYPES = ["active" "passive_compensated" "passive_penalty"];

nWorkers = localPool(P.N_WORKERS);

for ch = CH
    if ~all(P.CHANNELS == "") && ~any(P.CHANNELS == ch.name), continue; end
    % vorhandene DAC-Stufen dieses Kanals
    lev = []; levCommon = [];
    for k = P.DAC_LEVELS
        if isfolder(gearboxphy.paths.dataDir(sprintf("%s_dac%d", ch.digBase, k))), lev(end+1) = k; end %#ok<AGROW>
        if isfolder(gearboxphy.paths.dataDir(sprintf("%s_dac%d_common", ch.digBase, k))), levCommon(end+1) = k; end %#ok<AGROW>
    end
    if isempty(lev)
        fprintf('\n%s: keine Ordner %s_dac<k> -- Kanal uebersprungen (erst export_dbf_dac_curves).\n', ...
                ch.name, ch.digBase);
        continue
    end
    % common ist seit 2026-10-12 der Standardfall und damit die Pflichtachse.
    if isempty(levCommon)
        fprintf('\n%s: keine Ordner %s_dac<k>_common -- Kanal uebersprungen. Der Standardfall\n', ...
                ch.name, ch.digBase);
        fprintf('  ist die gemeinsame Aussteuerung; ohne sie gibt es nichts zu rechnen.\n');
        continue
    end
    % LAUT MELDEN, WENN DER STANDARD WENIGER STUFEN HAT ALS DER VERGLEICH.
    % Sonst sieht ein Ergebnis mit einer einzigen DAC-Stufe wie ein voller
    % Sweep aus. Die fehlenden Ordner entstehen in QuantizedMimoMI mit
    % DAC_OFFSETS_COMMON = [0 1 2 3] (runQamSweepBfRayleighDac,
    % runQamSweepBfLosDigitalDac).
    fehlt = setdiff(lev, levCommon);
    if ~isempty(fehlt)
        warning('run_dbf_dac_distance:commonIncomplete', ...
            ['%s: der Standardfall (gemeinsame Aussteuerung) liegt nur fuer die Stufen %s vor, ' ...
             'der Vergleich fuer %s. Es fehlen %s_dac{%s}_common -- erst in QuantizedMimoMI ' ...
             'mit DAC_OFFSETS_COMMON = [0 1 2 3] rechnen, sonst ist dieses Ergebnis kein ' ...
             'vollstaendiger Sweep.'], ch.name, mat2str(levCommon), mat2str(lev), ...
            ch.digBase, strjoin(string(fehlt), ','));
    end
    assert(isfolder(gearboxphy.paths.dataDir(ch.digBase)), 'run_dbf_dac_distance:noData', ...
        '%s fehlt - die Kurven mit idealem DAC gehoeren dazu (Export wiederholen).', ch.digBase);

    for hwName = P.DAC_MODELS
        % hwName benennt die Ergebnisdatei; hw traegt die drei Schalter dazu.
        hw = localHw(hwName, P.ADC_MODEL); dacModel = hwName;
        % ---------------- digitale Seite ----------------
        for li = 1:numel(P.LO_NAMES)
            outFile = gearboxphy.paths.resultsDir(sprintf('%sdbfdac_distance_%s_%s_%s.mat', ...
                P.RESULT_PREFIX, ch.name, P.LO_NAMES(li), dacModel));
            if P.SKIP_EXISTING && localDone(outFile, CFG, lev, levCommon)
                fprintf('\n======== %s liegt vor, uebersprungen ========\n', outFile);
                continue
            end
            fprintf('\n======== digital, %s / %s / %s ========\n', ch.name, P.LO_NAMES(li), dacModel);
            t0 = tic;
            v = struct('name', "dbf", 'data', ch.digBase, 'mode', "multiplexing", 'arch', "digital", ...
                       'ps', "active", 'lo', "", 'loPower', NaN);
            if ~isnan(P.LO_POWER(li)), v.lo = "per_mixer"; v.loPower = P.LO_POWER(li); end

            % WIEDERVERWENDEN STATT NEU RECHNEN -- siehe +data/gridFingerprint.m.
            % Eine Datei deckt hier MEHRERE Kurvenordner ab (idealer DAC und
            % je Stufe einen), deshalb ein Teil-Fingerabdruck je Ordner und
            % darueber einer. Die Form steht im Schluessel, damit eine Datei
            % der digitalen Seite nie fuer eine der analogen gehalten wird.
            dataNames = [string(ch.digBase), ...
                arrayfun(@(k) sprintf("%s_dac%d_common", ch.digBase, k), levCommon), ...
                arrayfun(@(k) sprintf("%s_dac%d", ch.digBase, k), lev)];
            fp = localGridFp("dbfdac_distance_digital/v1", CFG, v, hw, dataNames);
            if gearboxphy.data.fetchFromStore(fp, outFile)
                fprintf('   schon gerechnet (%s) -- uebernommen\n', fp);
                continue
            end

            R0 = localCase(CFG, v, hw, nWorkers);
            Eideal = R0.E; EidealDac = R0.Edac; EidealPa = R0.Epa;
            SEideal = R0.SE; SNRrxideal_dB = R0.SNRrx_dB;

            % STANDARD IST DIE GEMEINSAME AUSSTEUERUNG (2026-10-12): E,
            % Ebest und kBest kommen aus den _common-Ordnern. Die
            % Aussteuerung je Antenne setzt hinter jedem DAC eine stufenlos
            % einstellbare Verstaerkung voraus, die im Energiebudget
            % niemand bezahlt -- sie bleibt als Eper daneben stehen und
            % zeigt, was sie wert waere. Bis 2026-10-12 war es umgekehrt;
            % Dateien ohne das Feld dacScaleStandard stammen von davor.
            [E, Etx, Erx, Epa, Edac, SE, SNRrx_dB] = localLevels(CFG, v, ch.digBase, levCommon, "_common", hw, nWorkers);
            [Ebest, kBest, EbestDac, EbestPa] = gearboxphy.sweep.minOverDacLevels(E, Edac, Epa);
            S = struct('E', E, 'Etx', Etx, 'Erx', Erx, 'Epa', Epa, 'Edac', Edac, ...
                       'Eideal', Eideal, 'EidealDac', EidealDac, 'EidealPa', EidealPa, ...
                       'Ebest', Ebest, 'kBest', kBest, 'EbestDac', EbestDac, 'EbestPa', EbestPa, ...
                       'SE', SE, 'SNRrx_dB', SNRrx_dB, ...
                       'SEideal', SEideal, 'SNRrxideal_dB', SNRrxideal_dB, ...
                       'dacLevels', levCommon, 'dacLevelsPer', lev, 'dacScaleStandard', "common", ...
                       'CFG', CFG, ...
                       'channel', ch.name, 'lo', P.LO_NAMES(li), 'dacModel', dacModel, 'hw', hw, 'v', v);
            [S.Eper, ~, ~, S.EperPa, S.EperDac, S.SEper, S.SNRrxper_dB] = ...
                localLevels(CFG, v, ch.digBase, lev, "", hw, nWorkers);
            S.resultFingerprint = fp;
            save(outFile, '-struct', 'S');
            gearboxphy.data.publishToStore(fp, outFile);
            fprintf('fertig nach %.1f min -> %s\n', toc(t0)/60, outFile);
        end

        % ---------------- analoge Varianten ----------------
        if ~isfolder(gearboxphy.paths.dataDir(ch.anaData))
            fprintf('\n%s fehlt -- analoge Varianten fuer "%s" uebersprungen.\n', ch.anaData, ch.name);
            continue
        end
        for pi_ = 1:numel(PS_NAMES)
            vname = sprintf("%s_%s", ch.anaPrefix, PS_NAMES(pi_));
            outFile = gearboxphy.paths.resultsDir(sprintf('%sabfdac_distance_%s_%s.mat', ...
                P.RESULT_PREFIX, vname, dacModel));
            % localDone WAR HIER WIRKUNGSLOS: es verlangt die Felder
            % dacLevelsPer und dacScaleStandard, die eine analoge Datei nie
            % hatte (sie trug dacLevels/dacLevelsCommon). Die analogen
            % Varianten wurden deshalb bei JEDEM Lauf neu gerechnet, obwohl
            % SKIP_EXISTING an war. Der Schluessel ist die bessere Pruefung:
            % er deckt Raster, Modelle UND Kurveninhalt ab.
            v = struct('name', vname, 'data', ch.anaData, 'mode', ch.anaMode, 'arch', "analog", ...
                       'ps', PS_TYPES(pi_), 'lo', "", 'loPower', NaN);
            % Form "abf_analog/v2": derselbe Variablensatz wie
            % studies/analog_bf/run_analog_bf_distance.m, damit der
            % Ergebnisspeicher die Dateien gegeneinander liefern kann --
            % es ist dieselbe Rechnung (docs/RESULT_NAMING.md, Fall 2).
            % DIREKT gridFingerprint, nicht localGridFp: der Mehrordner-Weg
            % hasht erst je Ordner und dann darueber, was einen anderen
            % Schluessel ergibt als der einstufige Weg in
            % run_analog_bf_distance. Nur derselbe Weg gibt denselben
            % Schluessel -- und genau darauf beruht die Wiederverwendung.
            fp = gearboxphy.data.gridFingerprint("abf_analog/v2", ...
                @(d) bf_arch_scenario(d, CFG, v, gearboxphy.paths.dataDir(v.data), ...
                    hw.adc, arrayfun(@(n) struct('N_t', n, 'N_r', n), CFG.Ns, ...
                        'UniformOutput', false), hw.dac, hw.lna), CFG);
            if P.SKIP_EXISTING && gearboxphy.data.fingerprintMatches(string(outFile), fp)
                fprintf('\n======== %s liegt vor (gleicher Schluessel), uebersprungen ========\n', outFile);
                continue
            end
            fprintf('\n======== analog, %s / %s ========\n', vname, dacModel);
            t0 = tic;
            if gearboxphy.data.fetchFromStore(fp, outFile)
                fprintf('   schon gerechnet (%s) -- uebernommen\n', fp);
                continue
            end
            S = localCase(CFG, v, hw, nWorkers);   % traegt SE/SNRrx_dB/Eadc/Eps schon als Felder
            S.CFG = CFG; S.variant = vname; S.v = v;
            S.adcModel = hw.adc; S.dacModel = dacModel; S.hw = hw;
            % channel, dacLevels und dacLevelsCommon stehen hier NICHT mehr.
            % channel war irrefuehrend: die Kanaele "losd" und "los" haben
            % dieselben anaData/anaMode/anaPrefix, erzeugen also dieselbe
            % Datei -- das Feld haette je nach Reihenfolge "losd" oder "los"
            % enthalten. Die DAC-Stufen sind fuer einen analogen Sender mit
            % EINEM DAC ohnehin leer.
            S.resultFingerprint = fp;
            save(outFile, '-struct', 'S');
            gearboxphy.data.publishToStore(fp, outFile);
            fprintf('fertig nach %.1f min -> %s\n', toc(t0)/60, outFile);
        end
    end
end
end

function [E, Etx, Erx, Epa, Edac, SE, SNRrx_dB] = localLevels(CFG, v, base, levels, suffix, hw, nWorkers)
%LOCALLEVELS  Dieselbe Variante fuer jede DAC-Stufe; letzte Dimension = Stufe.
nK = numel(levels);
sz = [numel(CFG.distances), numel(CFG.rates), numel(CFG.Ms), numel(CFG.Ns)];
E = nan([sz nK]); Etx = E; Erx = E; Epa = E; Edac = E; SE = E; SNRrx_dB = E;
for i = 1:nK
    vk = v; vk.data = sprintf("%s_dac%d%s", base, levels(i), suffix);
    fprintf('  -- DAC-Stufe +%d%s (%s)\n', levels(i), suffix, vk.data);
    R = localCase(CFG, vk, hw, nWorkers);
    E(:,:,:,:,i) = R.E; Etx(:,:,:,:,i) = R.Etx; Erx(:,:,:,:,i) = R.Erx;
    Epa(:,:,:,:,i) = R.Epa; Edac(:,:,:,:,i) = R.Edac;
    SE(:,:,:,:,i) = R.SE; SNRrx_dB(:,:,:,:,i) = R.SNRrx_dB;
end
end

function R = localCase(CFG, v, hw, nWorkers)
%LOCALCASE  Eine Variante ueber alle Distanzen (parfor), Felder [nD nR nM nN].
nD = numel(CFG.distances); nR = numel(CFG.rates); nM = numel(CFG.Ms); nN = numel(CFG.Ns);
dataDir = gearboxphy.paths.dataDir(v.data);
E = nan(nD, nR, nM, nN); Etx = E; Erx = E; Epa = E; Edac = E; Eadc = E; Eps = E; SE = E; SNRrx = E;
dists = CFG.distances;
parfor (di = 1:nD, nWorkers)
    [e, etx, erx, epa, edac, eadc, eps_, se, snr] = localOneDistance(dists(di), CFG, v, dataDir, hw);
    E(di,:,:,:)     = reshape(e,    [1 nR nM nN]);
    Etx(di,:,:,:)   = reshape(etx,  [1 nR nM nN]);
    Erx(di,:,:,:)   = reshape(erx,  [1 nR nM nN]);
    Epa(di,:,:,:)   = reshape(epa,  [1 nR nM nN]);
    Edac(di,:,:,:)  = reshape(edac, [1 nR nM nN]);
    Eadc(di,:,:,:)  = reshape(eadc, [1 nR nM nN]);
    Eps(di,:,:,:)   = reshape(eps_, [1 nR nM nN]);
    SE(di,:,:,:)    = reshape(se,   [1 nR nM nN]);
    SNRrx(di,:,:,:) = reshape(snr,  [1 nR nM nN]);
end
R = struct('E', E, 'Etx', Etx, 'Erx', Erx, 'Epa', Epa, 'Edac', Edac, ...
           'Eadc', Eadc, 'Eps', Eps, 'SE', SE, 'SNRrx_dB', SNRrx);
end

function [E, Etx, Erx, Epa, Edac, Eadc, Eps, SE, SNRrx_dB] = localOneDistance(d, CFG, v, dataDir, hw)
%LOCALONEDISTANCE  Alle (Rate, M, N) bei einer Distanz, auf einem Worker.
%   Wie in run_analog_bf_distance, zusaetzlich der DAC-Anteil.
nR = numel(CFG.rates); nM = numel(CFG.Ms); nN = numel(CFG.Ns);
E = nan(nR, nM, nN); Etx = E; Erx = E; Epa = E; Edac = E; Eadc = E; Eps = E;
% ARBEITSPUNKT JE ZELLE: wo der Gang diesen Punkt betreibt. Ohne das sind
% im Ergebnis nur die Energien, nicht die Spektraleffizienz und der noetige
% SNR -- die waren nach dem Lauf nicht mehr rekonstruierbar.
SE = E; SNRrx_dB = E;
fc = CFG.fcGHz * 1e9;
configs = arrayfun(@(n) struct('N_t', n, 'N_r', n), CFG.Ns, 'UniformOutput', false);
scen = bf_arch_scenario(d, CFG, v, dataDir, hw.adc, configs, hw.dac, hw.lna);
cs = gearboxphy.sweep.resolveScenarioForCarrier(scen, fc);
op = struct('tolerance', scen.tolerance, 'maxiters', scen.maxiters, 'numtriesPerOpt', scen.numtriesPerOpt);
gear = gearboxphy.gears.qamGear();
TXF = {'PA','DAC','LO_Tx','Mix_Tx'}; RXF = {'LNA','LO_Rx','Mix_Rx','ADC'};
for mi = 1:nM
    M = CFG.Ms(mi);
    cfgs = gear.antennaConfigs(M, cs);
    x0 = gear.initialGuess(M, cs); bnds = gear.optimizerBounds(M, cs);
    for c = 1:numel(cfgs)
        ni = find(CFG.Ns == cfgs{c}.N_t, 1);
        if isempty(ni), continue; end
        ctx = gear.prepare(M, cs, cfgs{c});
        for ri = 1:nR
            % opPt, nicht op: op ist hier schon die Optimierer-Parameter.
            [e, ~, ~, pb, opPt] = gearboxphy.sweep.optimizeOnePoint(gear, ctx, CFG.rates(ri), x0, bnds, op);
            E(ri, mi, ni) = e;
            SE(ri, mi, ni) = opPt.SE; SNRrx_dB(ri, mi, ni) = opPt.SNR_rx_dB;
            if isstruct(pb)
                Etx(ri, mi, ni)  = sum(cellfun(@(n) pb.(n), TXF));
                Erx(ri, mi, ni)  = sum(cellfun(@(n) pb.(n), RXF));
                if isfield(pb, 'PS_Tx')
                    Etx(ri, mi, ni) = Etx(ri, mi, ni) + pb.PS_Tx;
                    Erx(ri, mi, ni) = Erx(ri, mi, ni) + pb.PS_Rx;
                end
                Epa(ri, mi, ni)  = pb.PA;
                Edac(ri, mi, ni) = pb.DAC;
                % Eadc und Eps gehoeren mit in die Datei: die analogen
                % Varianten dieser Studie sind dieselbe Rechnung wie
                % studies/analog_bf (docs/RESULT_NAMING.md, Fall 2), und
                % austauschbar sind zwei Dateien nur mit demselben
                % Variablensatz. Fuer die digitale Seite kostet es nichts --
                % die Zahlen stehen beide in pb.
                Eadc(ri, mi, ni) = pb.ADC;
                if isfield(pb, 'PS_Tx')
                    Eps(ri, mi, ni) = pb.PS_Tx + pb.PS_Rx;
                else
                    Eps(ri, mi, ni) = 0;
                end
            end
        end
    end
end
end

function hw = localHw(name, adcDefault)
%LOCALHW  Modellsatz zu einem Namen aus P.DAC_MODELS.
%   "analytic", "analytic_1V", "survey": NUR das DAC-Leistungsmodell wechselt,
%       LNA und ADC bleiben bei den Modellen der Dissertation (fom_bandwidth,
%       P.ADC_MODEL). So sind alle bisherigen Ergebnisdateien gerechnet.
%   "hw_new": die survey-gestuetzten Modelle fuer alle drei Komponenten --
%       LNA "envelope", ADC "quantile5", DAC "survey". Das ist der Satz, den
%       der Sammelschalter hardwareModel = "new" setzt
%       (docs/HARDWARE_MODEL_SWITCH.md, Zweig worktree-hardware-model-switch);
%       hier ueber die drei Einzelschalter, damit es ohne den Zweig laeuft.
%   PA, LO und Mischer sind in beiden Faellen dieselben.
switch string(name)
    case {"analytic", "analytic_1V", "survey"}
        hw = struct('name', string(name), 'lna', "fom_bandwidth", 'adc', string(adcDefault), 'dac', string(name));
    case "hw_new"
        hw = struct('name', "hw_new", 'lna', "envelope", 'adc', "quantile5", 'dac', "survey");
    otherwise
        error('run_dbf_dac_distance:hw', 'Unbekannter Modellsatz "%s".', string(name));
end
end

function nWorkers = localPool(nWanted)
%LOCALPOOL  Vorhandenen Pool nutzen (nie schliessen), sonst einen mit
%   nWanted Workern oeffnen; gelingt das nicht, seriell rechnen.
%
%   nWanted wird an das gedeckelt, was die Maschine hergibt
%   (+sweep/workerBudget.m), und das Profil kommt aus +sweep/clusterFor.m --
%   P.N_WORKERS ist auf den Windows-Cluster gemuenzt und laege auf einem
%   ZIH-Knoten ueber der Kernzahl.
nWorkers = 0;
if isempty(ver('parallel')) || nWanted < 1
    fprintf('Kein Pool -- parfor laeuft seriell.\n');
    return
end
nWanted = gearboxphy.sweep.workerBudget(nWanted);
pool = gcp('nocreate');
if isempty(pool)
    try
        [cl, profilQuelle] = gearboxphy.sweep.clusterFor();
        fprintf('Pool: Profil "%s" (%s).\n', cl.Profile, profilQuelle);
        pool = parpool(cl, nWanted);
    catch err
        fprintf('Pool liess sich nicht oeffnen (%s) -- parfor laeuft seriell.\n', err.message);
        return
    end
end
% Worker erben das Arbeitsverzeichnis des Clients NICHT (siehe runSweep.m).
% setupGearboxPath legt auch die Studienordner auf den Pfad, darunter
% studies/common mit bf_arch_scenario.
wait(parfevalOnAll(@addpath, 0, gearboxphy.paths.root()));
wait(parfevalOnAll(@setupGearboxPath, 0));
nWorkers = min(pool.NumWorkers, nWanted);
fprintf('Pool mit %d Workern, genutzt werden %d.\n', pool.NumWorkers, nWorkers);
end

function tf = localDone(outFile, CFG, lev, levCommon)
%LOCALDONE  Datei vorhanden UND mit demselben Raster, denselben Stufen und
%   demselben Standardfall gerechnet. Kommen spaeter Stufen dazu, wird neu
%   gerechnet.
%
%   dacScaleStandard IST PFLICHT, und zwar nicht aus Ordnungsliebe: seit
%   2026-10-12 ist E die gemeinsame Aussteuerung, vorher war es die je
%   Antenne. Die aelteren Dateien tragen dasselbe CFG und -- sobald die
%   fehlenden _common-Ordner gerechnet sind -- auch dasselbe Stufenraster,
%   wuerden also uebersprungen und als neue Rechnung gelesen, obwohl in E
%   der andere Fall steht. Das Feld fehlt ihnen, und daran scheitert der
%   Vergleich hier absichtlich.
tf = false;
if ~isfile(outFile), return; end
try
    % ERST NACHSEHEN, DANN LADEN. load(file, 'name') WARNT fuer jeden
    % Namen, den die Datei nicht hat -- und bei den Dateien von vor dem
    % 2026-10-12 fehlen dacLevelsPer und dacScaleStandard beide. Das gab
    % zwei Warnungen JE DATEI, also 36 in einem Lauf, fuer einen Fall, der
    % voellig in Ordnung ist: die Datei ist alt, gilt als nicht fertig und
    % wird neu gerechnet. Genau so soll es sein -- aber nicht laut.
    vars = who('-file', outFile);
    if ~all(ismember({'CFG', 'dacLevels', 'dacLevelsPer', 'dacScaleStandard'}, vars))
        return
    end
    T = load(outFile, 'CFG', 'dacLevels', 'dacLevelsPer', 'dacScaleStandard');
catch
    return
end
if ~isfield(T, 'CFG') || ~isfield(T, 'dacLevels') || ~isfield(T, 'dacLevelsPer') ...
        || ~isfield(T, 'dacScaleStandard'), return; end
tf = isequaln(T.CFG, CFG) && string(T.dacScaleStandard) == "common" ...
     && isequal(T.dacLevels(:), levCommon(:)) && isequal(T.dacLevelsPer(:), lev(:));
end

function fp = localGridFp(shape, CFG, v, hw, dataNames)
%LOCALGRIDFP  Fingerabdruck EINER Ergebnisdatei dieser Studie.
%   Eine Datei deckt mehrere Kurvenordner ab, deshalb je Ordner ein
%   Teil-Fingerabdruck und darueber einer. shape traegt den Variablensatz
%   (digital/analog) -- siehe +data/gridFingerprint.m, warum das noetig ist.
cfgs = arrayfun(@(n) struct('N_t', n, 'N_r', n), CFG.Ns, 'UniformOutput', false);
parts = strings(1, numel(dataNames));
for i = 1:numel(dataNames)
    vi = v; vi.data = dataNames(i);
    dd = gearboxphy.paths.dataDir(vi.data);
    parts(i) = gearboxphy.data.gridFingerprint("dbfdac_case/v1", ...
        @(d) bf_arch_scenario(d, CFG, vi, dd, hw.adc, cfgs, hw.dac, hw.lna), CFG);
end
fp = gearboxphy.data.fingerprint(shape, parts);
end
