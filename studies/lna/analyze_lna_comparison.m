function out = analyze_lna_comparison(opts)
%ANALYZE_LNA_COMPARISON  Figures and summary table for the LNA-model
%   comparison (run_lna_comparison, LNA_POWER_MODEL.md).
%
%   out = analyze_lna_comparison();                       % defaults
%   out = analyze_lna_comparison(rateTable=[1e5 1e7]);
%
%   For every case it takes, per rate R, the BEST gear over all gears and
%   orders - without the NA-QAM baseline, as plotOptimalGearReport does -
%   and compares the three LNA models on it. One figure set per study and
%   distance, tiles = bandwidth setting (rows) x carrier (columns):
%     lna_ebit_<study>_d<d>.png    E_bit of the best gear
%     lna_ratio_<study>_d<d>.png   E_bit / E_bit(dissertation model)
%     lna_share_<study>_d<d>.png   LNA share of E_bit at the optimum
%     lna_gear_<study>_d<d>.png    optimal gear
%     lna_nopt_<study>_d<d>.png    optimal N (beamforming only)
%   plus summary.csv / summary.mat (one row per case x carrier x rate in
%   rateTable) and the same table in the console.
%
%   Missing cases or result files are skipped with a warning, so this can
%   be run on a partial sweep (e.g. SISO only).
arguments
    opts.root (1,1) string = ""
    opts.figDir (1,1) string = ""
    opts.rateTable (1,:) double = [1e4 1e6 1e8 1e9]
    opts.cfg struct = struct([])
end
if isempty(opts.cfg), cfg = lna_comparison_config(); else, cfg = opts.cfg; end
if opts.root ~= "", cfg.root = char(opts.root); end
figDir = opts.figDir;
if figDir == "", figDir = string(fullfile(cfg.root, 'figures')); end
if ~isfolder(figDir), mkdir(figDir); end

% Colours as in LituratureReview/lna_survey_fit/plot_lna_models.py
MODEL_COL = [0.322 0.318 0.306; 0.106 0.686 0.478; 0.922 0.408 0.204];
MODEL_STY = ["-" "--" "-"];
MODEL_LW  = [1.5 2 2];
INK  = [0.043 0.043 0.043];
INK2 = [0.322 0.318 0.306];

[combos, comboLabels] = localCombos();
nM = numel(cfg.models); nB = numel(cfg.bw); nF = numel(cfg.fcVec);
rows = cell(0, 12);

for study = cfg.studies
    for d = cfg.distances.(char(study))
        % ---- load: data{b, m} ----------------------------------------
        data = cell(nB, nM);
        for b = 1:nB
            for m = 1:nM
                c = lna_comparison_case(cfg, study, cfg.bw(b), cfg.models(m), d);
                if ~isfolder(c.dir)
                    warning('lna:missingCase', '%s missing - skipped.', c.dir);
                    continue
                end
                data{b, m} = localLoadCase(c, cfg, combos);
                if isempty(data{b, m})
                    warning('lna:emptyCase', '%s has no result files yet - skipped.', c.dir);
                end
            end
        end
        if all(cellfun(@isempty, data(:))), continue, end
        tag = sprintf('%s_d%g', study, d);
        ttl = sprintf('%s, d = %g m', study, d);

        % ---- figures --------------------------------------------------
        localFigure(figDir, "lna_ebit_" + tag, ttl + ": E_{bit} of the best gear", ...
            data, cfg, 'E_{bit} [J/bit]', 'log', @(dk, f) dk.Ebest(:, f), ...
            MODEL_COL, MODEL_STY, MODEL_LW, INK, INK2, []);
        localFigure(figDir, "lna_ratio_" + tag, ttl + ": E_{bit} / E_{bit}(dissertation model)", ...
            data, cfg, 'ratio', 'log', @(dk, f) dk.Ebest(:, f), ...
            MODEL_COL, MODEL_STY, MODEL_LW, INK, INK2, 1);
        localFigure(figDir, "lna_share_" + tag, ttl + ": LNA share of E_{bit} at the optimum", ...
            data, cfg, 'LNA share [%]', 'linear', @(dk, f) 100*dk.lnaShare(:, f), ...
            MODEL_COL, MODEL_STY, MODEL_LW, INK, INK2, []);
        localGearFigure(figDir, "lna_gear_" + tag, ttl + ": optimal gear", data, cfg, ...
            comboLabels, MODEL_COL, MODEL_STY, MODEL_LW, INK, INK2);
        if study == "beamforming"
            localFigure(figDir, "lna_nopt_" + tag, ttl + ": energy-optimal N (N x N)", ...
                data, cfg, 'N', 'log', @(dk, f) dk.Nopt(:, f), ...
                MODEL_COL, MODEL_STY, MODEL_LW, INK, INK2, []);
        end

        % ---- table rows -----------------------------------------------
        for b = 1:nB
            ref = data{b, 1};
            for m = 1:nM
                dk = data{b, m};
                if isempty(dk), continue, end
                for f = 1:nF
                    for R = opts.rateTable
                        [~, r] = min(abs(log10(cfg.RVec) - log10(R)));
                        Eref = NaN;
                        if ~isempty(ref), Eref = ref.Ebest(r, f); end
                        g = "-";
                        if ~isnan(dk.idx(r, f)), g = comboLabels(dk.idx(r, f)); end
                        rows(end+1, :) = {char(study), d, char(cfg.bw(b).name), char(cfg.models(m)), ...
                            cfg.fcVec(f)/1e9, cfg.RVec(r), dk.Ebest(r, f), dk.Ebest(r, f)/Eref, ...
                            char(g), dk.Bopt(r, f), dk.Nopt(r, f), 100*dk.lnaShare(r, f)}; %#ok<AGROW>
                    end
                end
            end
        end
    end
end

assert(~isempty(rows) && any(isfinite(cell2mat(rows(:, 7)))), 'lna:noData', ...
    'No results under %s - run run_lna_comparison first.', cfg.root);
T = cell2table(rows, 'VariableNames', {'study', 'distance_m', 'bw', 'lnaModel', ...
    'fc_GHz', 'R_bps', 'Ebit_J', 'ratioToDiss', 'gear', 'B_Hz', 'N', 'lnaShare_pct'});
writetable(T, fullfile(figDir, 'summary.csv'));
save(fullfile(figDir, 'summary.mat'), 'T');
disp(T);
fprintf('\nFigures and summary in %s\n', figDir);
out.table = T;
out.figDir = figDir;
end

%% ======================================================================
function [combos, labels] = localCombos()
% Every (gear, order) except the baseline gear, in registry order.
gears = gearboxphy.gears.gearRegistry();
combos = struct('gear', {}, 'order', {});
labels = strings(0);
for gi = 1:numel(gears)
    if gearboxphy.gears.isBaselineGear(gears{gi}), continue, end
    for o = gears{gi}.orders
        combos(end+1) = struct('gear', gears{gi}.name, 'order', o); %#ok<AGROW>
        if numel(gears{gi}.orders) > 1
            labels(end+1) = sprintf('%s %g', gears{gi}.name, o); %#ok<AGROW>
        else
            labels(end+1) = gears{gi}.name; %#ok<AGROW>
        end
    end
end
end

function dk = localLoadCase(c, cfg, combos)
% Best gear per rate and carrier. Fields are nR x nF. Returns [] if the
% case has no result file at all (directory created, not yet computed).
nR = numel(cfg.RVec); nF = numel(cfg.fcVec); nC = numel(combos);
nFound = 0;
dk.Ebest = NaN(nR, nF); dk.idx = NaN(nR, nF); dk.Bopt = NaN(nR, nF);
dk.Nopt = NaN(nR, nF); dk.lnaShare = NaN(nR, nF);
for f = 1:nF
    E = NaN(nR, nC); B = NaN(nR, nC); N = NaN(nR, nC); PB = cell(nR, nC);
    for k = 1:nC
        key = gearboxphy.data.resultKey(combos(k).gear, combos(k).order, cfg.fcVec(f));
        file = fullfile(c.dir, key + ".mat");
        if ~isfile(file)
            warning('lna:missingFile', '%s missing.', file);
            continue
        end
        S = load(file, 'RVec', 'E_per_bit', 'Optimal_B', 'Optimal_N_r', 'PowerBudget');
        nFound = nFound + 1;
        assert(isequal(S.RVec, cfg.RVec), 'lna:rvec', '%s: RVec differs from config.', file);
        E(:, k) = S.E_per_bit; B(:, k) = S.Optimal_B; N(:, k) = S.Optimal_N_r;
        PB(:, k) = S.PowerBudget;
    end
    for r = 1:nR
        [e, k] = min(E(r, :));   % min ignores NaN; all-NaN gives NaN
        if isnan(e), continue, end
        dk.Ebest(r, f) = e; dk.idx(r, f) = k;
        dk.Bopt(r, f) = B(r, k); dk.Nopt(r, f) = N(r, k);
        pb = PB{r, k};
        if isstruct(pb)
            v = cellfun(@(fn) pb.(fn), fieldnames(pb));   % all budget terms, J/bit
            dk.lnaShare(r, f) = pb.LNA / sum(v);
        end
    end
end
if nFound == 0, dk = []; end
end

function localFigure(figDir, name, ttl, data, cfg, yl, yscale, getY, COL, STY, LW, INK, INK2, ratioRef)
% ratioRef non-empty -> plot getY(model)/getY(model 1).
nB = size(data, 1); nM = size(data, 2); nF = numel(cfg.fcVec);
fig = figure('Position', [100 100 330*nF+80 290*nB+90], 'Color', 'w', 'Visible', 'off');
tl = tiledlayout(fig, nB, nF, 'TileSpacing', 'compact', 'Padding', 'compact');
h = gobjects(1, nM);
for b = 1:nB
    for f = 1:nF
        ax = nexttile(tl); hold(ax, 'on'); box(ax, 'off'); grid(ax, 'on');
        set(ax, 'XScale', 'log', 'YScale', yscale, 'XColor', INK2, 'YColor', INK2, ...
            'GridColor', [0.89 0.89 0.87], 'GridAlpha', 1);
        for m = 1:nM
            dk = data{b, m};
            if isempty(dk), continue, end
            y = getY(dk, f);
            if ~isempty(ratioRef)
                if isempty(data{b, 1}), continue, end
                y = y ./ getY(data{b, 1}, f);
            end
            h(m) = plot(ax, cfg.RVec, y, char(STY(m)), 'Color', COL(m, :), 'LineWidth', LW(m), ...
                'DisplayName', cfg.modelLabels(m));
        end
        title(ax, sprintf('%s, f_c = %g GHz', cfg.bw(b).label, cfg.fcVec(f)/1e9), ...
            'FontSize', 10, 'Color', INK, 'FontWeight', 'normal');
        if f == 1, ylabel(ax, yl, 'Color', INK2); end
        if b == nB, xlabel(ax, 'R_{eff} [bit/s]', 'Color', INK2); end
    end
end
localLegend(ax, isgraphics(h), cfg, COL, STY, LW, INK2);
title(tl, ttl, 'FontSize', 12, 'Color', INK, 'FontWeight', 'bold');
exportgraphics(fig, fullfile(figDir, name + ".png"), 'Resolution', 200);
close(fig);
end

function localGearFigure(figDir, name, ttl, data, cfg, labels, COL, STY, LW, INK, INK2)
nB = size(data, 1); nM = size(data, 2); nF = numel(cfg.fcVec);
fig = figure('Position', [100 100 360*nF+140 300*nB+90], 'Color', 'w', 'Visible', 'off');
tl = tiledlayout(fig, nB, nF, 'TileSpacing', 'compact', 'Padding', 'compact');
h = gobjects(1, nM);
for b = 1:nB
    for f = 1:nF
        ax = nexttile(tl); hold(ax, 'on'); box(ax, 'off'); grid(ax, 'on');
        set(ax, 'XScale', 'log', 'XColor', INK2, 'YColor', INK2, 'YLim', [0.5 numel(labels)+0.5], ...
            'YTick', 1:numel(labels), 'GridColor', [0.89 0.89 0.87], 'GridAlpha', 1);
        if f == 1
            set(ax, 'YTickLabel', labels);
        else
            set(ax, 'YTickLabel', []);
        end
        for m = 1:nM
            dk = data{b, m};
            if isempty(dk), continue, end
            % small vertical offset per model so identical choices stay visible
            h(m) = stairs(ax, cfg.RVec, dk.idx(:, f) + (m-2)*0.12, char(STY(m)), ...
                'Color', COL(m, :), 'LineWidth', LW(m), 'DisplayName', cfg.modelLabels(m));
        end
        title(ax, sprintf('%s, f_c = %g GHz', cfg.bw(b).label, cfg.fcVec(f)/1e9), ...
            'FontSize', 10, 'Color', INK, 'FontWeight', 'normal');
        if b == nB, xlabel(ax, 'R_{eff} [bit/s]', 'Color', INK2); end
    end
end
localLegend(ax, isgraphics(h), cfg, COL, STY, LW, INK2);
title(tl, ttl, 'FontSize', 12, 'Color', INK, 'FontWeight', 'bold');
exportgraphics(fig, fullfile(figDir, name + ".png"), 'Resolution', 200);
close(fig);
end

function localLegend(ax, present, cfg, COL, STY, LW, INK2)
% Legend from invisible dummy lines in ONE axes, so it never mixes handles
% from different tiles. present(m) = model m was plotted somewhere.
if ~any(present), return, end
hl = gobjects(0);
for m = find(present)
    hl(end+1) = plot(ax, NaN, NaN, char(STY(m)), 'Color', COL(m, :), 'LineWidth', LW(m), ...
        'DisplayName', cfg.modelLabels(m)); %#ok<AGROW>
end
lg = legend(ax, hl, 'Orientation', 'horizontal', 'Box', 'off', 'TextColor', INK2);
lg.Layout.Tile = 'south';
end
