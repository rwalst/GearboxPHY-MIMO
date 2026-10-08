function out = analyze_analog_bf()
%ANALYZE_ANALOG_BF  Auswertung der Analog-BF-Studie: analoges gegen
%   digitales Beamforming ueber die Distanz, je Rate und ADC-Modell.
%
%   Aufruf: in GearboxPHY-MIMO/ einfach
%       setupGearboxPath; analyze_analog_bf
%   Braucht results/abf_distance_<variante>_<adc>.mat aus
%   run_analog_bf_distance. Reine Auswertung, keine Optimierung; laeuft in
%   Sekunden und darf am Arbeitsplatz laufen.
%
%   Je Variante wird fuer jede Distanz und Rate das Minimum ueber (M, N)
%   gebildet. Alle Varianten von Fall 1 rechnen auf demselben (M, N)-Gitter
%   und mit derselben SE-Kurve; der Unterschied liegt allein in der
%   Hardware und im Linkbudget.
%
%   AUSGABE: results/abf_figures/abf_energy_<adc>.png, abf_arrays_<adc>.png,
%   abf_summary.csv; out als Struct fuer die Weiterverarbeitung.
%   UNGETESTET, solange keine Ergebnisdateien vorliegen.
resDir = gearboxphy.paths.resultsDir('');
f = dir(fullfile(resDir, 'abf_distance_*.mat'));
assert(~isempty(f), 'analyze_analog_bf:noResults', ...
    'Keine abf_distance_*.mat in %s - erst run_analog_bf_distance.', resDir);
figDir = gearboxphy.paths.resultsDir('abf_figures');
if ~isfolder(figDir), mkdir(figDir); end

S = struct('variant', {}, 'adc', {}, 'CFG', {}, 'Ebest', {}, 'Nbest', {}, 'Mbest', {}, 'psShare', {}, 'adcShare', {});
for i = 1:numel(f)
    T = load(fullfile(f(i).folder, f(i).name));
    [nD, nR, ~, ~] = size(T.E);
    Eb = nan(nD, nR); Nb = Eb; Mb = Eb; psS = Eb; adS = Eb;
    for di = 1:nD
        for ri = 1:nR
            e = squeeze(T.E(di, ri, :, :));                 % nM x nN
            [m, idx] = min(e(:));
            if isnan(m), continue; end
            [mi, ni] = ind2sub(size(e), idx);
            Eb(di, ri) = m; Nb(di, ri) = T.CFG.Ns(ni); Mb(di, ri) = T.CFG.Ms(mi);
            psS(di, ri) = T.Eps(di, ri, mi, ni) / m;
            adS(di, ri) = T.Eadc(di, ri, mi, ni) / m;
        end
    end
    S(end+1) = struct('variant', string(T.variant), 'adc', string(T.adcModel), 'CFG', T.CFG, ...
        'Ebest', Eb, 'Nbest', Nb, 'Mbest', Mb, 'psShare', psS, 'adcShare', adS); %#ok<AGROW>
end
out.S = S;

LBL = containers.Map( ...
    {'dbf_ideal', 'dbf_ideal_lo4mW', 'dbf_ideal_lo12p5mW', 'dbf_ideal_lo17mW', 'abf_active', 'abf_passive_comp', 'abf_passive_pen', ...
     'abfray_active', 'abfray_passive_comp', 'abfray_passive_pen'}, ...
    {'digital, LOS, shared LO', 'digital, LOS, 4 mW LO per extra mixer', 'digital, LOS, 12.5 mW LO per extra mixer', ...
     'digital, LOS, 17 mW LO per extra mixer', 'analog, active PS', 'analog, passive + gain compensation', 'analog, passive, loss penalty only', ...
     'analog Rayleigh, active PS', 'analog Rayleigh, passive + compensation', 'analog Rayleigh, passive, penalty only'});
COL = containers.Map( ...
    {'dbf_ideal', 'dbf_ideal_lo4mW', 'dbf_ideal_lo12p5mW', 'dbf_ideal_lo17mW', 'abf_active', 'abf_passive_comp', 'abf_passive_pen', ...
     'abfray_active', 'abfray_passive_comp', 'abfray_passive_pen'}, ...
    {[0.04 0.04 0.04], [0.30 0.30 0.30], [0.48 0.48 0.48], [0.66 0.66 0.66], [0.16 0.47 0.84], [0.92 0.41 0.20], [0.11 0.69 0.48], ...
     [0.16 0.47 0.84], [0.92 0.41 0.20], [0.11 0.69 0.48]});

rows = {};
for adc = unique([S.adc])
    sel = S([S.adc] == adc);
    CFG = sel(1).CFG; nR = numel(CFG.rates);
    ref = sel([sel.variant] == "dbf_ideal");

    % ---- Energie je Bit ueber die Distanz
    fig = figure('Visible', 'off', 'Position', [100 100 1100 420], 'Color', 'w');
    tl = tiledlayout(fig, 1, nR, 'TileSpacing', 'compact', 'Padding', 'compact');
    for ri = 1:nR
        ax = nexttile(tl); hold(ax, 'on');
        for k = 1:numel(sel)
            v = char(sel(k).variant);
            ls = '-'; if startsWith(v, 'abfray'), ls = '--'; end
            if startsWith(v, 'dbf_ideal_lo'), ls = ':'; end
            lw = 1.6; if startsWith(v, 'dbf_ideal'), lw = 2.2; end
            plot(ax, CFG.distances, sel(k).Ebest(:, ri), ls, 'Color', COL(v), 'LineWidth', lw, 'DisplayName', LBL(v));
        end
        set(ax, 'XScale', 'log', 'YScale', 'log'); grid(ax, 'on'); box(ax, 'off');
        xlabel(ax, 'distance [m]'); ylabel(ax, 'energy per bit [J]');
        title(ax, sprintf('R = %s bit/s', localEng(CFG.rates(ri))), 'FontWeight', 'normal');
        if ri == 1, legend(ax, 'Location', 'northwest', 'Box', 'off'); end
    end
    title(tl, sprintf('Analog vs. digital beamforming, QAM, %g GHz, ADC model "%s"', CFG.fcGHz, adc));
    exportgraphics(fig, fullfile(figDir, sprintf('abf_energy_%s.png', adc)), 'Resolution', 200);
    close(fig);

    % ---- gewaehlte Antennenzahl
    fig = figure('Visible', 'off', 'Position', [100 100 1100 420], 'Color', 'w');
    tl = tiledlayout(fig, 1, nR, 'TileSpacing', 'compact', 'Padding', 'compact');
    for ri = 1:nR
        ax = nexttile(tl); hold(ax, 'on');
        for k = 1:numel(sel)
            v = char(sel(k).variant);
            ls = '-'; if startsWith(v, 'abfray'), ls = '--'; end
            if startsWith(v, 'dbf_ideal_lo'), ls = ':'; end
            stairs(ax, CFG.distances, sel(k).Nbest(:, ri), ls, 'Color', COL(v), 'LineWidth', 1.6, 'DisplayName', LBL(v));
        end
        set(ax, 'XScale', 'log', 'YScale', 'log', 'YTick', CFG.Ns); grid(ax, 'on'); box(ax, 'off');
        ylim(ax, [0.8 max(CFG.Ns) * 1.25]);
        xlabel(ax, 'distance [m]'); ylabel(ax, 'antennas per side at the optimum');
        title(ax, sprintf('R = %s bit/s', localEng(CFG.rates(ri))), 'FontWeight', 'normal');
        if ri == 1, legend(ax, 'Location', 'northwest', 'Box', 'off'); end
    end
    title(tl, sprintf('Array size chosen, ADC model "%s"', adc));
    exportgraphics(fig, fullfile(figDir, sprintf('abf_arrays_%s.png', adc)), 'Resolution', 200);
    close(fig);

    % ---- Tabelle: Verhaeltnis zur digitalen Referenz
    fprintf('\n=== ADC-Modell %s: E_analog / E_digital (LOS-Referenz), gewaehltes N ===\n', adc);
    dIdx = unique(round(linspace(1, numel(CFG.distances), 5)));
    for ri = 1:nR
        fprintf('  R = %s bit/s\n', localEng(CFG.rates(ri)));
        fprintf('    %-38s', 'Variante');
        hdr = arrayfun(@(d) sprintf('%.0f m', d), CFG.distances(dIdx), 'UniformOutput', false);
        fprintf('%16s', hdr{:});
        fprintf('\n');
        for k = 1:numel(sel)
            v = char(sel(k).variant);
            fprintf('    %-38s', LBL(v));
            for di = dIdx
                ratio = NaN;
                if ~isempty(ref), ratio = sel(k).Ebest(di, ri) / ref.Ebest(di, ri); end
                fprintf('%8.2f (N=%2g)', ratio, sel(k).Nbest(di, ri));
                rows(end+1, :) = {char(adc), v, CFG.rates(ri), CFG.distances(di), sel(k).Ebest(di, ri), ratio, ...
                    sel(k).Nbest(di, ri), sel(k).Mbest(di, ri), sel(k).psShare(di, ri), sel(k).adcShare(di, ri)}; %#ok<AGROW>
            end
            fprintf('\n');
        end
    end
end
Tsum = cell2table(rows, 'VariableNames', {'adcModel', 'variant', 'rate_bps', 'distance_m', 'E_J_per_bit', ...
    'ratio_to_digital', 'N', 'M', 'psShare', 'adcShare'});
writetable(Tsum, fullfile(figDir, 'abf_summary.csv'));
out.summary = Tsum;
fprintf('\nAbbildungen und abf_summary.csv in %s\n', figDir);
end

function s = localEng(x)
e = floor(log10(x) / 3) * 3;
u = containers.Map({0, 3, 6, 9, 12}, {'', 'k', 'M', 'G', 'T'});
s = sprintf('%g %s', x / 10^e, u(e));
end
