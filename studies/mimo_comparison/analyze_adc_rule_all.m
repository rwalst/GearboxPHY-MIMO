function out = analyze_adc_rule_all(opts)
%ANALYZE_ADC_RULE_ALL  Die ADC-Regel fuer alle drei Modi in EINER
%   Abbildung.
%
%   out = analyze_adc_rule_all();
%   out = analyze_adc_rule_all(distances=[50 5000]);
%
%   Schreibt results/cmp_figures/cmp_adc_rule_all.png. Die Einzel-
%   abbildungen je Modus erzeugt analyze_adc_rule(mode=...); dieselbe
%   Ladelogik wird hier ueber makeFigure=false wiederverwendet, damit es
%   nur EINE Stelle gibt, an der "bestes E_bit ueber M und N" definiert ist.
%
%   WAS HIER WEGFAELLT: die absoluten E_bit-Kurven. In den Einzel-
%   abbildungen liegen fixedB und scaledB sichtbar uebereinander -- der
%   Unterschied ist zu klein, um in einer logarithmischen Achse ueber acht
%   Dekaden aufzufallen. Genau deshalb ist die Differenz in Prozent die
%   Aussage und nicht die Kurve selbst.
%
%   ZEILE 1 ist die Antwort, ZEILE 2 der Grund: der ADC-Anteil am Budget.
%   Wo er klein ist, entscheidet die bessere SE-Kurve und scaledB gewinnt;
%   wo er spuerbar wird, schlaegt der Preis 2^b mal N_r Wandler durch.
arguments
    opts.distances (1,:) double = [50 500 5000]
    opts.fcGHz (1,1) double = 28
    opts.figDir (1,1) string = "cmp_figures"
end

MODES = ["mux" "bf" "bfideal"];
LABEL = ["MUX" "BF" "BF ideal"];
C     = lines(3);
INK   = [0.043 0.043 0.043];
INK2  = [0.322 0.318 0.306];
nD    = numel(opts.distances);

figDir = gearboxphy.paths.resultsDir(opts.figDir);
if ~isfolder(figDir), mkdir(figDir); end

%% ---- Laden (eine Quelle fuer alle drei) -------------------------------
R = cell(1, numel(MODES));
for m = 1:numel(MODES)
    R{m} = analyze_adc_rule(mode=MODES(m), distances=opts.distances, ...
        fcGHz=opts.fcGHz, makeFigure=false);
end

%% ---- Abbildung -------------------------------------------------------
fig = figure('Position', [100 100 390*nD+140 560], 'Color', 'w');
tl  = tiledlayout(fig, 2, nD, 'TileSpacing', 'compact', 'Padding', 'compact');

for di = 1:nD
    % --- Zeile 1: scaledB gegen fixedB ---
    ax = nexttile(tl, di); localStyle(ax, INK2);
    h = gobjects(0);
    for m = 1:numel(MODES)
        D = R{m}.data{1};
        a = D{1,di}; b = D{2,di};
        if isempty(a) || isempty(b), continue; end
        h(end+1) = plot(ax, a.R, 100*(b.Ebest./a.Ebest - 1), '-', 'Color', C(m,:), ...
            'LineWidth', 2, 'DisplayName', LABEL(m)); %#ok<AGROW>
    end
    yline(ax, 0, '--', 'Color', INK2, 'LineWidth', 1.2);
    title(ax, sprintf('d = %g m', opts.distances(di)), 'FontSize', 12.5, 'Color', INK);
    % Legende und die beiden Richtungshinweise in VERSCHIEDENE Felder:
    % im ersten Feld laufen die Kurven bis -6 %, dort ueberlagern sie sich
    % sonst gegenseitig.
    if di == 1
        ylabel(ax, 'scaledB vs. fixedB [%]', 'FontSize', 12, 'Color', INK2);
        yl = ylim(ax);
        text(ax, ax.XLim(1)*3, yl(2)*0.85, ' scaledB teurer', 'FontSize', 9, 'Color', INK2);
        text(ax, ax.XLim(1)*3, yl(1)*0.85, ' scaledB guenstiger', 'FontSize', 9, 'Color', INK2);
    elseif di == nD
        legend(ax, h, 'Location', 'southwest', 'Box', 'off', 'FontSize', 10, ...
            'TextColor', INK2);
    end

    % --- Zeile 2: ADC-Anteil, durchgezogen scaledB, gepunktet fixedB ---
    ax2 = nexttile(tl, nD + di); localStyle(ax2, INK2);
    for m = 1:numel(MODES)
        D = R{m}.data{1};
        a = D{1,di}; b = D{2,di};
        if isempty(a) || isempty(b), continue; end
        plot(ax2, b.R, 100*b.adcShare, '-',  'Color', C(m,:), 'LineWidth', 2);
        plot(ax2, a.R, 100*a.adcShare, ':',  'Color', C(m,:), 'LineWidth', 1.6);
    end
    xlabel(ax2, 'R_{eff} [bit/s]', 'FontSize', 12, 'Color', INK2);
    if di == 1
        ylabel(ax2, 'ADC-Anteil an E_{bit} [%]', 'FontSize', 12, 'Color', INK2);
        text(ax2, ax2.XLim(1)*3, max(ylim(ax2))*0.85, ...
            ' durchgezogen: scaledB,  gepunktet: fixedB', 'FontSize', 9, 'Color', INK2);
    end
end
title(tl, sprintf(['The ADC bit rule across all three modes, f_c = %g GHz, ' ...
    'best over M \\leq 256 and N \\leq 4'], opts.fcGHz), ...
    'FontSize', 13, 'Color', INK, 'FontWeight', 'bold');
exportgraphics(fig, fullfile(figDir, 'cmp_adc_rule_all.png'), 'Resolution', 200);

%% ---- Zusammenfassung -------------------------------------------------
fprintf('\n==== scaledB gegen fixedB, alle Modi, ganzer Ratenbereich ====\n');
fprintf('%-10s %-8s %-10s %-10s %-10s %s\n', 'Modus', 'Punkte', 'Median', ...
    'Minimum', 'Maximum', 'scaledB guenstiger');
out.summary = [];
for m = 1:numel(MODES)
    D = R{m}.data{1};
    v = [];
    for di = 1:nD
        a = D{1,di}; b = D{2,di};
        if isempty(a) || isempty(b), continue; end
        x = 100*(b.Ebest./a.Ebest - 1);
        v = [v x(isfinite(x))]; %#ok<AGROW>
    end
    fprintf('%-10s %-8d %+-9.2f %+-9.2f %+-9.2f %.1f %%\n', LABEL(m), numel(v), ...
        median(v), min(v), max(v), 100*mean(v < 0));
    out.summary(m,:) = [numel(v), median(v), min(v), max(v), 100*mean(v < 0)]; %#ok<AGROW>
end

out.modes = MODES; out.distances = opts.distances; out.perMode = R;
save(fullfile(figDir, 'adc_rule_all_summary.mat'), 'out');
fprintf('\ncmp_adc_rule_all.png und adc_rule_all_summary.mat in %s\n', figDir);
end

% =======================================================================
function localStyle(ax, INK2)
hold(ax, 'on'); grid(ax, 'on'); box(ax, 'off');
set(ax, 'XScale', 'log', 'FontSize', 11, 'XColor', INK2, 'YColor', INK2, 'GridAlpha', 0.12);
end
