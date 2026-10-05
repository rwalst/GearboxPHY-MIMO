function analyze_siso_vs_mimo_gf(opts)
%ANALYZE_SISO_VS_MIMO_GF  Die drei Abbildungen der GF-Folien 34, 36 und 37,
%   neu gerechnet mit dem aktuellen Stand.
%
%   analyze_siso_vs_mimo_gf()
%   analyze_siso_vs_mimo_gf(outDir="/workspace/Groupmeetings/sisomimo_deck")
%
%   WAS SICH GEGENUEBER DEN ALTEN FOLIEN GEAENDERT HAT -- jede dieser
%   Aenderungen verschiebt Zahlen, nicht nur Beschriftungen:
%
%     ADC-Regel   b = 1/2*log2(M) + log2(N) + 3  (scaledB) statt
%                 b = 1/2*log2(M). Die alte Folie 34 schrieb B = 2/4/6
%                 fuer M = 4/16/64; dieselben Konfigurationen tragen jetzt
%                 je nach N bis zu 11 Bit.
%     Antennen    N bis 16 statt bis 8.
%     Konstellat. M bis 256 statt bis 64.
%     Achse       drei DISTANZEN bei 28 GHz statt drei Traegerfrequenzen.
%                 Die alten Folien kodierten f_c ueber die Farbe; die
%                 Distanz ist fuer diese Studie die interessante Achse,
%                 weil sie entscheidet, ob die PA oder die Ketten das
%                 Budget dominieren.
%
%   ABBILDUNG 1 (war Folie 34): ergodische MI ueber SNR, ein Panel je N,
%   eine Kurve je M, mit der tatsaechlich verwendeten Bitzahl annotiert.
%   Die Tier-Tabelle der alten Folie steht jetzt IN der Abbildung, weil
%   sie sich mit der Regel verschoben hat.
%
%   ABBILDUNG 2 (war Folie 36): welcher Gang gewinnt, Farbe = N. Enthaelt
%   die SISO-only-Referenz als gestrichelte Linie, wie die alte Folie.
%
%   ABBILDUNG 3 (war Folie 37): Einsparung gegenueber NA-QAM, einmal mit
%   und einmal ohne MIMO -- dieselbe Definition wie plotSavingsReport.m
%   (Verhaeltnis zum Basisgang), nur nach Distanz statt nach Traeger
%   aufgeteilt.
arguments
    opts.distances (1,:) double = [50 500 5000]
    opts.Ns (1,:) double = [1 2 4 8 16]
    opts.Ms (1,:) double = [4 16 64 256]
    opts.fcGHz (1,1) double = 28
    opts.prefix (1,1) string = "cmp_sisomimo_scaledB"
    opts.srcDir (1,1) string = "/workspace/QuantizedMimoMI/qam/results/rule_mux"
    opts.outDir (1,1) string = "/workspace/Groupmeetings/sisomimo_deck"
end
INK  = [0.043 0.043 0.043];
INK2 = [0.322 0.318 0.306];
if ~isfolder(opts.outDir), mkdir(opts.outDir); end

%% ================= 1) ergodische MI, scaledB (war Folie 34) ===========
Nplot = opts.Ns(opts.Ns > 1);                 % N = 1 ist die SISO-Referenz
fig = figure('Position', [100 100 390*numel(Nplot)+120 520], 'Color', 'w');
tl  = tiledlayout(fig, 1, numel(Nplot), 'TileSpacing', 'compact', 'Padding', 'compact');
C   = lines(numel(opts.Ms));
tierTab = strings(numel(opts.Ns), numel(opts.Ms));
for ni = 1:numel(opts.Ns)
    for mi = 1:numel(opts.Ms)
        [~, ~, tierTab(ni,mi)] = localLoadMi(opts.srcDir, opts.Ns(ni), opts.Ms(mi));
    end
end
for k = 1:numel(Nplot)
    N = Nplot(k);
    ax = nexttile(tl, k); hold(ax,'on'); grid(ax,'on'); box(ax,'off');
    set(ax, 'FontSize', 11, 'XColor', INK2, 'YColor', INK2, 'GridAlpha', 0.12);
    h = gobjects(0); lbl = {};
    for mi = 1:numel(opts.Ms)
        M = opts.Ms(mi);
        [snr, mi_v, tier, B] = localLoadMi(opts.srcDir, N, M);
        if isempty(snr), continue; end
        sty = '-';
        if tier == "mldExact", sty = '--'; elseif tier == "bounds", sty = ':'; end
        h(end+1) = plot(ax, snr, mi_v, sty, 'Color', C(mi,:), 'LineWidth', 2); %#ok<AGROW>
        lbl{end+1} = sprintf('M=%d (B=%d)', M, B); %#ok<AGROW>
        yline(ax, N*log2(M), '-', 'Color', [C(mi,:) 0.35], 'LineWidth', 1);
    end
    title(ax, sprintf('%dx%d MIMO', N, N), 'FontSize', 13, 'Color', INK);
    xlabel(ax, 'SNR per stream [dB]', 'FontSize', 11.5, 'Color', INK2);
    if k == 1
        ylabel(ax, 'MI [bit/channel use]', 'FontSize', 11.5, 'Color', INK2);
    end
    legend(ax, h, lbl, 'Location', 'northwest', 'Box', 'off', 'FontSize', 9, 'TextColor', INK2);
end
% KEIN \onehalf -- das kennt MATLABs TeX-Interpreter nicht und rendert
% als "ønehalf". 1/2 ausschreiben.
title(tl, ['Ergodic MI with the scaledB ADC rule, b = 1/2 log_2M + log_2N + 3' ...
    '   (solid: exact, dashed: MLD-MC, dotted: lower bound)'], ...
    'FontSize', 13, 'Color', INK, 'FontWeight', 'bold');
subtitle(tl, 'i.i.d. Rayleigh, perfect CSI at the receiver, no spatial correlation, 400 channel realisations', ...
    'FontSize', 11, 'Color', INK2);
exportgraphics(fig, fullfile(opts.outDir, 'gf_mi_scaledB.png'), 'Resolution', 200);
close(fig);

fprintf('\n==== Tier je (N, M), scaledB ====\n%-6s', 'N\M');
fprintf('%-12d', opts.Ms); fprintf('\n');
for ni = 1:numel(opts.Ns)
    fprintf('%-6d', opts.Ns(ni));
    for mi = 1:numel(opts.Ms), fprintf('%-12s', tierTab(ni,mi)); end
    fprintf('\n');
end

%% ====== 1b) E_bit je Antennenkonfiguration, festes M (war Folie 35) ===
% Die alte Folie zeigte QAM M = 16 ueber drei TRAEGER. Hier dieselbe
% Groesse ueber drei DISTANZEN und mit N bis 16 -- bewusst bei festem M,
% damit sie sich 1:1 gegen die alte Folie halten laesst. Die Fassung
% "bestes M" steht in analyze_siso_vs_mimo.m.
Mfix = 16;
nD0 = numel(opts.distances);
figE = figure('Position', [100 100 400*nD0+120 500], 'Color', 'w');
tlE  = tiledlayout(figE, 1, nD0, 'TileSpacing','compact','Padding','compact');
CN0 = lines(numel(opts.Ns));
axEl = gobjects(1, nD0);
for di = 1:nD0
    rd = gearboxphy.paths.resultsDir(sprintf('%s_d%g', opts.prefix, opts.distances(di)));
    f = fullfile(rd, sprintf('qam_M%d_fc%gGHz.mat', Mfix, opts.fcGHz));
    if ~isfile(f), continue; end
    S = load(f);
    ax = nexttile(tlE, di); hold(ax,'on'); grid(ax,'on'); box(ax,'off');
    set(ax,'XScale','log','YScale','log','FontSize',11,'XColor',INK2,'YColor',INK2,'GridAlpha',0.12);
    h = gobjects(0); lbl = {};
    for ci = 1:numel(S.antennaConfigsUsed)
        cfg = S.antennaConfigsUsed{ci};
        k = find(opts.Ns == cfg.N_t, 1);
        if isempty(k), continue; end
        v = S.E_per_bit_all(:,ci).';
        if ~any(isfinite(v)), continue; end
        h(end+1) = plot(ax, S.RVec, v, '-', 'Color', CN0(k,:), 'LineWidth', 2); %#ok<AGROW>
        lbl{end+1} = sprintf('%dx%d', cfg.N_t, cfg.N_r); %#ok<AGROW>
    end
    xlabel(ax, 'R_{eff} [bit/s]', 'FontSize', 11.5, 'Color', INK2);
    title(ax, sprintf('d = %g m', opts.distances(di)), 'FontSize', 13, 'Color', INK);
    if di == 1
        ylabel(ax, 'E_{bit} [J/bit]', 'FontSize', 11.5, 'Color', INK2);
        legend(ax, h, lbl, 'Location','southwest','Box','off','FontSize',9.5,'TextColor',INK2);
    end
    axEl(di) = ax;
end
okE = isgraphics(axEl);
if any(okE), linkaxes(axEl(okE), 'xy'); end
title(tlE, sprintf('Energy per bit per antenna configuration, QAM M = %d   (f_c = %g GHz, scaledB)', ...
    Mfix, opts.fcGHz), 'FontSize', 13, 'Color', INK, 'FontWeight','bold');
exportgraphics(figE, fullfile(opts.outDir, 'gf_ebit_M16.png'), 'Resolution', 200);
close(figE);

%% ================= 2+3) Gangwahl und Einsparung =======================
nD = numel(opts.distances);
figG = figure('Position', [100 100 400*nD+120 540], 'Color', 'w');
tlG  = tiledlayout(figG, 1, nD, 'TileSpacing','compact','Padding','compact');
figS = figure('Position', [100 100 400*nD+120 500], 'Color', 'w');
tlS  = tiledlayout(figS, 1, nD, 'TileSpacing','compact','Padding','compact');
CN = lines(numel(opts.Ns));
MK = {'o','s','^','d','v'};

% Gemeinsame Achsen: bei d = 5000 m ist der NA-QAM-Basisgang nur ueber ein
% schmales Ratenband ueberhaupt zulaessig, also auch das VERHAELTNIS. Mit
% Autoskalierung bekaeme dieses Panel einen voellig anderen x-Bereich als
% die beiden anderen, und die Zeile traegt dann keinen Vergleich mehr.
axSlist = gobjects(1, nD);
for di = 1:nD
    rd = gearboxphy.paths.resultsDir(sprintf('%s_d%g', opts.prefix, opts.distances(di)));
    G = localLoadGears(rd, opts.fcGHz);
    if isempty(G), continue; end

    % --- Gangwahl ---
    axG = nexttile(tlG, di); hold(axG,'on'); grid(axG,'on'); box(axG,'off');
    set(axG,'XScale','log','FontSize',11,'XColor',INK2,'YColor',INK2,'GridAlpha',0.12);
    [~, win] = min(G.E, [], 1, 'omitnan');
    win(all(isnan(G.E),1)) = NaN;
    for ni = 1:numel(opts.Ns)
        m = isfinite(win) & (G.Nt(sub2ind(size(G.Nt), max(win,1), 1:numel(win))) == opts.Ns(ni));
        m = m & isfinite(win);
        if any(m)
            plot(axG, G.R(m), win(m), MK{ni}, 'Color', CN(ni,:), ...
                'MarkerFaceColor', CN(ni,:), 'MarkerSize', 5, 'LineStyle','none');
        end
    end
    stairs(axG, G.R, win, '-', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.2);
    [~, winS] = min(G.Esiso, [], 1, 'omitnan');
    winS(all(isnan(G.Esiso),1)) = NaN;
    stairs(axG, G.R, winS, '--', 'Color', [0.25 0.25 0.25], 'LineWidth', 1.2);
    % 'tex', nicht 'none': sonst steht "ZXM M_{Tx}=3" woertlich da.
    set(axG, 'YTick', 1:numel(G.names), 'YTickLabel', G.labels, 'TickLabelInterpreter','tex');
    ylim(axG, [0.5 numel(G.names)+0.5]);
    xlabel(axG, 'R_{eff} [bit/s]', 'FontSize', 11.5, 'Color', INK2);
    title(axG, sprintf('d = %g m', opts.distances(di)), 'FontSize', 13, 'Color', INK);
    if di == nD
        lg = gobjects(0); ll = {};
        for ni = 1:numel(opts.Ns)
            lg(end+1) = plot(axG, NaN, NaN, MK{ni}, 'Color', CN(ni,:), ...
                'MarkerFaceColor', CN(ni,:), 'LineStyle','none'); %#ok<AGROW>
            ll{end+1} = sprintf('%dx%d', opts.Ns(ni), opts.Ns(ni)); %#ok<AGROW>
        end
        lg(end+1) = plot(axG, NaN, NaN, '--', 'Color', [0.25 0.25 0.25]);
        ll{end+1} = 'SISO only';
        legend(axG, lg, ll, 'Location','southeast','Box','off','FontSize',9,'TextColor',INK2);
    end

    % --- Einsparung gegen NA-QAM ---
    axS = nexttile(tlS, di); hold(axS,'on'); grid(axS,'on'); box(axS,'off');
    set(axS,'XScale','log','YScale','log','FontSize',11,'XColor',INK2,'YColor',INK2,'GridAlpha',0.12);
    best  = min(G.E, [], 1, 'omitnan');
    bestS = min(G.Esiso, [], 1, 'omitnan');
    sav   = best  ./ G.base;
    savS  = bestS ./ G.base;
    plot(axS, G.R, sav,  '-',  'Color', [0.835 0 0], 'LineWidth', 2);
    plot(axS, G.R, savS, '--', 'Color', [0.25 0.25 0.25], 'LineWidth', 1.6);
    yline(axS, 1, ':', 'Color', INK2, 'LineWidth', 1.2);
    xlabel(axS, 'R_{eff} [bit/s]', 'FontSize', 11.5, 'Color', INK2);
    title(axS, sprintf('d = %g m', opts.distances(di)), 'FontSize', 13, 'Color', INK);
    if di == 1
        ylabel(axS, 'E_{bit,Gearbox} / E_{bit,NA-QAM}', 'FontSize', 11.5, 'Color', INK2);
        legend(axS, {'Gearbox with MIMO','Gearbox, SISO only'}, 'Location','southwest', ...
            'Box','off','FontSize',9.5,'TextColor',INK2);
    end
    axSlist(di) = axS;
    fprintf(['d = %-6g  beste Einsparung mit MIMO %.3g, ohne %.3g  (Faktor %.1f)\n'], ...
        opts.distances(di), min(sav), min(savS), min(savS)/max(min(sav),eps));
end
ok = isgraphics(axSlist);
if any(ok)
    linkaxes(axSlist(ok), 'xy');
    xlim(axSlist(find(ok,1)), [1e3 1e11]);
    ylim(axSlist(find(ok,1)), [1e-3 2]);
end
title(tlG, sprintf('Selected gear, colour = antenna count   (f_c = %g GHz, scaledB)', opts.fcGHz), ...
    'FontSize', 13, 'Color', INK, 'FontWeight','bold');
title(tlS, sprintf('Energy saving over the NA-QAM baseline   (f_c = %g GHz, scaledB)', opts.fcGHz), ...
    'FontSize', 13, 'Color', INK, 'FontWeight','bold');
exportgraphics(figG, fullfile(opts.outDir, 'gf_selected_gear.png'), 'Resolution', 200);
exportgraphics(figS, fullfile(opts.outDir, 'gf_savings.png'), 'Resolution', 200);
close(figG); close(figS);
fprintf('\ngf_mi_scaledB.png, gf_ebit_M16.png, gf_selected_gear.png, gf_savings.png -> %s\n', opts.outDir);
end

% =======================================================================
function [snr, mi, tier, B] = localLoadMi(srcDir, N, M)
%LOCALLOADMI  scaledB-Kurve einer (N,M)-Kombination, mit ihrem Tier.
B = round(0.5*log2(M) + log2(N) + 3);
f = fullfile(srcDir, sprintf('mi_Nt%d_Nr%d_M%d_B%d.mat', N, N, M, B));
snr = []; mi = []; tier = "fehlt";
if ~isfile(f), return; end
r = load(f); r = r.results;
snr = r.snrDbList(:).'; mi = r.lower(:).';
m = r.methodPerSnr;
if iscell(m), tier = string(m{end}); else, tier = string(m); end
end

function G = localLoadGears(rd, fcGHz)
%LOCALLOADGEARS  E_bit je Gang (ohne Basisgang), plus die SISO-Spalte und
%   den NA-QAM-Basisgang. Die Reihenfolge der Gaenge ist die der alten
%   Folie: von energieaermstem zu spektraleffizientestem.
G = [];
spec = {'pulseenergy_M1','Pulse-Energy'; 'pulsearbitrary_M1','Pulse-Arbitrary'; ...
        'zxm_M1','ZXM M_{Tx}=1'; 'zxm_M2','ZXM M_{Tx}=2'; 'zxm_M3','ZXM M_{Tx}=3'; ...
        'qam_M4','QAM M=4'; 'qam_M16','QAM M=16'; 'qam_M64','QAM M=64'; ...
        'qam_M256','QAM M=256'; 'qam_M1024','QAM M=1024'};
E = []; Es = []; Nt = []; names = {}; labels = {}; R = [];
for i = 1:size(spec,1)
    f = fullfile(rd, sprintf('%s_fc%gGHz.mat', spec{i,1}, fcGHz));
    if ~isfile(f), continue; end
    S = load(f);
    if isempty(R), R = S.RVec(:).'; end
    E(end+1,:)  = S.E_per_bit(:).'; %#ok<AGROW>
    Nt(end+1,:) = S.Optimal_N_t(:).'; %#ok<AGROW>
    sisoRow = NaN(1, numel(R));
    if isfield(S,'antennaConfigsUsed') && isfield(S,'E_per_bit_all')
        k = find(cellfun(@(c) c.N_t==1 && c.N_r==1, S.antennaConfigsUsed), 1);
        if ~isempty(k), sisoRow = S.E_per_bit_all(:,k).'; end
    end
    Es(end+1,:) = sisoRow; %#ok<AGROW>
    names{end+1} = spec{i,1}; labels{end+1} = spec{i,2}; %#ok<AGROW>
end
if isempty(E), return; end
bf = fullfile(rd, sprintf('naqam_M1024_fc%gGHz.mat', fcGHz));
assert(isfile(bf), 'gf:noBaseline', '%s fehlt - NA-QAM ist der Basisgang.', bf);
B = load(bf);
G = struct('R',R,'E',E,'Esiso',Es,'Nt',Nt,'names',{names},'labels',{labels}, ...
           'base',B.E_per_bit(:).');
end
