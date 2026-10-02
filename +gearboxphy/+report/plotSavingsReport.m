function fig = plotSavingsReport(resultsDir, scenario, opts)
%PLOTSAVINGSREPORT The "best gear vs NA-QAM baseline" savings curve,
%   ported from Wrapper.m's "Savings" section. The baseline gear is
%   identified via gear.isBaseline (see +gears/isBaselineGear.m), not a
%   hardcoded name string (code review finding #6).
%
%   A combo with no result file yet renders as a NaN row; any other load
%   error propagates instead of being silently swallowed (code review
%   finding #2 - see plotEnergyReport.m for the full rationale).
%
%   Same three-channel encoding as plotOptimalGearReport.m, applied to
%   the savings ratio instead of the gear-index curve:
%     COLOR      -> carrier frequency f_c
%     LINE STYLE -> MIMO+SISO best-gear savings (solid) vs. SISO-only
%                   best-gear savings (dashed) - the latter uses the
%                   N_t=1,N_r=1 column of E_per_bit_all/antennaConfigsUsed
%                   instead of the (possibly MIMO) winner column, so it
%                   answers "how much would Gearbox-PHY still save over
%                   NA-QAM if MIMO were never available". NA-QAM itself
%                   has no MIMO variant (baseline, always SISO), so only
%                   the numerator changes between the two curves.
%     MARKER     -> winning antenna count on the MIMO+SISO curve only
%                   (o=1x1, s=2x2, ^=4x4, d=8x8) - omitted on the
%                   SISO-only curve since it's 1x1 there by construction.
%   A results file predating antennaConfigsUsed/E_per_bit_all simply
%   can't supply the SISO-only curve - left as NaN for that row rather
%   than guessed (same convention as plotOptimalGearReport.m).
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

markerByNt = containers.Map({1,2,4,8}, {'o','s','^','d'});
% N_t -> "N_txN_r" legend label, filled from the antennaConfigsUsed
% actually stored in the results (markerByNt is keyed on N_t alone, so a
% non-square config like 2x4 would be mislabelled if N_r were assumed
% equal to N_t instead of read back).
ntLabels = containers.Map('KeyType','double','ValueType','char');
maxMarkersPerRun = opts.maxMarkersPerRun;

gears = gearboxphy.gears.gearRegistry();
n = numel(scenario.RVec);

naGear = [];
for gi = 1:numel(gears)
    if gearboxphy.gears.isBaselineGear(gears{gi})
        naGear = gears{gi};
    end
end
assert(~isempty(naGear), 'gearboxphy:report:noBaselineGear', 'No baseline gear (isBaseline=true) found in registry');

fig = figure();
ax = axes(fig);
ax.XScale = 'log'; ax.YScale = 'log';   % set explicitly - see plotOptimalGearReport.m for why
hold(ax, 'on'); grid(ax, 'on');
colors = lines(numel(scenario.fcVec));
ntValuesUsed = [];

for fi = 1:numel(scenario.fcVec)
    f_c = scenario.fcVec(fi);
    col = colors(fi,:);

    E_bit_all = [];    % nRows x n: MIMO+SISO winner per row
    E_bit_siso = [];   % nRows x n: SISO-only (N_t=1,N_r=1) per row
    Nt_all = [];       % nRows x n: winning N_t per row, for markers

    for gi = 1:numel(gears)
        gear = gears{gi};
        if gearboxphy.gears.isBaselineGear(gear)
            continue
        end
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

    key = gearboxphy.data.resultKey(naGear.name, naGear.orders(1), f_c);
    S = gearboxphy.data.loadAllResults(resultsDir, key);   % baseline must exist - let it error if missing
    E_bit_naqam = S.E_per_bit(:).';

    % --- MIMO+SISO savings ---
    E_bit_smoothed = gearboxphy.report.interpolateNaN(E_bit_all);
    lowest = min(E_bit_smoothed, [], 1);
    nt_at_winner = NaN(1,n);
    for r = 1:n
        idx = find(E_bit_smoothed(:,r)==lowest(r), 1, 'first');
        if ~isempty(idx)
            nt_at_winner(r) = Nt_all(idx, r);   % raw (non-interpolated) - NaN if this exact point was itself interpolated
        end
    end
    savings = lowest ./ E_bit_naqam;

    % --- SISO-only savings ---
    lowest_siso = min(gearboxphy.report.interpolateNaN(E_bit_siso), [], 1);
    savings_siso = lowest_siso ./ E_bit_naqam;

    plot(ax, scenario.RVec, savings, 'Color', col, 'LineStyle', '-', 'LineWidth', 1, ...
        'DisplayName', sprintf('f_c=%g GHz', f_c/1e9));
    plot(ax, scenario.RVec, savings_siso, 'Color', col, 'LineStyle', '--', 'LineWidth', 1, ...
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
            plot(ax, scenario.RVec(mask), savings(mask), markerByNt(ntVal), ...
                'Color', col, 'MarkerFaceColor', col, 'MarkerSize', 6, ...
                'LineStyle', 'none', 'HandleVisibility', 'off');
        end
        % legend entry reflects every config that WON somewhere, even if
        % the decimation happened to drop all of its markers
        if any(nt_at_winner == ntVal)
            ntValuesUsed = union(ntValuesUsed, ntVal);
        end
    end
end

xlim(ax, [min(scenario.RVec),max(scenario.RVec)])
ylabel(ax, 'E_{bit,Gearbox}/E_{bit,singleGear}'); xlabel(ax, 'R_{eff} [bit/s]')
title(ax, 'Savings')

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
