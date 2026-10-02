function fig = plotOptimalGearReport(resultsDir, scenario, opts)
%PLOTOPTIMALGEARREPORT The argmin-gear-per-rate plot, ported from
%   Wrapper.m's "Optimal Gear" section. The baseline gear (NA-QAM) is
%   excluded from the argmin set via gear.isBaseline (see
%   +gears/isBaselineGear.m) rather than a hardcoded name string - it is
%   plotted as the savings baseline instead (plotSavingsReport.m).
%
%   A combo with no result file yet renders as a NaN row; any other load
%   error propagates instead of being silently swallowed (code review
%   finding #2 - see plotEnergyReport.m for the full rationale).
%
%   Y-axis order is a fixed, explicit gear-family priority (not
%   gearRegistry()'s registration order): Pulse-Energy, Pulse-Arbitrary,
%   ZXM, QAM bottom-to-top, orders ascending within each - low-power/
%   low-rate gears at the bottom, higher-throughput QAM at the top, so
%   the plot reads the same way the Gearbox-PHY gear-switching story
%   itself does. Any future gear not named in gearPriority falls back to
%   being appended at the end rather than silently vanishing.
%
%   Three separate visual encodings, kept on three separate channels so
%   they don't interfere with each other:
%     COLOR      -> carrier frequency f_c (one color per fcVec entry)
%     LINE STYLE -> MIMO+SISO nested-enumeration winner (solid) vs. the
%                   SISO-only winner (dashed), i.e. what the optimal gear
%                   would have been if MIMO were never available - reuses
%                   the per-candidate E_per_bit_all/antennaConfigsUsed
%                   saved by runSweep.m/saveAllResults.m, picking out
%                   just the N_t=1,N_r=1 column instead of the winner
%                   column. A results file predating that field (no
%                   antennaConfigsUsed) simply can't supply the SISO-only
%                   curve - left as NaN for that row rather than guessed.
%     MARKER     -> winning antenna count on the MIMO+SISO curve only
%                   (o=1x1, s=2x2, ^=4x4, d=8x8); omitted on the
%                   SISO-only curve since it is 1x1 by construction there
%                   and a marker would say nothing new.
%
%   maxMarkersPerRun caps how many markers each contiguous run of equal
%   N_t gets (see the decimation note below); raise it for a denser
%   read, lower it for a cleaner slide.
arguments
    resultsDir
    scenario (1,1) struct
    opts.maxMarkersPerRun (1,1) double {mustBePositive} = 4
end
resultsDir = gearboxphy.paths.resultsDir(resultsDir);   % Name -> results/<name>

gearPriority = ["Pulse-Energy", "Pulse-Arbitrary", "ZXM", "QAM"];
maxMarkersPerRun = opts.maxMarkersPerRun;
markerByNt = containers.Map({1,2,4,8}, {'o','s','^','d'});
% N_t -> "N_txN_r" legend label, filled from the antennaConfigsUsed
% actually stored in the results (markerByNt is keyed on N_t alone, so a
% non-square config like 2x4 would be mislabelled if N_r were assumed
% equal to N_t instead of read back).
ntLabels = containers.Map('KeyType','double','ValueType','char');

gears = gearboxphy.gears.gearRegistry();
n = numel(scenario.RVec);

noNaGears = {};
for gi = 1:numel(gears)
    if ~gearboxphy.gears.isBaselineGear(gears{gi})
        noNaGears{end+1} = gears{gi}; %#ok<AGROW>
    end
end
priorityRank = cellfun(@(g) find([gearPriority == g.name, true], 1, 'first'), noNaGears);
[~, order_] = sort(priorityRank);
noNaGears = noNaGears(order_);

legendNames = strings(0);
for gi = 1:numel(noNaGears)
    for oi = 1:numel(noNaGears{gi}.orders)
        legendNames(end+1) = sprintf('%s (order=%g)', noNaGears{gi}.name, noNaGears{gi}.orders(oi)); %#ok<AGROW>
    end
end

fig = figure();
ax = axes(fig);
ax.XScale = 'log';   % set explicitly, before any plotting - see note below
hold(ax, 'on');
% Note on a bug this replaces (kept from the previous revision of this
% file): calling hold('on') on a fresh axes BEFORE the first plot call
% sets NextPlot='add' immediately, and plot()/semilogx() then don't
% reliably (re)set XScale on that first call the way they would with
% NextPlot at its default 'replace'. Setting ax.XScale explicitly up
% front sidesteps that ordering dependency rather than relying on a
% plotting function to infer it.
colors = lines(numel(scenario.fcVec));
ntValuesUsed = [];

for fi = 1:numel(scenario.fcVec)
    f_c = scenario.fcVec(fi);
    col = colors(fi,:);

    E_bit_all = [];    % nRows x n: MIMO+SISO winner per row
    E_bit_siso = [];   % nRows x n: SISO-only (N_t=1,N_r=1) per row
    Nt_all = [];       % nRows x n: winning N_t per row, for markers

    for gi = 1:numel(noNaGears)
        gear = noNaGears{gi};
        for oi = 1:numel(gear.orders)
            key = gearboxphy.data.resultKey(gear.name, gear.orders(oi), f_c);
            if isfile(fullfile(resultsDir, key + ".mat"))
                S = gearboxphy.data.loadAllResults(resultsDir, key);
                E_bit_all(end+1,:) = S.E_per_bit(:).'; %#ok<AGROW>
                if isfield(S, 'Optimal_N_t')
                    Nt_all(end+1,:) = S.Optimal_N_t(:).'; %#ok<AGROW>
                else
                    Nt_all(end+1,:) = ones(1,n); %#ok<AGROW>
                end
                sisoRow = NaN(1,n);
                if isfield(S,'antennaConfigsUsed')
                    for ci = 1:numel(S.antennaConfigsUsed)
                        cfg_ = S.antennaConfigsUsed{ci};
                        ntLabels(cfg_.N_t) = sprintf('%dx%d', cfg_.N_t, cfg_.N_r);
                    end
                end
                if isfield(S,'antennaConfigsUsed') && isfield(S,'E_per_bit_all') && ~isempty(S.E_per_bit_all)
                    sisoIdx = find(cellfun(@(c) c.N_t==1 && c.N_r==1, S.antennaConfigsUsed), 1, 'first');
                    if ~isempty(sisoIdx)
                        sisoRow = S.E_per_bit_all(:,sisoIdx).';
                    end
                end
                E_bit_siso(end+1,:) = sisoRow; %#ok<AGROW>
            else
                E_bit_all(end+1,:) = NaN(1,n); %#ok<AGROW>
                Nt_all(end+1,:) = NaN(1,n); %#ok<AGROW>
                E_bit_siso(end+1,:) = NaN(1,n); %#ok<AGROW>
            end
        end
    end

    % --- MIMO+SISO winner (existing behavior) ---
    E_bit_smoothed = gearboxphy.report.interpolateNaN(E_bit_all);
    lowest = min(E_bit_smoothed, [], 1);
    opt_vec = NaN(1,n);
    nt_at_winner = NaN(1,n);
    for r = 1:n
        idx = find(E_bit_smoothed(:,r)==lowest(r), 1, 'first');
        if ~isempty(idx)
            opt_vec(r) = idx;
            nt_at_winner(r) = Nt_all(idx, r);   % raw (non-interpolated) - NaN if this exact point was itself interpolated
        end
    end

    % --- SISO-only winner (what if MIMO didn't exist) ---
    E_bit_siso_smoothed = gearboxphy.report.interpolateNaN(E_bit_siso);
    lowest_siso = min(E_bit_siso_smoothed, [], 1);
    opt_vec_siso = NaN(1,n);
    for r = 1:n
        idx = find(E_bit_siso_smoothed(:,r)==lowest_siso(r), 1, 'first');
        if ~isempty(idx)
            opt_vec_siso(r) = idx;
        end
    end

    plot(ax, scenario.RVec, opt_vec, 'Color', col, 'LineStyle', '-', ...
        'DisplayName', sprintf('f_c=%g GHz', f_c/1e9));
    plot(ax, scenario.RVec, opt_vec_siso, 'Color', col, 'LineStyle', '--', ...
        'HandleVisibility', 'off');

    % Thin the markers. At full sweep resolution one marker per rate
    % point merges into a solid band that hides the line itself - worst
    % in the low-R_eff region, where the winning config stays N_t=1 for
    % hundreds of consecutive points and every one of them got its own
    % marker. Decimating EVENLY over the whole axis would still spend the
    % same marker density on that constant stretch as on the interesting
    % one, so instead each RUN of equal N_t is decimated separately to at
    % most maxMarkersPerRun: a long constant run (low R_eff) collapses to
    % a few markers, while the short runs where the config actually
    % changes keep theirs. Every run keeps at least its first point, so no
    % antenna-config change can be hidden by the decimation.
    markMask = false(1, n);
    runStart = find([true, nt_at_winner(2:end) ~= nt_at_winner(1:end-1)]);
    runEnd   = [runStart(2:end)-1, n];
    for rr = 1:numel(runStart)
        a = runStart(rr); b = runEnd(rr);
        if isnan(nt_at_winner(a)), continue; end
        k = min(maxMarkersPerRun, b-a+1);
        if k <= 1
            markMask(a) = true;              % linspace(a,b,1) would give b, not a
        else
            markMask(unique(round(linspace(a, b, k)))) = true;
        end
    end

    for ntVal = cell2mat(markerByNt.keys)
        mask = (nt_at_winner == ntVal) & markMask;
        if any(mask)
            plot(ax, scenario.RVec(mask), opt_vec(mask), markerByNt(ntVal), ...
                'Color', col, 'MarkerFaceColor', col, 'MarkerSize', 6, ...
                'LineStyle', 'none', 'HandleVisibility', 'off');
        end
        if any(nt_at_winner == ntVal)
            ntValuesUsed = union(ntValuesUsed, ntVal);
        end
    end
end

yticks(ax, 1:numel(legendNames))
yticklabels(ax, legendNames)
title(ax, 'Optimal Gear'); xlabel(ax, 'R [bit/s]');

% Manual legend entries for the two encodings that aren't already
% carried by a real, named line: line style (MIMO+SISO vs. SISO-only)
% and marker shape (winning antenna count) - both in neutral gray so
% they read as "what this style/shape means", not as another carrier.
plot(ax, NaN, NaN, '-', 'Color', [0.3 0.3 0.3], 'DisplayName', 'MIMO+SISO');
plot(ax, NaN, NaN, '--', 'Color', [0.3 0.3 0.3], 'DisplayName', 'SISO only');
for ntVal = sort(ntValuesUsed)
    plot(ax, NaN, NaN, markerByNt(ntVal), 'Color', [0.3 0.3 0.3], 'MarkerFaceColor', [0.3 0.3 0.3], ...
        'MarkerSize', 6, 'LineStyle', 'none', 'DisplayName', ntLegendLabel(ntLabels, ntVal));
end
legend(ax, 'Location', 'eastoutside')
end

function lbl = ntLegendLabel(ntLabels, ntVal)
%NTLEGENDLABEL "N_txN_r" for this N_t, from the configs actually stored in the
%   results; falls back to the square assumption only if the results predate
%   antennaConfigsUsed (in which case N_r genuinely isn't recorded anywhere).
if isKey(ntLabels, ntVal)
    lbl = ntLabels(ntVal);
else
    lbl = sprintf('%dx%d', ntVal, ntVal);
end
end
