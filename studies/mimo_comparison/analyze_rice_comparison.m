function out = analyze_rice_comparison(opts)
%ANALYZE_RICE_COMPARISON  Schritt 6 der Rice-Erweiterung: E_bit ueber dem
%   Rice-Faktor K, und der Schnittpunkt K*, ab dem Beamforming guenstiger
%   ist als Multiplexing.
%
%   out = analyze_rice_comparison();
%   out = analyze_rice_comparison(cases=[500 1.1e10; 5000 9.5e8]);
%
%   Liest results/cmp_distance_<variante>.mat (Schritt 3b) und schreibt
%   results/cmp_figures/cmp_rice.png.
%
%   WARUM DIESE ABBILDUNG: der BF/MUX-Vergleich ist methodisch sauber,
%   sein Ergebnis haengt aber am Kanal, und i.i.d. Rayleigh (K = 0) ist
%   der guenstigste Fall fuer Multiplexing -- vollrangig, alle N
%   Eigenmodi tragen. Bei 28 GHz ist das die schwaechste Annahme der
%   Studie. K* macht daraus eine Zahl statt einer Einschraenkung.
%
%   K = 0 IST DER VORHANDENE RAYLEIGH-LAUF. mux_scaledB und bf_scaledB
%   sind nicht "auch noch" K = 0, sie SIND es -- deshalb wird hier nichts
%   doppelt gerechnet.
%
%   DREI STUETZSTELLEN, NICHT VIER. K = 10 wurde bewusst ausgelassen, die
%   Luecke zwischen 4.8 dB und 14.8 dB ist also breit. K* wird deshalb nur
%   dann als Zahl ausgewiesen, wenn der Schnittpunkt zwischen zwei
%   GERECHNETEN K liegt; sonst steht da, zwischen welchen beiden er faellt.
%   Interpoliert wird in log10(K), weil der Arraygewinn und der
%   Rangverlust beide mit K/(K+1) skalieren.
%
%   WAS K MISST: RANGARMUT, NICHT SICHTVERBINDUNG. H_LOS ist Broadside mit
%   lambda/2, also vollstaendig korreliert. Ein reiner LOS-Kanal mit
%   LOS-MIMO-Antennenabstand waere VOLLRANGIG und wuerde Multiplexing
%   nicht schaden. K* ist deshalb die Schwelle fuer "Kanal zu rangarm fuer
%   Multiplexing", nicht fuer "zu viel Sichtverbindung".
%
%   NICHT AN DER SAETTIGUNG ABLESEN: bei K = 30 erreicht MUX 4x4 QPSK noch
%   7.997 von 8 bit. Der Verlust steckt in der benoetigten SNR (bis
%   +8.42 dB gemessen), nicht in der Decke -- und genau deshalb schlaegt er
%   auf E_bit durch, was diese Abbildung zeigt.
%
%   IDEALES BEAMFORMING ist der Grenzfall K -> unendlich (Rang 1, voller
%   Gewinn N_t*N_r) und wird als Marke am rechten Rand eingetragen, nicht
%   als Kurve -- es kennt kein K.
arguments
    % Zeilen [Distanz_m, Rate_bit_s]; je Zeile ein Spaltenpaar der Abbildung.
    %
    % DIE RATEN MUESSEN IM 3b-RASTER LIEGEN. Schritt 3b rechnet nur ZWEI
    % Raten (1e6 und 1e9), nicht die 100 Ratenpunkte von 3a. Ein Wunsch
    % wie 1.1e10 wird sonst auf 1e9 gerundet -- Faktor 11 daneben -- und
    % die Abbildung trueg eine Beschriftung, die nicht zu den Zahlen passt.
    % localIndex warnt jetzt, wenn gerundet werden muss.
    opts.cases (:,2) double = [50 1e9; 500 1e9; 5000 1e9]
    opts.figDir (1,1) string = "cmp_figures"
end

KS   = [0 3 30];
MODE = ["mux" "bf"];
INK  = [0.043 0.043 0.043];
INK2 = [0.322 0.318 0.306];
C    = lines(3);                      % blau = MUX, rot = BF, gelb = ideal

figDir = gearboxphy.paths.resultsDir(opts.figDir);
if ~isfolder(figDir), mkdir(figDir); end

%% ---- Laden -----------------------------------------------------------
D = cell(numel(MODE), numel(KS));
for m = 1:numel(MODE)
    for k = 1:numel(KS)
        D{m,k} = localLoad(localName(MODE(m), KS(k)));
    end
end
ideal = localLoad("bfideal_scaledB");
assert(any(~cellfun(@isempty, D(:))), 'analyzeRice:noData', ...
    ['Keine results/cmp_distance_*scaledB*.mat gefunden - erst ' ...
     'run_mimo_comparison_distance ausfuehren.']);

ref = localFirst(D);
nC  = size(opts.cases, 1);

%% ---- Abbildung -------------------------------------------------------
fig = figure('Position', [100 100 380*nC+120 640], 'Color', 'w');
tl  = tiledlayout(fig, 2, nC, 'TileSpacing', 'compact', 'Padding', 'compact');
cases = nan(nC, 2);          % tatsaechlich getroffene (d, R)
out = struct('cases', [], 'K', KS, 'E', [], 'ratio', [], 'Kstar', []);
E     = nan(nC, numel(MODE), numel(KS));
Eidl  = nan(1, nC);
ratio = nan(nC, numel(KS));
Kstar = cell(1, nC);

for c = 1:nC
    [di, ri] = localIndex(ref.CFG, opts.cases(c,1), opts.cases(c,2));
    % AB HIER die tatsaechlich getroffenen Stuetzstellen verwenden, nicht
    % die gewuenschten -- sonst beschriftet die Abbildung etwas anderes,
    % als sie zeigt.
    d = ref.CFG.distances(di); R = ref.CFG.rates(ri);
    cases(c,:) = [d R]; %#ok<AGROW>
    for m = 1:numel(MODE)
        for k = 1:numel(KS)
            if isempty(D{m,k}), continue; end
            E(c,m,k) = localBest(D{m,k}, di, ri);
        end
    end
    if ~isempty(ideal), Eidl(c) = localBest(ideal, di, ri); end
    ratio(c,:) = squeeze(E(c,2,:)) ./ squeeze(E(c,1,:));   % BF / MUX
    Kstar{c}   = localKstar(KS, ratio(c,:));

    % --- oben: E_bit ueber K ---
    ax = nexttile(tl, c); localStyle(ax, INK2); set(ax, 'YScale', 'log');
    x = 1:numel(KS);
    h = gobjects(0);
    h(end+1) = plot(ax, x, squeeze(E(c,1,:)), '-o', 'Color', C(1,:), 'LineWidth', 2, ...
        'MarkerFaceColor', 'w', 'DisplayName', 'MUX'); %#ok<AGROW>
    h(end+1) = plot(ax, x, squeeze(E(c,2,:)), '-o', 'Color', C(2,:), 'LineWidth', 2, ...
        'MarkerFaceColor', 'w', 'DisplayName', 'BF'); %#ok<AGROW>
    if isfinite(Eidl(c))
        h(end+1) = plot(ax, numel(KS)+0.6, Eidl(c), 'p', 'Color', C(3,:), ...
            'MarkerSize', 12, 'MarkerFaceColor', C(3,:), ...
            'DisplayName', 'BF ideal (K \rightarrow \infty)'); %#ok<AGROW>
    end
    set(ax, 'XTick', [x numel(KS)+0.6], 'XTickLabel', [localKLabels(KS) {'\infty'}], ...
        'XLim', [0.6 numel(KS)+1.0]);
    title(ax, sprintf('d = %.0f m,  R_{eff} = %g bit/s', d, R), 'FontSize', 12, 'Color', INK);
    if c == 1
        ylabel(ax, 'E_{bit} [J/bit]', 'FontSize', 12, 'Color', INK2);
        legend(ax, h, 'Location', 'best', 'Box', 'off', 'FontSize', 10, 'TextColor', INK2);
    end

    % --- unten: Verhaeltnis BF/MUX ---
    ax2 = nexttile(tl, nC + c); localStyle(ax2, INK2); set(ax2, 'YScale', 'log');
    plot(ax2, x, ratio(c,:), '-o', 'Color', INK, 'LineWidth', 2, 'MarkerFaceColor', 'w');
    yline(ax2, 1, '--', 'Color', INK2, 'LineWidth', 1.2, 'Label', 'BF = MUX', ...
        'LabelHorizontalAlignment', 'left', 'FontSize', 9, 'Color', INK2);
    if isfinite(Kstar{c}.K)
        xs = interp1(KS(Kstar{c}.lo:Kstar{c}.lo+1), [Kstar{c}.lo Kstar{c}.lo+1], ...
                     Kstar{c}.K, 'linear');
        xline(ax2, xs, '-', 'Color', C(2,:), 'LineWidth', 1.6, ...
            'Label', sprintf('K* = %.1f (%.1f dB)', Kstar{c}.K, 10*log10(Kstar{c}.K)), ...
            'LabelVerticalAlignment', 'bottom', 'FontSize', 9, 'Color', C(2,:));
    end
    set(ax2, 'XTick', x, 'XTickLabel', localKLabels(KS), 'XLim', [0.6 numel(KS)+1.0]);
    xlabel(ax2, 'Rice-Faktor K', 'FontSize', 12, 'Color', INK2);
    if c == 1
        ylabel(ax2, 'E_{bit}(BF) / E_{bit}(MUX)', 'FontSize', 12, 'Color', INK2);
    end
end
title(tl, 'Energy per bit over the Ricean K factor (scaledB, best over M \leq 256 and N \leq 4)', ...
    'FontSize', 13, 'Color', INK, 'FontWeight', 'bold');
exportgraphics(fig, fullfile(figDir, 'cmp_rice.png'), 'Resolution', 200);

%% ---- Tabelle ---------------------------------------------------------
fprintf('\n==== E_bit [J/bit] ueber K (bestes M und N) ====\n');
fprintf('%-8s %-11s %-6s %-11s %-11s %-9s\n', 'd [m]', 'R [bit/s]', 'K', 'MUX', 'BF', 'BF/MUX');
for c = 1:nC
    for k = 1:numel(KS)
        fprintf('%-8.0f %-11.2g %-6g %-11.3g %-11.3g %-9.3f\n', cases(c,1), ...
            cases(c,2), KS(k), E(c,1,k), E(c,2,k), ratio(c,k));
    end
    s = Kstar{c};
    if isfinite(s.K)
        fprintf('   -> K* = %.1f  (%.1f dB): ab hier ist BF guenstiger\n', s.K, 10*log10(s.K));
    else
        fprintf('   -> %s\n', s.note);
    end
    if isfinite(Eidl(c))
        fprintf('   -> BF ideal (K -> inf): %.3g J/bit\n', Eidl(c));
    end
end

out.cases = cases; out.E = E; out.ratio = ratio; out.Kstar = Kstar; out.Eideal = Eidl;
save(fullfile(figDir, 'rice_summary.mat'), 'out');
fprintf('\ncmp_rice.png und rice_summary.mat in %s\n', figDir);
end

% =======================================================================
function n = localName(mode, K)
if K == 0, n = mode + "_scaledB"; else, n = mode + sprintf("_scaledB_K%g", K); end
end

function S = localLoad(variant)
f = gearboxphy.paths.resultsDir(sprintf('cmp_distance_%s.mat', variant));
if isfile(f), S = load(f); else, S = []; end
end

function s = localFirst(c)
s = [];
for i = 1:numel(c), if ~isempty(c{i}), s = c{i}; return; end, end
end

function [di, ri] = localIndex(CFG, d, R)
[~, di] = min(abs(log10(CFG.distances) - log10(d)));
[~, ri] = min(abs(log10(CFG.rates)     - log10(R)));
% Laut warnen statt still runden. Die Distanzen sind logarithmisch dicht
% (25 Punkte ueber drei Dekaden), die Raten NICHT -- 3b kennt genau zwei.
if abs(log10(CFG.rates(ri)/R)) > log10(1.25)
    warning('analyzeRice:rateSnap', ...
        ['Rate %.3g bit/s liegt nicht im 3b-Raster {%s}; genommen wird %.3g ' ...
         '(Faktor %.1f). Fuer andere Raten 3b mit CFG.rates erweitern.'], ...
        R, strjoin(compose('%g', CFG.rates), ', '), CFG.rates(ri), R/CFG.rates(ri));
end
if abs(log10(CFG.distances(di)/d)) > log10(1.25)
    warning('analyzeRice:distSnap', 'Distanz %g m -> %g m im Raster.', d, CFG.distances(di));
end
end

function e = localBest(S, di, ri)
%LOCALBEST  Bestes E_bit ueber M und N bei einer (Distanz, Rate).
v = squeeze(S.E(di, ri, :, :));
e = min(v(:));
if isempty(e) || ~isfinite(e), e = NaN; end
end

function lbl = localKLabels(KS)
lbl = cell(1, numel(KS));
for i = 1:numel(KS)
    if KS(i) == 0, lbl{i} = '0 (Rayleigh)';
    else,          lbl{i} = sprintf('%g (%.1f dB)', KS(i), 10*log10(KS(i)));
    end
end
end

function s = localKstar(KS, ratio)
%LOCALKSTAR  Erster Durchgang des Verhaeltnisses BF/MUX durch 1.
%
%   Interpoliert in log10(K), weil Arraygewinn und Rangverlust beide mit
%   K/(K+1) skalieren. Zwischen K = 0 und dem naechsten Wert ist log10
%   nicht definiert -- dort wird KEINE Zahl ausgewiesen, sondern das
%   Intervall genannt. Das ist ehrlicher als ein linear interpolierter
%   Wert, der eine Genauigkeit vortaeuschte, die die Stuetzstellen nicht
%   hergeben.
s = struct('K', NaN, 'lo', NaN, 'note', '');
if all(ratio < 1)
    s.note = 'BF ist schon bei K = 0 guenstiger - kein Schnittpunkt im gerechneten Bereich';
    return
end
if all(ratio > 1)
    s.note = 'MUX bleibt bis K = 30 guenstiger - K* liegt oberhalb des gerechneten Bereichs';
    return
end
i = find(ratio(1:end-1) > 1 & ratio(2:end) <= 1, 1);
if isempty(i)
    s.note = 'Verhaeltnis kreuzt 1 nicht monoton - Stuetzstellen ansehen';
    return
end
s.lo = i;
if KS(i) == 0
    s.note = sprintf(['Schnittpunkt zwischen K = 0 und K = %g. Nicht weiter ' ...
        'aufgeloest: log10(0) existiert nicht, und K = 10 wurde ausgelassen.'], KS(i+1));
    return
end
s.K = 10^interp1([ratio(i) ratio(i+1)], log10([KS(i) KS(i+1)]), 1);
end

function localStyle(ax, INK2)
hold(ax, 'on'); grid(ax, 'on'); box(ax, 'off');
set(ax, 'FontSize', 11, 'XColor', INK2, 'YColor', INK2, 'GridAlpha', 0.12);
end
