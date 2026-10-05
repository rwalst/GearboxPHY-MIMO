function out = analyze_adc_rule_curves(opts)
%ANALYZE_ADC_RULE_CURVES  Die beiden Kurven HINTER dem Regelvergleich:
%   oben die spektrale Effizienz (dort wirkt das zusaetzliche Bit), unten
%   das Energie pro Bit (dort verschwindet der Effekt wieder).
%
%   out = analyze_adc_rule_curves();
%   out = analyze_adc_rule_curves(mode="bf");
%
%   Schreibt results/cmp_figures/cmp_adc_rule_se_<modus>.png und
%   cmp_adc_rule_ebit_<modus>.png.
%
%   DER MODUS GEHOERT IN DEN DATEINAMEN. Ohne ihn ueberschreibt ein Lauf
%   mit mode="mux" die Abbildungen eines vorangegangenen mode="bf" -- und
%   zwar lautlos, mit identisch aussehendem Ergebnis.
%
%   WARUM ZWEI ABBILDUNGEN STATT EINER: sie zeigen Eingang und Ausgang
%   derselben Rechnung, und beide brauchen eine eigene Achse. Die
%   SE-Kurven stehen ueber der SNR, die E_bit-Kurven ueber der Rate.
%
%   DIE SE-ABBILDUNG IST DER BELEG, DASS DIE REGEL UEBERHAUPT ETWAS TUT:
%   scaledB liegt sichtbar ueber fixedB. Die E_bit-Abbildung zeigt, dass
%   davon im Energiebudget fast nichts uebrig bleibt -- die beiden Kurven
%   liegen aufeinander. Genau dieses Nebeneinander rechtfertigt, dass der
%   eigentliche Vergleich als Differenz in Prozent gefuehrt wird
%   (analyze_adc_rule_all.m) und nicht als Kurvenpaar.
%
%   NUR N > 1: bei N = 1 sind beide Regeln dieselbe Datei, die Kurven
%   laegen exakt uebereinander und zeigten nichts.
arguments
    opts.mode (1,1) string {mustBeMember(opts.mode, ["mux","bf","bfideal"])} = "mux"
    opts.Ns (1,:) double = [2 4]
    opts.Ms (1,:) double = [16 64 256]
    opts.distances (1,:) double = [50 500 5000]
    opts.fcGHz (1,1) double = 28
    opts.figDir (1,1) string = "cmp_figures"
end

RULES = ["fixedB" "scaledB"];
STY   = {'-', '--'};
C     = lines(3);
INK   = [0.043 0.043 0.043];
INK2  = [0.322 0.318 0.306];

figDir = gearboxphy.paths.resultsDir(opts.figDir);
if ~isfolder(figDir), mkdir(figDir); end

%% ================= 1. SE-Kurven ======================================
nN = numel(opts.Ns);
fig = figure('Position', [100 100 460*nN+140 470], 'Color', 'w');
tl  = tiledlayout(fig, 1, nN, 'TileSpacing', 'compact', 'Padding', 'compact');
se = struct('N', {}, 'M', {}, 'capPct', {}, 'gainDb', {});

for ni = 1:nN
    N = opts.Ns(ni);
    ax = nexttile(tl); localStyle(ax, INK2);
    h = gobjects(0);
    for mi = 1:numel(opts.Ms)
        M = opts.Ms(mi);
        for r = 1:2
            f = fullfile(gearboxphy.paths.dataDir("SE_data_" + opts.mode + "_" + RULES(r)), ...
                sprintf('SE_%d_QAM_%dx%d.mat', M, N, N));
            if ~isfile(f), continue; end
            S = load(f);
            hh = plot(ax, S.SNR_vec, S.SE_vec, STY{r}, 'Color', C(mi,:), 'LineWidth', 2);
            if ni == 1
                set(hh, 'DisplayName', sprintf('M = %d, %s (b = %d)', M, RULES(r), S.sourceB));
                h(end+1) = hh; %#ok<AGROW>
            end
        end
        % Gemessen wird NAHE DER SAETTIGUNG, nicht in der Mitte: dort
        % begrenzt das Rauschen, nicht der Quantisierer, und beide Regeln
        % liefern dieselbe Kurve. Erst am oberen Ende wirkt das Bit.
        a = localLoad(opts.mode, "fixedB", M, N);
        b = localLoad(opts.mode, "scaledB", M, N);
        if ~isempty(a) && ~isempty(b)
            capA = max(a.SE_vec); capB = max(b.SE_vec);
            t = 0.9 * capA;                       % 90 % der fixedB-Saettigung
            se(end+1) = struct('N', N, 'M', M, 'capPct', 100*(capB/capA - 1), ...
                'gainDb', localSnrAt(a, t) - localSnrAt(b, t)); %#ok<AGROW>
        end
    end
    title(ax, sprintf('%d x %d', N, N), 'FontSize', 12.5, 'Color', INK);
    xlabel(ax, 'SNR [dB]', 'FontSize', 12, 'Color', INK2);
    if ni == 1
        ylabel(ax, 'spectral efficiency [bit/channel use]', 'FontSize', 12, 'Color', INK2);
        legend(ax, h, 'Location', 'northwest', 'Box', 'off', 'FontSize', 9, 'TextColor', INK2);
    end
end
title(tl, sprintf('What the extra bit buys: %s, solid fixedB, dashed scaledB', ...
    localModeName(opts.mode)), 'FontSize', 13, 'Color', INK, 'FontWeight', 'bold');
exportgraphics(fig, fullfile(figDir, sprintf('cmp_adc_rule_se_%s.png', opts.mode)), 'Resolution', 200);

%% ================= 2. E_bit-Kurven ===================================
nD = numel(opts.distances);
fig = figure('Position', [100 100 400*nD+140 440], 'Color', 'w');
tl  = tiledlayout(fig, 1, nD, 'TileSpacing', 'compact', 'Padding', 'compact');
for di = 1:nD
    % Beide Achsen logarithmisch: die Rate laeuft ueber acht Dekaden, linear
    % klebt alles am linken Rand.
    ax = nexttile(tl); localStyle(ax, INK2); set(ax, 'XScale', 'log', 'YScale', 'log');
    h = gobjects(0);
    for r = 1:2
        rd = gearboxphy.paths.resultsDir(sprintf('cmp_%s_%s_d%g', opts.mode, RULES(r), ...
            opts.distances(di)));
        d = localBestE(rd, opts);
        if isempty(d), continue; end
        hh = plot(ax, d.R, d.E, STY{r}, 'Color', C(r,:), 'LineWidth', 2, ...
            'DisplayName', char(RULES(r)));
        if di == 1, h(end+1) = hh; end %#ok<AGROW>
    end
    title(ax, sprintf('d = %g m', opts.distances(di)), 'FontSize', 12.5, 'Color', INK);
    xlabel(ax, 'R_{eff} [bit/s]', 'FontSize', 12, 'Color', INK2);
    if di == 1
        ylabel(ax, 'E_{bit} [J/bit]', 'FontSize', 12, 'Color', INK2);
        legend(ax, h, 'Location', 'northeast', 'Box', 'off', 'FontSize', 11, 'TextColor', INK2);
    end
end
title(tl, sprintf(['...and what is left of it in the budget: %s, best over ' ...
    'M \\leq 256 and N \\leq 4'], localModeName(opts.mode)), ...
    'FontSize', 13, 'Color', INK, 'FontWeight', 'bold');
exportgraphics(fig, fullfile(figDir, sprintf('cmp_adc_rule_ebit_%s.png', opts.mode)), 'Resolution', 200);

%% ---- Zahlen ----------------------------------------------------------
fprintf('\n==== Was scaledB auf der SE-Kurve bringt (%s) ====\n', opts.mode);
fprintf('%-6s %-6s %-14s %s\n', 'N', 'M', 'Saettigung', 'SNR-Ersparnis bei 90 %% davon');
for i = 1:numel(se)
    fprintf('%-6d %-6d %+8.2f %%     %+.2f dB\n', se(i).N, se(i).M, se(i).capPct, se(i).gainDb);
end
fprintf('Median: Saettigung %+.2f %%, SNR-Ersparnis %+.2f dB\n', ...
    median([se.capPct]), median([se.gainDb]));
out.se = se; out.mode = opts.mode;
save(fullfile(figDir, sprintf('adc_rule_curves_%s_summary.mat', opts.mode)), 'out');
fprintf('\ncmp_adc_rule_se_%s.png und cmp_adc_rule_ebit_%s.png in %s\n', opts.mode, opts.mode, figDir);
end

% =======================================================================
function S = localLoad(mode, rule, M, N)
f = fullfile(gearboxphy.paths.dataDir("SE_data_" + mode + "_" + rule), ...
    sprintf('SE_%d_QAM_%dx%d.mat', M, N, N));
if isfile(f), S = load(f); else, S = []; end
end

function snr = localSnrAt(S, target)
%LOCALSNRAT  SNR, bei der die Kurve die Ziel-SE erreicht.
%
%   Streng monoton per LAUFMAXIMUM, nicht per diff > 0. Derselbe Fehler
%   steckte schon in trimCurve.m: ein Vergleich mit dem Vorgaenger laesst
%   in der Folge 5, 4, 5 die zweite 5 stehen, weil sie gegenueber der 4
%   ein Anstieg ist -- und interp1 lehnt doppelte Stuetzstellen ab. Bei
%   den exakt gerechneten bfideal-Kurven mit ihren Plateaus trat genau
%   das auf.
v = S.SE_vec(:).';
keep = [true, v(2:end) > cummax(v(1:end-1))];
snr = interp1(v(keep), S.SNR_vec(keep), target, 'linear', NaN);
end

function s = localBestE(rd, opts)
%LOCALBESTE  Bestes E_bit ueber M und N je Ratenpunkt.
s = [];
if ~isfolder(rd), return; end
first = true;
for M = [4 opts.Ms]
    f = fullfile(rd, sprintf('qam_M%d_fc%gGHz.mat', M, opts.fcGHz));
    if ~isfile(f), continue; end
    S = load(f);
    if first, s.R = S.RVec(:).'; s.E = inf(size(s.R)); first = false; end
    e = S.E_per_bit(:).';
    s.E = min(s.E, e);
end
if ~first, s.E(~isfinite(s.E)) = NaN; end
end

function n = localModeName(mode)
switch mode
    case "mux",     n = 'multiplexing';
    case "bf",      n = 'digital eigen-beamforming';
    otherwise,      n = 'rank-1 bound';
end
end

function localStyle(ax, INK2)
hold(ax, 'on'); grid(ax, 'on'); box(ax, 'off');
set(ax, 'FontSize', 11, 'XColor', INK2, 'YColor', INK2, 'GridAlpha', 0.12);
end
