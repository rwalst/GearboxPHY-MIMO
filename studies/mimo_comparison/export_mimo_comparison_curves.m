%EXPORT_MIMO_COMPARISON_CURVES  Schritt 2 des BF/MUX-Vergleichs: die
%   MI-Kurven aus QuantizedMimoMI in sechs vollstaendige Gearbox-Datenordner
%   uebersetzen.
%
%   Aufruf: in gearboxphy_framework/ einfach
%       export_mimo_comparison_curves
%   Braucht die Ergebnisse von Schritt 1 (siehe HPC_RUNBOOK_MIMO_VERGLEICH.md):
%       QuantizedMimoMI/qam/results/bHalf        runQamSweepBHalf      (MUX V0)
%       QuantizedMimoMI/qam/results/rule_mux     runQamSweepMuxV1      (MUX V1)
%       QuantizedMimoMI/qam/results/bf_rayleigh  runQamSweepBfRayleigh (BF V0+V1)
%       QuantizedMimoMI/qam/results/bf_ideal     runQamSweepBfIdeal    (BF ideal V0+V1)
%
%   ERGEBNIS: SE_data_mux_V0/_V1, SE_data_bf_V0/_V1, SE_data_bfideal_V0/_V1.
%   Jeder Ordner ist fuer sich vollstaendig:
%     * Gasts SISO-Kurven aus SE_data (ZXM, Pulse, NA-QAM, QAM M=1024) --
%       unveraendert AWGN, im Vergleich NICHT verwendet;
%     * QAM 1x1 aus demselben Lauf und mit derselben ADC-Regel wie die
%       Arrays (sisoFrom1x1) -- Rayleigh bei MUX/BF, AWGN beim idealen BF;
%     * QAM NxN (N = 2..16, M = 4..256), SNR auf Gesamtleistung, sourceB.
%   SE_data selbst bleibt unangetastet.
%
%   WARUM ALLE DENSELBEN GEARBOX-MODUS NUTZEN: in allen Ordnern steckt der
%   Array-Effekt IN der Kurve (MUX: N Stroeme; Rayleigh-BF: E[lambda_max];
%   ideales BF: deterministischer Gewinn N_t*N_r, als Verschiebung der
%   SNR-Achse), das Linkbudget bekommt nichts gutgeschrieben, und die
%   Hardware skaliert je Kette gleich. Der Gearbox laeuft deshalb fuer alle
%   im Modus "multiplexing" (= "Kurve je Antennenkonfiguration"); der
%   Unterschied zwischen den Verfahren liegt allein in der Kurve. Fuer das
%   ideale BF ist das algebraisch identisch zum alten Modus "beamforming".
mimoRoot = fullfile(gearboxphy.paths.root(), '..', 'QuantizedMimoMI');
addpath(mimoRoot); setupPath;
qamRoot = fullfile(mimoRoot, 'qam');
baseDir = gearboxphy.paths.dataDir('SE_data');

% name, Quellordner, Dateimuster, Regel-Variante, Kanal (fuer die 1x1-Pruefung)
V = struct( ...
  'name',    {"mux_V0", "mux_V1", "bf_V0", "bf_V1", "bfideal_V0", "bfideal_V1"}, ...
  'src',     {fullfile(qamRoot,'results','bHalf'),       fullfile(qamRoot,'results','rule_mux'), ...
              fullfile(qamRoot,'results','bf_rayleigh'), fullfile(qamRoot,'results','bf_rayleigh'), ...
              fullfile(qamRoot,'results','bf_ideal'),    fullfile(qamRoot,'results','bf_ideal')}, ...
  'pattern', {'mi_Nt*_Nr*_M*.mat',        'mi_Nt*_Nr*_M*_B*.mat', ...
              'mi_bf_Nt*_Nr*_M*_B*.mat',  'mi_bf_Nt*_Nr*_M*_B*.mat', ...
              'mi_bfideal_Nt*_Nr*_M*_B*.mat', 'mi_bfideal_Nt*_Nr*_M*_B*.mat'}, ...
  'variant', {"V0", "V1", "V0", "V1", "V0", "V1"}, ...
  'channel', {"rayleigh", "rayleigh", "rayleigh", "rayleigh", "awgn", "awgn"});

% Gemeinsames SNR-Raster fuer die drei RAYLEIGH-Varianten. Die Laeufe
% entstanden mit unterschiedlicher Aufloesung: Beamforming mit 1 dB,
% Multiplexing V1 mit 2 dB (V0 laeuft mit 1 dB). -15:2:25 ist Teilmenge
% von -15:1:25, das feinere wird also exakt ausgeduennt, nichts
% interpoliert. Gemessener Preis der groeberen Aufloesung: bis 0.23 dB
% im noetigen SNR, Median 0.01 dB -- und er trifft jetzt ALLE gleich,
% statt nur eine Seite des Vergleichs.
%
% Ideales Beamforming bleibt auf seinem eigenen, feineren Raster: es ist
% exakt gerechnet statt simuliert, deckt -20..45 dB ab (256-QAM saettigt
% ueber AWGN erst jenseits von 25 dB) und ist ohnehin nur eine
% Obergrenze, kein Kandidat im "besten Modus".
SNR_GRID_RAYLEIGH = -15:2:25;

Ns = [1 2 4 8 16];
Ms = [4 16 64 256];
missingTotal = 0;
for k = 1:numel(V)
    dst = gearboxphy.paths.dataDir("SE_data_" + V(k).name);
    fprintf('\n################ %s ################\n', V(k).name);
    if ~isfolder(V(k).src)
        warning('export:noSource', 'Quelle %s fehlt - %s uebersprungen.', V(k).src, V(k).name);
        missingTotal = missingTotal + numel(Ns)*numel(Ms);
        continue;
    end
    o = struct('pattern', V(k).pattern, 'variant', V(k).variant, ...
               'baseDir', baseDir, 'sisoFrom1x1', true);
    if V(k).channel == "rayleigh", o.snrGrid = SNR_GRID_RAYLEIGH; end
    exportToGearboxSEData(V(k).src, dst, o);

    % Vollstaendigkeit: jede (N, M)-Kurve muss da sein, mit der richtigen Bitzahl
    fprintf('  Vollstaendigkeit %s:\n', V(k).name);
    for M = Ms
        row = sprintf('    M=%-3d', M);
        for N = Ns
            if N == 1, fn = sprintf('SE_%d_QAM.mat', M);
            else,      fn = sprintf('SE_%d_QAM_%dx%d.mat', M, N, N); end
            p = fullfile(dst, fn);
            Bsoll = adcBitsRule(M, N, N, V(k).variant);
            if isfile(p)
                w = load(p, 'sourceB');
                if isfield(w, 'sourceB') && w.sourceB == Bsoll
                    row = [row sprintf('  %2dx%-2d B=%-2d', N, N, Bsoll)]; %#ok<AGROW>
                else
                    % z.B. Gasts AWGN-SISO-Kurve (ohne sourceB), weil die
                    % 1x1-Kurve des Laufs fehlt
                    row = [row sprintf('  %2dx%-2d FALSCH', N, N)]; %#ok<AGROW>
                    missingTotal = missingTotal + 1;
                end
            else
                row = [row sprintf('  %2dx%-2d FEHLT ', N, N)]; %#ok<AGROW>
                missingTotal = missingTotal + 1;
            end
        end
        fprintf('%s\n', row);
    end
end

% Querpruefung: die 1x1-Kurven muessen innerhalb eines KANALS in allen
% Ordnern gleich sein. Rayleigh: gleiche Kanalziehung, gleicher Seed,
% Tier 1, BF ist fuer Nt = 1 bitgenau MUX (validateBfRayleigh T1) -- eine
% Abweichung heisst, die Laeufe hatten nicht dieselben Einstellungen (Seed,
% nMC, SNR-Raster). AWGN (ideales BF): V0 und V1 haben fuer N = 1 dieselbe
% Bitzahl und muessen deshalb identisch sein. Zwischen den Kanaelen sind
% die 1x1-Kurven dagegen ABSICHTLICH verschieden.
for ch = ["rayleigh" "awgn"]
    sel = find([V.channel] == ch);
    fprintf('\n=== Querpruefung 1x1, Kanal %s ===\n', ch);
    for M = Ms
        ref = []; row = sprintf('  M=%-3d', M);
        for k = sel
            p = fullfile(gearboxphy.paths.dataDir("SE_data_" + V(k).name), sprintf('SE_%d_QAM.mat', M));
            if ~isfile(p), row = [row '  ' char(V(k).name) ':fehlt']; continue; end %#ok<AGROW>
            w = load(p, 'SE_vec', 'SNR_vec');
            if isempty(ref), ref = w; row = [row '  ' char(V(k).name) ':Referenz']; continue; end %#ok<AGROW>
            same = isequal(size(w.SE_vec), size(ref.SE_vec)) && ...
                   max(abs(w.SE_vec - ref.SE_vec)) < 1e-9 && isequal(w.SNR_vec, ref.SNR_vec);
            row = [row '  ' char(V(k).name) ':' char(tern(same, 'gleich', 'ABWEICHUNG'))]; %#ok<AGROW>
            if ~same
                % Identifier-Teile muessen mit einem Buchstaben beginnen --
                % sonst haelt MATLAB den String fuer die Meldung selbst
                warning('export:siso1x1Mismatch', ['1x1-Kurve M=%d in %s weicht ab - ' ...
                    'Seed/nMC/SNR-Raster der Laeufe pruefen.'], M, V(k).name);
            end
        end
        fprintf('%s\n', row);
    end
end

if missingTotal > 0
    warning('export:incomplete', ['%d Kurve(n) fehlen oder haben die falsche Bitzahl. ' ...
        'Der Gearbox laesst fehlende Konfigurationen mit Warnung aus ' ...
        '(filterAvailableAntennaConfigs) - fuer den Vergleich vorher nachrechnen.'], missingTotal);
else
    fprintf('\nAlle %d Ordner vollstaendig.\n', numel(V));
end

function s = tern(c, a, b)
if c, s = a; else, s = b; end
end
