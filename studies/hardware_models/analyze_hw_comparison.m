function out = analyze_hw_comparison(opts)
%ANALYZE_HW_COMPARISON  Figures and summary table for the comparison of
%   the old and the new component power models in the SISO gearbox
%   (run_hw_comparison, docs/HARDWARE_MODEL_SWITCH.md).
%
%   out = analyze_hw_comparison();                       % defaults
%   out = analyze_hw_comparison(rateTable=[1e5 1e7]);
%
%   For every case it takes, per rate R, the BEST gear over all gears and
%   orders - without the NA-QAM baseline, as plotOptimalGearReport does.
%   One figure set per distance, columns = carriers:
%     hw_gear_d<d>.png     chosen gear over the rate, one line per variant
%     hw_budget_d<d>.png   power budget of the chosen gear over the rate
%                          (shares of E_bit), one row per variant
%     hw_ebit_d<d>.png     E_bit of the chosen gear, and its ratio to the
%                          reference variant (cfg.reference)
%   plus summary.csv / summary.mat (one row per variant x carrier x rate
%   in rateTable, with the budget shares) and the same table in the
%   console.
%
%   Variants without a results directory are left out, so this runs on
%   whatever run_hw_comparison has computed (old/new, or all five).
arguments
    opts.root (1,1) string = ""
    opts.figDir (1,1) string = ""
    opts.rateTable (1,:) double = [1e4 1e6 1e8 1e9 1e10]
    opts.cfg struct = struct([])
end
if isempty(opts.cfg), cfg = hw_comparison_config(); else, cfg = opts.cfg; end
if opts.root ~= "", cfg.root = char(opts.root); end
figDir = opts.figDir;
if figDir == "", figDir = string(fullfile(cfg.root, 'figures')); end
if ~isfolder(figDir), mkdir(figDir); end

% MATLAB default colour order
COL = [0 0.4470 0.7410; 0.8500 0.3250 0.0980; 0.9290 0.6940 0.1250; 0.4940 0.1840 0.5560; ...
       0.4660 0.6740 0.1880; 0.3010 0.7450 0.9330; 0.6350 0.0780 0.1840];
STY = ["-" "--" ":" "-." "-"];
% Budget components: Tx and Rx parts of LO and mixer are added up.
COMP = struct('label', {"PA", "DAC", "LO", "Mixer", "LNA", "ADC", "Energy detector"}, ...
              'fields', {"PA", "DAC", ["LO_Tx" "LO_Rx"], ["Mix_Tx" "Mix_Rx"], "LNA", "ADC", "EnergyDetector"});

[combos, comboLabels] = localCombos();
nF = numel(cfg.fcVec);
rows = cell(0, 8 + numel(COMP));

for d = cfg.distances
    % ---- load every variant that has been computed ---------------------
    data = {}; labels = strings(0); names = strings(0);
    for v = cfg.variants
        c = hw_comparison_case(cfg, v.name, d);
        if ~isfolder(c.dir), continue, end
        dk = localLoadCase(c, cfg, combos, COMP);
        if isempty(dk)
            warning('hw:emptyCase', '%s has no result files yet - skipped.', c.dir);
            continue
        end
        data{end+1} = dk; labels(end+1) = c.label; names(end+1) = v.name; %#ok<AGROW>
    end
    if isempty(data), continue, end
    nV = numel(data);
    ref = find(names == cfg.reference, 1);
    tag = sprintf('d%g', d);

    % ---- chosen gear ----------------------------------------------------
    fig = figure('Position', [100 100 max(360*nF+160, 900) 380], 'Color', 'w', 'Visible', 'off');
    tl = tiledlayout(fig, 1, nF, 'TileSpacing', 'compact', 'Padding', 'compact');
    for f = 1:nF
        ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on');
        set(ax, 'XScale', 'log', 'YLim', [0.5 numel(comboLabels)+0.5], 'YTick', 1:numel(comboLabels));
        if f == 1, set(ax, 'YTickLabel', comboLabels); else, set(ax, 'YTickLabel', []); end
        for m = 1:nV
            % small vertical offset per variant so identical choices stay visible
            stairs(ax, cfg.RVec, data{m}.idx(:, f) + (m - (nV+1)/2)*0.14, char(STY(m)), ...
                'Color', COL(m, :), 'LineWidth', 1.8, 'DisplayName', labels(m));
        end
        title(ax, sprintf('f_c = %g GHz', cfg.fcVec(f)/1e9), 'FontWeight', 'normal');
        xlabel(ax, 'R_{eff} [bit/s]'); xlim(ax, [min(cfg.RVec) max(cfg.RVec)]);
    end
    lg = legend(ax, 'Orientation', 'horizontal', 'Box', 'off'); lg.Layout.Tile = 'south';
    title(tl, sprintf('SISO gearbox, d = %g m: chosen gear', d), 'FontWeight', 'bold');
    exportgraphics(fig, fullfile(figDir, "hw_gear_" + tag + ".png"), 'Resolution', 200);
    close(fig);

    % ---- power budget of the chosen gear --------------------------------
    fig = figure('Position', [100 100 max(360*nF+120, 900) 250*nV+110], 'Color', 'w', 'Visible', 'off');
    tl = tiledlayout(fig, nV, nF, 'TileSpacing', 'compact', 'Padding', 'compact');
    for m = 1:nV
        for f = 1:nF
            ax = nexttile(tl); hold(ax, 'on');
            share = 100 * squeeze(data{m}.share(:, f, :));     % nR x nComp
            ok = ~any(isnan(share), 2);                         % rates no gear can serve stay empty
            h = area(ax, cfg.RVec(ok), share(ok, :), 'LineStyle', 'none');
            for k = 1:numel(h), h(k).FaceColor = COL(k, :); h(k).DisplayName = COMP(k).label; end
            % mark the rates at which the chosen gear changes
            chg = find(diff(data{m}.idx(:, f)) ~= 0 & ~isnan(diff(data{m}.idx(:, f))));
            for r = chg(:)'
                xline(ax, sqrt(cfg.RVec(r)*cfg.RVec(r+1)), '-', 'Color', [1 1 1], 'LineWidth', 1, ...
                    'HandleVisibility', 'off');
            end
            set(ax, 'XScale', 'log', 'YLim', [0 100], 'Layer', 'top');
            xlim(ax, [min(cfg.RVec) max(cfg.RVec)]);
            title(ax, sprintf('%s, f_c = %g GHz', labels(m), cfg.fcVec(f)/1e9), 'FontWeight', 'normal');
            if f == 1, ylabel(ax, 'Share of E_{bit} [%]'); end
            if m == nV, xlabel(ax, 'R_{eff} [bit/s]'); end
        end
    end
    lg = legend(ax, 'Orientation', 'horizontal', 'Box', 'off'); lg.Layout.Tile = 'south';
    title(tl, sprintf('SISO gearbox, d = %g m: power budget of the chosen gear', d), 'FontWeight', 'bold');
    subtitle(tl, 'white lines: the chosen gear changes', 'FontSize', 9);
    exportgraphics(fig, fullfile(figDir, "hw_budget_" + tag + ".png"), 'Resolution', 200);
    close(fig);

    % ---- E_bit and ratio to the reference -------------------------------
    fig = figure('Position', [100 100 max(360*nF+120, 900) 620], 'Color', 'w', 'Visible', 'off');
    tl = tiledlayout(fig, 2, nF, 'TileSpacing', 'compact', 'Padding', 'compact');
    for row = 1:2
        for f = 1:nF
            ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on');
            set(ax, 'XScale', 'log', 'YScale', 'log');
            for m = 1:nV
                y = data{m}.Ebest(:, f);
                if row == 2
                    if isempty(ref), continue, end
                    y = y ./ data{ref}.Ebest(:, f);
                end
                plot(ax, cfg.RVec, y, char(STY(m)), 'Color', COL(m, :), 'LineWidth', 1.8, ...
                    'DisplayName', labels(m));
            end
            xlim(ax, [min(cfg.RVec) max(cfg.RVec)]);
            if row == 1
                title(ax, sprintf('f_c = %g GHz', cfg.fcVec(f)/1e9), 'FontWeight', 'normal');
                if f == 1, ylabel(ax, 'E_{bit} [J/bit]'); end
            else
                xlabel(ax, 'R_{eff} [bit/s]');
                if f == 1, ylabel(ax, sprintf('E_{bit} / E_{bit}(%s)', cfg.reference)); end
            end
        end
    end
    lg = legend(ax, 'Orientation', 'horizontal', 'Box', 'off'); lg.Layout.Tile = 'south';
    title(tl, sprintf('SISO gearbox, d = %g m: energy per bit of the chosen gear', d), 'FontWeight', 'bold');
    exportgraphics(fig, fullfile(figDir, "hw_ebit_" + tag + ".png"), 'Resolution', 200);
    close(fig);

    % ---- table rows -----------------------------------------------------
    for m = 1:nV
        dk = data{m};
        for f = 1:nF
            for R = opts.rateTable
                [~, r] = min(abs(log10(cfg.RVec) - log10(R)));
                Eref = NaN;
                if ~isempty(ref), Eref = data{ref}.Ebest(r, f); end
                g = "-";
                if ~isnan(dk.idx(r, f)), g = comboLabels(dk.idx(r, f)); end
                rows(end+1, :) = [{d, char(names(m)), cfg.fcVec(f)/1e9, cfg.RVec(r), dk.Ebest(r, f), ...
                    dk.Ebest(r, f)/Eref, char(g), dk.Bopt(r, f)}, ...
                    num2cell(100 * squeeze(dk.share(r, f, :))')]; %#ok<AGROW>
            end
        end
    end
end

assert(~isempty(rows) && any(isfinite(cell2mat(rows(:, 5)))), 'hw:noData', ...
    'No results under %s - run run_hw_comparison first.', cfg.root);
shareNames = cellstr("share_" + regexprep([COMP.label], '\s', '') + "_pct");
T = cell2table(rows, 'VariableNames', [{'distance_m', 'variant', 'fc_GHz', 'R_bps', 'Ebit_J', ...
    'ratioToRef', 'gear', 'B_Hz'}, shareNames]);
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

function dk = localLoadCase(c, cfg, combos, COMP)
% Best gear per rate and carrier. Ebest/idx/Bopt are nR x nF, share is
% nR x nF x nComp (shares of E_bit, summing to 1). Returns [] if the case
% has no result file at all (directory created, not yet computed).
nR = numel(cfg.RVec); nF = numel(cfg.fcVec); nC = numel(combos);
nFound = 0;
dk.Ebest = NaN(nR, nF); dk.idx = NaN(nR, nF); dk.Bopt = NaN(nR, nF);
dk.share = NaN(nR, nF, numel(COMP));
for f = 1:nF
    E = NaN(nR, nC); B = NaN(nR, nC); PB = cell(nR, nC);
    for k = 1:nC
        key = gearboxphy.data.resultKey(combos(k).gear, combos(k).order, cfg.fcVec(f));
        file = fullfile(c.dir, key + ".mat");
        if ~isfile(file)
            warning('hw:missingFile', '%s missing.', file);
            continue
        end
        S = load(file, 'RVec', 'E_per_bit', 'Optimal_B', 'PowerBudget');
        nFound = nFound + 1;
        assert(isequal(S.RVec, cfg.RVec), 'hw:rvec', '%s: RVec differs from config.', file);
        E(:, k) = S.E_per_bit; B(:, k) = S.Optimal_B; PB(:, k) = S.PowerBudget;
    end
    for r = 1:nR
        [e, k] = min(E(r, :));   % min ignores NaN; all-NaN gives NaN
        if isnan(e), continue, end
        dk.Ebest(r, f) = e; dk.idx(r, f) = k; dk.Bopt(r, f) = B(r, k);
        pb = PB{r, k};
        if ~isstruct(pb), continue, end
        known = [COMP.fields];
        extra = setdiff(string(fieldnames(pb))', known);
        assert(isempty(extra), 'hw:budgetField', ...
            'Budget of %s has a term this script does not know: %s.', combos(k).gear, strjoin(extra, ', '));
        p = zeros(1, numel(COMP));
        for j = 1:numel(COMP)
            for fn = COMP(j).fields
                if isfield(pb, fn), p(j) = p(j) + pb.(fn); end
            end
        end
        dk.share(r, f, :) = p / sum(p);
    end
end
if nFound == 0, dk = []; end
end
