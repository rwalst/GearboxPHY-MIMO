function out = analyze_adc_rule(opts)
%ANALYZE_ADC_RULE  Die beiden ADC-Regeln im direkten Vergleich, fuer EINEN
%   Modus.
%
%   out = analyze_adc_rule();                  % Multiplexing
%   out = analyze_adc_rule(mode="bf");         % digitales Eigen-Beamforming
%   out = analyze_adc_rule(mode="bf", distances=[50 5000]);
%
%   Liest results/cmp_<modus>_<regel>_d<d>/ (Schritt 3a) und schreibt
%   results/cmp_figures/cmp_adc_rule_<modus>.png.
%
%   EIN MODUS JE ABBILDUNG, mit Absicht. Multiplexing und Beamforming
%   reagieren verschieden auf das zusaetzliche Bit -- MUX detektiert N
%   Stroeme gemeinsam, BF einen einzigen -- und beides uebereinander zu
%   legen hat den Vergleich in der Sechs-Varianten-Abbildung eher
%   verdeckt als gezeigt.
%
%   DIE FRAGE: lohnt das zusaetzliche ADC-Bit je Antennenverdopplung?
%       fixedB    B = 1/2*log2(M) + 3
%       scaledB   B = 1/2*log2(M) + log2(N) + 3
%   Beide tragen die +3; sie unterscheiden sich NUR im Term log2(N), und
%   bei N = 1 sind sie identisch. Der Vergleich ist damit sauber: gleiche
%   Kurvenquelle, gleiches Hardwaremodell, gleiches SNR-Raster, ein
%   einziger Unterschied.
%
%   ZWEI GEGENLAEUFIGE EFFEKTE, die die Abbildung trennen soll:
%     + die feinere Quantisierung hebt die SE-Kurve, es wird also weniger
%       Sendeleistung fuer dieselbe Rate gebraucht;
%     - der Wandler kostet 2^b, und davon stehen N_r Stueck im Empfaenger.
%       Unter scaledB waechst die ADC-Leistung mit N^2 statt mit N.
%   Welcher gewinnt, haengt davon ab, wie gross der ADC-Anteil am Budget
%   ueberhaupt ist -- und der ist klein, solange die PA dominiert.
%
%   NUR N <= 4: weiter reichen die gerechneten Sweeps nicht. Bei N = 1
%   sind beide Regeln per Definition gleich, der Unterschied kann also nur
%   aus 2x2 und 4x4 kommen.
arguments
    opts.mode (1,1) string {mustBeMember(opts.mode, ["mux","bf","bfideal"])} = "mux"
    opts.distances (1,:) double = [50 500 5000]
    opts.fcGHz (1,1) double = 28
    opts.Ms (1,:) double = [4 16 64 256]
    opts.figDir (1,1) string = "cmp_figures"
    % false: nur laden und zurueckgeben, keine Abbildung, keine Tabelle.
    % analyze_adc_rule_all nutzt das, um alle drei Modi mit DERSELBEN
    % Ladelogik zu holen, statt sie zu kopieren.
    opts.makeFigure (1,1) logical = true
end

RULES = ["fixedB" "scaledB"];
INK  = [0.043 0.043 0.043];
INK2 = [0.322 0.318 0.306];
C    = lines(2);
nD   = numel(opts.distances);

figDir = gearboxphy.paths.resultsDir(opts.figDir);
if ~isfolder(figDir), mkdir(figDir); end

%% ---- Laden -----------------------------------------------------------
D = cell(numel(RULES), nD);
for r = 1:numel(RULES)
    for di = 1:nD
        rd = gearboxphy.paths.resultsDir(sprintf('cmp_%s_%s_d%g', opts.mode, RULES(r), ...
            opts.distances(di)));
        if ~isfolder(rd)
            warning('adcRule:missing', '%s fehlt - uebersprungen.', rd);
            continue
        end
        D{r,di} = localLoad(rd, opts);
    end
end
assert(any(~cellfun(@isempty, D(:))), 'adcRule:noData', ...
    'Keine results/cmp_%s_*_d* gefunden - erst run_mimo_comparison_sweep ausfuehren.', opts.mode);

out.mode = opts.mode; out.rules = RULES; out.distances = opts.distances; out.data = {D};
if ~opts.makeFigure
    return
end

%% ---- Abbildung -------------------------------------------------------
fig = figure('Position', [100 100 380*nD+140 760], 'Color', 'w');
tl  = tiledlayout(fig, 3, nD, 'TileSpacing', 'compact', 'Padding', 'compact');

for di = 1:nD
    a = D{1,di}; b = D{2,di};
    if isempty(a) || isempty(b), continue; end
    R = a.R;

    % --- Zeile 1: E_bit beider Regeln ---
    ax = nexttile(tl, di); localStyle(ax, INK2); set(ax, 'YScale', 'log');
    h = gobjects(0);
    h(end+1) = plot(ax, R, a.Ebest, '-',  'Color', C(1,:), 'LineWidth', 2, ...
        'DisplayName', 'fixedB'); %#ok<AGROW>
    h(end+1) = plot(ax, R, b.Ebest, '--', 'Color', C(2,:), 'LineWidth', 2, ...
        'DisplayName', 'scaledB'); %#ok<AGROW>
    title(ax, sprintf('d = %g m', opts.distances(di)), 'FontSize', 12.5, 'Color', INK);
    if di == 1
        ylabel(ax, 'E_{bit} [J/bit]', 'FontSize', 12, 'Color', INK2);
        legend(ax, h, 'Location', 'northeast', 'Box', 'off', 'FontSize', 10, 'TextColor', INK2);
    end

    % --- Zeile 2: Verhaeltnis, das ist die eigentliche Aussage ---
    ax2 = nexttile(tl, nD + di); localStyle(ax2, INK2);
    ratio = b.Ebest ./ a.Ebest;
    plot(ax2, R, 100*(ratio-1), '-', 'Color', INK, 'LineWidth', 2);
    yline(ax2, 0, '--', 'Color', INK2, 'LineWidth', 1.2);
    % Bereiche einfaerben: unter 0 ist scaledB besser
    ylim(ax2, localSymRange(100*(ratio-1)));
    if di == 1
        ylabel(ax2, 'scaledB vs. fixedB [%]', 'FontSize', 12, 'Color', INK2);
        text(ax2, R(2), max(ylim(ax2))*0.75, ' scaledB teurer', 'FontSize', 9, 'Color', INK2);
        text(ax2, R(2), min(ylim(ax2))*0.75, ' scaledB guenstiger', 'FontSize', 9, 'Color', INK2);
    end

    % --- Zeile 3: ADC-Anteil, erklaert das Verhaeltnis ---
    ax3 = nexttile(tl, 2*nD + di); localStyle(ax3, INK2);
    plot(ax3, R, 100*a.adcShare, '-',  'Color', C(1,:), 'LineWidth', 2);
    plot(ax3, R, 100*b.adcShare, '--', 'Color', C(2,:), 'LineWidth', 2);
    xlabel(ax3, 'R_{eff} [bit/s]', 'FontSize', 12, 'Color', INK2);
    if di == 1
        ylabel(ax3, 'ADC-Anteil an E_{bit} [%]', 'FontSize', 12, 'Color', INK2);
    end
end
MODENAME = containers.Map({'mux','bf','bfideal'}, ...
    {'multiplexing', 'digital eigen-beamforming', 'idealized beamforming'});
chan = 'i.i.d. Rayleigh';
if opts.mode == "bfideal", chan = 'AWGN, rank 1'; end
title(tl, sprintf(['ADC rule for %s, f_c = %g GHz, %s, ' ...
    'best over M \\leq 256 and N \\leq 4'], MODENAME(char(opts.mode)), opts.fcGHz, chan), ...
    'FontSize', 13, 'Color', INK, 'FontWeight', 'bold');
exportgraphics(fig, fullfile(figDir, sprintf('cmp_adc_rule_%s.png', opts.mode)), 'Resolution', 200);

%% ---- Tabelle ---------------------------------------------------------
fprintf('\n==== scaledB gegen fixedB, Modus %s ====\n', opts.mode);
fprintf('%-8s %-11s %-11s %-11s %-10s %-7s %-7s %s\n', 'd [m]', 'R [bit/s]', ...
    'fixedB', 'scaledB', 'Differenz', 'N fix', 'N scl', 'ADC-Anteil fix/scl');
out.rows = [];
for di = 1:nD
    a = D{1,di}; b = D{2,di};
    if isempty(a) || isempty(b), continue; end
    for Rq = [1e6 1e8 1e9 1e10]
        [~, i] = min(abs(log10(a.R) - log10(Rq)));
        if ~isfinite(a.Ebest(i)) || ~isfinite(b.Ebest(i)), continue; end
        d = 100*(b.Ebest(i)/a.Ebest(i) - 1);
        fprintf('%-8g %-11.2g %-11.3g %-11.3g %+9.2f %% %-7d %-7d %.2f %% / %.2f %%\n', ...
            opts.distances(di), a.R(i), a.Ebest(i), b.Ebest(i), d, ...
            a.Nopt(i), b.Nopt(i), 100*a.adcShare(i), 100*b.adcShare(i));
        out.rows(end+1,:) = [opts.distances(di), a.R(i), a.Ebest(i), b.Ebest(i), d, ...
            a.Nopt(i), b.Nopt(i), a.adcShare(i), b.adcShare(i)]; %#ok<AGROW>
    end
end

% Zusammenfassung ueber den ganzen Ratenbereich
allD = [];
for di = 1:nD
    a = D{1,di}; b = D{2,di};
    if isempty(a) || isempty(b), continue; end
    v = 100*(b.Ebest./a.Ebest - 1);
    allD = [allD v(isfinite(v))]; %#ok<AGROW>
end
fprintf(['\nUeber alle %d ausgewerteten Punkte: scaledB im Median %+.2f %%, ' ...
    'Spanne %+.2f .. %+.2f %%.\n'], numel(allD), median(allD), min(allD), max(allD));
fprintf('Anteil der Punkte, an denen scaledB guenstiger ist: %.1f %%\n', ...
    100*mean(allD < 0));

save(fullfile(figDir, sprintf('adc_rule_%s_summary.mat', opts.mode)), 'out');
fprintf('\ncmp_adc_rule_%s.png und adc_rule_%s_summary.mat in %s\n', ...
    opts.mode, opts.mode, figDir);
end

% =======================================================================
function s = localLoad(rd, opts)
%LOCALLOAD  Bestes E_bit ueber M und N, zugehoerige Antennenzahl und
%   ADC-Anteil -- je Ratenpunkt.
TX = {'PA','DAC','LO_Tx','Mix_Tx'}; RX = {'LNA','LO_Rx','Mix_Rx','ADC'};
first = true;
for M = opts.Ms
    f = fullfile(rd, sprintf('qam_M%d_fc%gGHz.mat', M, opts.fcGHz));
    if ~isfile(f), continue; end
    S = load(f);
    if first
        s.R = S.RVec(:).';
        n = numel(s.R);
        s.Ebest = inf(1,n); s.Nopt = ones(1,n); s.adcShare = nan(1,n);
        first = false;
    end
    assert(numel(S.RVec) == numel(s.R), 'adcRule:grid', '%s: anderes Ratenraster', f);
    e = S.E_per_bit(:).';
    better = e < s.Ebest;
    s.Ebest(better) = e(better);
    s.Nopt(better)  = S.Optimal_N_t(better);
    for i = find(better)
        pb = S.PowerBudget{i};
        if isstruct(pb)
            tot = sum(cellfun(@(x) pb.(x), [TX RX]));
            s.adcShare(i) = pb.ADC / tot;
        end
    end
end
if first, s = []; return; end
s.Ebest(~isfinite(s.Ebest)) = NaN;
end

function r = localSymRange(v)
v = v(isfinite(v));
if isempty(v), r = [-1 1]; return; end
m = max(abs(v))*1.15;
if m == 0, m = 1; end
r = [-m m];
end

function localStyle(ax, INK2)
hold(ax, 'on'); grid(ax, 'on'); box(ax, 'off');
set(ax, 'XScale', 'log', 'FontSize', 11, 'XColor', INK2, 'YColor', INK2, 'GridAlpha', 0.12);
end
