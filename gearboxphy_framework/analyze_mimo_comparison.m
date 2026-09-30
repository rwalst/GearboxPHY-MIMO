function out = analyze_mimo_comparison(opts)
%ANALYZE_MIMO_COMPARISON  Schritt 4 des BF/MUX-Vergleichs: Auswertung und
%   Abbildungen aus den Laeufen von Schritt 3.
%
%   out = analyze_mimo_comparison();                 % Defaults
%   out = analyze_mimo_comparison(distances=[50 5000]);
%
%   Liest
%     results_cmp_<variante>_d<d>/qam_M<M>_fc28GHz.mat   (Schritt 3a)
%     results_cmp_distance_<variante>.mat                (Schritt 3b, optional)
%   und schreibt nach results_cmp_figures/:
%     cmp_ebit.png         E_bit ueber R_eff: SISO, bestes MUX, bestes BF,
%                          jeweils V0 (durchgezogen) und V1 (gestrichelt)
%     cmp_nopt.png         energieoptimale Antennenzahl ueber R_eff
%     cmp_adc_share.png    ADC-Anteil am Budget im jeweiligen Optimum --
%                          zeigt direkt, was die Regel "+1 Bit je
%                          Verdopplung" kostet
%     cmp_distance.png     Distanzschnitt bei festen Raten (falls 3b da)
%   plus eine Tabelle in der Konsole und results_cmp_figures/summary.mat.
%
%   "Bestes MUX" heisst: Minimum ueber M in {4,16,64,256} UND N in
%   {1,2,4,8,16}. N = 1 ist darin enthalten -- die Kurve kann also nie
%   ueber SISO liegen; wo sie auf SISO faellt, lohnt kein Array.
%
%   Verglichen wird nur QAM mit M <= 256: nur dort gibt es Rayleigh-Kurven
%   fuer alle Antennenzahlen. Die uebrigen Gaenge liegen mit AWGN-Kurven
%   in den Ergebnisordnern und werden hier bewusst ignoriert.
%
%   BF IDEAL (gelb) ist die Obergrenze fuer Beamforming: AWGN statt
%   Rayleigh, voller Gewinn N_t*N_r statt E[lambda_max], Kombination vor
%   dem ADC. Die Luecke zwischen gelb und rot ist das, was Fading und
%   Quantisierung pro Antenne kosten. Die SISO-Linie (schwarz) ist die
%   Rayleigh-1x1-Kurve; die 1x1-Kurve des idealen BF liegt als N = 1 in
%   dessen "bestes"-Kurve und ist AWGN -- dort also NICHT mit schwarz
%   vergleichen.
arguments
    opts.distances (1,:) double = [50 500 5000]
    opts.fcGHz (1,1) double = 28
    opts.Ms (1,:) double = [4 16 64 256]
    opts.Ns (1,:) double = [1 2 4 8 16]
    opts.rateTable (1,:) double = [1e6 1e8 1e9 1e10]
    opts.figDir (1,1) string = "results_cmp_figures"
end

here = fileparts(mfilename('fullpath'));
figDir = fullfile(here, opts.figDir);
if ~isfolder(figDir), mkdir(figDir); end

VARIANTS = ["mux_V0" "mux_V1" "bf_V0" "bf_V1" "bfideal_V0" "bfideal_V1"];
LABEL    = ["MUX V0" "MUX V1" "BF V0" "BF V1" "BF ideal V0" "BF ideal V1"];
C        = lines(3);                % Matlab-Blau (MUX), -Rot (BF), -Gelb (BF ideal)
COL      = [C(1,:); C(1,:); C(2,:); C(2,:); C(3,:); C(3,:)];
STY      = ["-" "--" "-" "--" "-" "--"];
INK  = [0.043 0.043 0.043];
INK2 = [0.322 0.318 0.306];
nV = numel(VARIANTS); nD = numel(opts.distances);
% Rayleigh-Modelle; BF ideal ist eine Obergrenze und liefert weder die
% SISO-Referenz (seine 1x1-Kurve ist AWGN) noch den "besten Modus"
REALISTIC = find(~startsWith(VARIANTS, "bfideal"));

%% ---- Laden -----------------------------------------------------------
data = cell(nV, nD);
for k = 1:nV
    for di = 1:nD
        rd = fullfile(here, sprintf('results_cmp_%s_d%g', VARIANTS(k), opts.distances(di)));
        if ~isfolder(rd)
            warning('analyze:missing', '%s fehlt - Variante %s bei d=%g uebersprungen.', ...
                rd, VARIANTS(k), opts.distances(di));
            continue;
        end
        data{k, di} = localLoad(rd, opts);
    end
end
assert(any(~cellfun(@isempty, data(:))), 'analyze:noData', ...
    'Keine results_cmp_* gefunden - erst run_mimo_comparison_sweep ausfuehren.');

%% ---- Abb. 1: E_bit ---------------------------------------------------
fig = figure('Position', [100 100 360*nD+120 420], 'Color', 'w');
tl = tiledlayout(fig, 1, nD, 'TileSpacing', 'compact', 'Padding', 'compact');
for di = 1:nD
    ax = localAxes(tl, INK2);
    set(ax, 'YScale', 'log');
    h = gobjects(0);
    ref = localFirst(data(REALISTIC, di));
    if ~isempty(ref)
        h(end+1) = plot(ax, ref.R, ref.E(:, opts.Ns == 1), '-', 'Color', INK, ...
            'LineWidth', 2.4, 'DisplayName', 'SISO (1x1)'); %#ok<AGROW>
    end
    for k = 1:nV
        dk = data{k, di};
        if isempty(dk), continue; end
        h(end+1) = plot(ax, dk.R, dk.Ebest, char(STY(k)), 'Color', COL(k,:), ...
            'LineWidth', 2, 'DisplayName', LABEL(k)); %#ok<AGROW>
    end
    title(ax, sprintf('d = %g m', opts.distances(di)), 'FontSize', 12.5, 'Color', INK);
    if di == 1
        ylabel(ax, 'E_{bit} [J/bit]', 'FontSize', 12, 'Color', INK2);
        legend(ax, h, 'Location', 'southwest', 'Box', 'off', 'FontSize', 10, 'TextColor', INK2);
    end
end
xlabel(tl, 'R_{eff} [bit/s]', 'FontSize', 12, 'Color', INK2);
title(tl, sprintf(['Beamforming vs. Multiplexing, f_c = %g GHz, best over M <= 256 and N ' ...
    '(V0 solid, V1 dashed)'], opts.fcGHz), 'FontSize', 13, 'Color', INK, 'FontWeight', 'bold');
exportgraphics(fig, fullfile(figDir, 'cmp_ebit.png'), 'Resolution', 200);

%% ---- Abb. 2: optimale Antennenzahl ------------------------------------
fig = figure('Position', [100 100 360*nD+120 380], 'Color', 'w');
tl = tiledlayout(fig, 1, nD, 'TileSpacing', 'compact', 'Padding', 'compact');
for di = 1:nD
    ax = localAxes(tl, INK2);
    set(ax, 'YScale', 'log', 'YTick', opts.Ns, 'YLim', [0.8 max(opts.Ns)*1.25]);
    h = gobjects(0);
    for k = 1:nV
        dk = data{k, di};
        if isempty(dk), continue; end
        h(end+1) = stairs(ax, dk.R, dk.Nopt, char(STY(k)), 'Color', COL(k,:), ...
            'LineWidth', 2, 'DisplayName', LABEL(k)); %#ok<AGROW>
    end
    title(ax, sprintf('d = %g m', opts.distances(di)), 'FontSize', 12.5, 'Color', INK);
    if di == 1
        ylabel(ax, 'energy-optimal N (N x N)', 'FontSize', 12, 'Color', INK2);
        legend(ax, h, 'Location', 'northwest', 'Box', 'off', 'FontSize', 10, 'TextColor', INK2);
    end
end
xlabel(tl, 'R_{eff} [bit/s]', 'FontSize', 12, 'Color', INK2);
title(tl, 'Energy-optimal array size', 'FontSize', 13, 'Color', INK, 'FontWeight', 'bold');
exportgraphics(fig, fullfile(figDir, 'cmp_nopt.png'), 'Resolution', 200);

%% ---- Abb. 3: ADC-Anteil im Optimum ------------------------------------
fig = figure('Position', [100 100 360*nD+120 380], 'Color', 'w');
tl = tiledlayout(fig, 1, nD, 'TileSpacing', 'compact', 'Padding', 'compact');
for di = 1:nD
    ax = localAxes(tl, INK2);
    set(ax, 'YLim', [0 100]);
    h = gobjects(0);
    for k = 1:nV
        dk = data{k, di};
        if isempty(dk), continue; end
        h(end+1) = plot(ax, dk.R, 100*dk.adcShareBest, char(STY(k)), 'Color', COL(k,:), ...
            'LineWidth', 2, 'DisplayName', LABEL(k)); %#ok<AGROW>
    end
    title(ax, sprintf('d = %g m', opts.distances(di)), 'FontSize', 12.5, 'Color', INK);
    if di == 1
        ylabel(ax, 'ADC share of E_{bit} [%]', 'FontSize', 12, 'Color', INK2);
        legend(ax, h, 'Location', 'northwest', 'Box', 'off', 'FontSize', 10, 'TextColor', INK2);
    end
end
xlabel(tl, 'R_{eff} [bit/s]', 'FontSize', 12, 'Color', INK2);
title(tl, 'What the ADC costs at the optimum (V1: +1 bit per doubling)', ...
    'FontSize', 13, 'Color', INK, 'FontWeight', 'bold');
exportgraphics(fig, fullfile(figDir, 'cmp_adc_share.png'), 'Resolution', 200);

%% ---- Abb. 4: Distanzschnitt (optional) --------------------------------
dist = cell(1, nV);
for k = 1:nV
    f = fullfile(here, sprintf('results_cmp_distance_%s.mat', VARIANTS(k)));
    if isfile(f), dist{k} = load(f); end
end
if any(~cellfun(@isempty, dist))
    iRef = REALISTIC(find(~cellfun(@isempty, dist(REALISTIC)), 1));
    if isempty(iRef), iRef = find(~cellfun(@isempty, dist), 1); end
    ref = dist{iRef};
    rates = ref.CFG.rates; d = ref.CFG.distances(:); nR = numel(rates);
    fig = figure('Position', [100 100 420*nR+120 640], 'Color', 'w');
    tl = tiledlayout(fig, 2, nR, 'TileSpacing', 'compact', 'Padding', 'compact');
    for ri = 1:nR
        ax1 = nexttile(tl, ri); localStyle(ax1, INK2); set(ax1, 'YScale', 'log');
        ax2 = nexttile(tl, nR + ri); localStyle(ax2, INK2);
        set(ax2, 'YScale', 'log', 'YTick', ref.CFG.Ns, 'YLim', [0.8 max(ref.CFG.Ns)*1.25]);
        h = gobjects(0);
        eS = min(squeeze(ref.E(:, ri, :, ref.CFG.Ns == 1)), [], 2);   % SISO, bestes M
        h(end+1) = plot(ax1, d, eS, '-', 'Color', INK, 'LineWidth', 2.4, 'DisplayName', 'SISO (1x1)'); %#ok<AGROW>
        for k = 1:nV
            if isempty(dist{k}), continue; end
            [eB, nB] = localBestDist(dist{k}, ri);
            h(end+1) = plot(ax1, d, eB, char(STY(k)), 'Color', COL(k,:), 'LineWidth', 2, ...
                'DisplayName', LABEL(k)); %#ok<AGROW>
            stairs(ax2, d, nB, char(STY(k)), 'Color', COL(k,:), 'LineWidth', 2);
        end
        title(ax1, sprintf('R_{eff} = %g bit/s', rates(ri)), 'FontSize', 12.5, 'Color', INK);
        xlabel(ax2, 'distance d [m]', 'FontSize', 12, 'Color', INK2);
        if ri == 1
            ylabel(ax1, 'E_{bit} [J/bit]', 'FontSize', 12, 'Color', INK2);
            ylabel(ax2, 'energy-optimal N', 'FontSize', 12, 'Color', INK2);
            legend(ax1, h, 'Location', 'northwest', 'Box', 'off', 'FontSize', 10, 'TextColor', INK2);
        end
    end
    title(tl, 'Distance sweep at fixed rates, best over M <= 256 and N', ...
        'FontSize', 13, 'Color', INK, 'FontWeight', 'bold');
    exportgraphics(fig, fullfile(figDir, 'cmp_distance.png'), 'Resolution', 200);
end

%% ---- Tabelle -----------------------------------------------------------
fprintf('\n==== E_bit [J/bit] im jeweiligen Optimum (in Klammern: N) ====\n');
fprintf('%-7s %-9s %-11s', 'd [m]', 'R [bit/s]', 'SISO');
fprintf(' %-15s', LABEL); fprintf(' %s\n', 'bester Modus (ohne ideal)');
for di = 1:nD
    ref = localFirst(data(REALISTIC, di));
    if isempty(ref), continue; end
    for Rq = opts.rateTable
        [~, i] = min(abs(log10(ref.R) - log10(Rq)));
        fprintf('%-7g %-9.2g %-11.3g', opts.distances(di), ref.R(i), ref.E(i, opts.Ns == 1));
        best = inf; winner = "-";
        for k = 1:nV
            dk = data{k, di};
            if isempty(dk) || ~isfinite(dk.Ebest(i))
                fprintf(' %-15s', '-'); continue;
            end
            fprintf(' %-15s', sprintf('%.3g (%dx%d)', dk.Ebest(i), dk.Nopt(i), dk.Nopt(i)));
            if ismember(k, REALISTIC) && dk.Ebest(i) < best
                best = dk.Ebest(i); winner = LABEL(k);
            end
        end
        fprintf(' %s\n', winner);
    end
end

out = struct('variants', VARIANTS, 'distances', opts.distances, 'data', {data}, ...
             'distance', {dist}, 'opts', opts);
save(fullfile(figDir, 'summary.mat'), 'out');
fprintf('\nAbbildungen und summary.mat in %s\n', figDir);
end

% =======================================================================
function s = localLoad(rd, opts)
%LOCALLOAD  Je Antennenzahl N das Minimum ueber M, dazu ADC-/PA-Anteil im
%   jeweiligen Optimum.
nN = numel(opts.Ns);
s = struct('R', [], 'E', [], 'Mbest', [], 'adcShare', []);
for M = opts.Ms
    f = fullfile(rd, sprintf('qam_M%d_fc%gGHz.mat', M, opts.fcGHz));
    if ~isfile(f)
        warning('analyze:missingM', '%s fehlt.', f);
        continue;
    end
    S = load(f);
    if isempty(s.R)
        s.R = S.RVec(:);
        nR = numel(s.R);
        s.E = inf(nR, nN); s.Mbest = nan(nR, nN); s.adcShare = nan(nR, nN);
    end
    assert(numel(S.RVec) == numel(s.R), 'analyze:grid', '%s: anderes Ratenraster', f);
    nt = cellfun(@(c) c.N_t, S.antennaConfigsUsed);
    for j = 1:numel(nt)
        ni = find(opts.Ns == nt(j), 1);
        if isempty(ni), continue; end
        e = S.E_per_bit_all(:, j);
        e(~isfinite(e)) = inf;
        better = find(e < s.E(:, ni));
        s.E(better, ni) = e(better);
        s.Mbest(better, ni) = M;
        for i = better(:).'
            pb = S.PowerBudget_all{i, j};
            if isstruct(pb)
                s.adcShare(i, ni) = pb.ADC / sum(struct2array(pb));
            end
        end
    end
end
if isempty(s.R), s = []; return; end
s.E(~isfinite(s.E)) = NaN;
% bestes N je Rate
[s.Ebest, iN] = min(s.E, [], 2);             % 'omitnan' ist Default
dead = all(isnan(s.E), 2);
s.Nopt = opts.Ns(iN).';
s.Nopt(dead) = NaN; s.Ebest(dead) = NaN;
idx = sub2ind(size(s.adcShare), (1:numel(s.R)).', iN);
s.adcShareBest = s.adcShare(idx);
s.adcShareBest(dead) = NaN;
end

function [eB, nB] = localBestDist(D, ri)
%LOCALBESTDIST  Distanzschnitt: Minimum ueber M und N, dazu das optimale N.
eMN = squeeze(D.E(:, ri, :, :));             % nD x nM x nN
eN  = squeeze(min(eMN, [], 2));              % nD x nN
[eB, iN] = min(eN, [], 2);
dead = all(isnan(eN), 2);
nB = D.CFG.Ns(iN).'; nB(dead) = NaN; eB(dead) = NaN;
end

function s = localFirst(c)
s = [];
for i = 1:numel(c)
    if ~isempty(c{i}), s = c{i}; return; end
end
end

function ax = localAxes(tl, INK2)
ax = nexttile(tl);
localStyle(ax, INK2);
end

function localStyle(ax, INK2)
hold(ax, 'on'); grid(ax, 'on'); box(ax, 'off');
set(ax, 'XScale', 'log', 'FontSize', 11, 'XColor', INK2, 'YColor', INK2, 'GridAlpha', 0.12);
end
