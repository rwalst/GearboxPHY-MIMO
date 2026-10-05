function out = analyze_siso_vs_mimo(opts)
%ANALYZE_SISO_VS_MIMO  SISO gegen MIMO bei scaledB, aufgeloest nach N.
%
%   out = analyze_siso_vs_mimo();
%   out = analyze_siso_vs_mimo(distances=[50 5000], Ns=[1 2 4]);
%
%   Liest results/cmp_sisomimo_scaledB_d<d>/ (run_siso_vs_mimo_scaledB)
%   und schreibt results/cmp_figures/cmp_sisomimo_scaledB.png.
%
%   DIE FRAGE: ab welcher Rate zahlen sich mehrere Ketten aus? SISO
%   (N = 1) braucht eine PA, einen DAC, einen Mischer, einen ADC; MIMO
%   braucht N davon und bekommt dafuer Arraygewinn und N Stroeme. Beides
%   steht im selben Energiemodell, der Umschlagpunkt ist also eine Zahl
%   und keine Einschaetzung.
%
%   WARUM NICHT DIE HUELLKURVE: E_per_bit je Datei ist das Minimum ueber
%   die Antennenkonfigurationen und beantwortet die Frage NICHT -- sie
%   verschweigt, wie teuer SISO dort war, wo MIMO gewinnt. Gelesen wird
%   deshalb E_per_bit_all (nR x nN), Spalte i gehoert zu
%   antennaConfigsUsed{i}. Die Spalte wird ueber N_t IDENTIFIZIERT, nicht
%   ueber ihre Position -- antennaConfigs laesst fehlende Kurven still
%   weg, dann verschieben sich die Spalten.
%
%   ZWEI GERICHTETE VERZERRUNGEN, die die Abbildung ausweist:
%     * exportToGearboxSEData nimmt results.lower. SISO ist exakt
%       (Luecke 0,00 %), N >= 4 bei M >= 64 sind Schranken mit 7-13 %
%       Slack nahe der Saettigung -- die Verzerrung laeuft GEGEN MIMO.
%       Jeder MIMO-Vorsprung ist damit eine untere Schranke, und die
%       N = 8/16-Kurven werden gestrichelt gezeichnet.
%     * Die SISO-Kurven enden bei 25 dB Gesamt-SNR, 16x16 bei 37 dB
%       (dieselbe Quellachse, um 10*log10(N) verschoben). Wo der Gearbox
%       NaN liefert, ist die Konfiguration nicht unmoeglich, sondern
%       ungerechnet. Die Tabelle weist "endlich bis" je N aus.
arguments
    opts.distances (1,:) double = [50 500 5000]
    opts.Ns (1,:) double = [1 2 4 8 16]
    opts.fcGHz (1,1) double = 28
    opts.Ms (1,:) double = [4 16 64 256]
    opts.prefix (1,1) string = "cmp_sisomimo_scaledB"
    opts.figDir (1,1) string = "cmp_figures"
end

INK  = [0.043 0.043 0.043];
INK2 = [0.322 0.318 0.306];
nD   = numel(opts.distances);
nN   = numel(opts.Ns);
C    = turbo(nN+1); C = C(1:nN, :);

figDir = gearboxphy.paths.resultsDir(opts.figDir);
if ~isfolder(figDir), mkdir(figDir); end

%% ---- Laden -----------------------------------------------------------
D = cell(1, nD);
for di = 1:nD
    rd = gearboxphy.paths.resultsDir(sprintf('%s_d%g', opts.prefix, opts.distances(di)));
    if ~isfolder(rd)
        warning('sisomimo:missing', '%s fehlt - uebersprungen.', rd);
        continue
    end
    D{di} = localLoad(rd, opts);
end
assert(any(~cellfun(@isempty, D)), 'sisomimo:noData', ...
    'Keine results/%s_d* gefunden - erst run_siso_vs_mimo_scaledB ausfuehren.', opts.prefix);

out.distances = opts.distances; out.Ns = opts.Ns; out.data = {D};

%% ---- Abbildung -------------------------------------------------------
fig = figure('Position', [100 100 400*nD+120 820], 'Color', 'w');
tl  = tiledlayout(fig, 3, nD, 'TileSpacing', 'compact', 'Padding', 'compact');

for di = 1:nD
    s = D{di};
    if isempty(s), continue; end

    % --- Zeile 1: E_bit je N ---
    ax = nexttile(tl, di); localStyle(ax, INK2); set(ax, 'YScale', 'log');
    localAwgnBand(ax, s);
    h = gobjects(0); lbl = {};
    for k = 1:nN
        % Schranken-Tier gestrichelt: N >= 4 traegt Slack (siehe Kopf)
        sty = '-'; if opts.Ns(k) >= 8, sty = '--'; end
        v = s.E(:,k);
        if ~any(isfinite(v)), continue; end
        h(end+1) = plot(ax, s.R, v, sty, 'Color', C(k,:), 'LineWidth', 2); %#ok<AGROW>
        lbl{end+1} = sprintf('%dx%d', opts.Ns(k), opts.Ns(k)); %#ok<AGROW>
    end
    title(ax, sprintf('d = %g m', opts.distances(di)), 'FontSize', 12.5, 'Color', INK);
    if di == 1
        ylabel(ax, 'E_{bit} [J/bit]', 'FontSize', 12, 'Color', INK2);
        legend(ax, h, lbl, 'Location', 'southwest', 'Box', 'off', ...
            'FontSize', 9.5, 'TextColor', INK2);
    end

    % --- Zeile 2: bestes MIMO gegen SISO, das ist die Aussage ---
    ax2 = nexttile(tl, nD + di); localStyle(ax2, INK2); set(ax2, 'YScale', 'log');
    localAwgnBand(ax2, s);
    plot(ax2, s.R, s.ratio, '-', 'Color', INK, 'LineWidth', 2);
    yline(ax2, 1, '--', 'Color', INK2, 'LineWidth', 1.2);
    if isfinite(s.cross)
        xline(ax2, s.cross, ':', 'Color', [0.835 0 0], 'LineWidth', 1.8, ...
            'Label', sprintf('%.2g bit/s', s.cross), 'LabelOrientation', 'horizontal', ...
            'FontSize', 9, 'Color', [0.835 0 0]);
    end
    if di == 1
        ylabel(ax2, 'E_{bit}: bestes MIMO / SISO', 'FontSize', 12, 'Color', INK2);
        text(ax2, s.R(3), 1.6, ' SISO guenstiger', 'FontSize', 9, 'Color', INK2);
        text(ax2, s.R(3), 0.55, ' MIMO guenstiger', 'FontSize', 9, 'Color', INK2);
    end

    % --- Zeile 3: welches N gewinnt -- die eigentliche Antwort ---
    ax3 = nexttile(tl, 2*nD + di); localStyle(ax3, INK2);
    localAwgnBand(ax3, s);
    stairs(ax3, s.R, s.Nbest, '-', 'Color', INK, 'LineWidth', 2);
    set(ax3, 'YScale', 'log', 'YTick', opts.Ns, 'YTickLabel', ...
        arrayfun(@(n) sprintf('%d', n), opts.Ns, 'UniformOutput', false));
    ylim(ax3, [0.8 max(opts.Ns)*1.3]);
    xlabel(ax3, 'R_{eff} [bit/s]', 'FontSize', 12, 'Color', INK2);
    if di == 1
        ylabel(ax3, 'optimales N', 'FontSize', 12, 'Color', INK2);
    end
end
title(tl, sprintf(['SISO gegen MIMO, scaledB, f_c = %g GHz, i.i.d. Rayleigh, ' ...
    'bestes M \\leq %d  (gestrichelt: Schranken-Tier)'], opts.fcGHz, max(opts.Ms)), ...
    'FontSize', 13, 'Color', INK, 'FontWeight', 'bold');
figName = sprintf('%s.png', opts.prefix);
exportgraphics(fig, fullfile(figDir, figName), 'Resolution', 200);

%% ---- Tabelle ---------------------------------------------------------
fprintf('\n==== SISO gegen MIMO, scaledB ====\n');
fprintf('%-8s %-11s %-11s %-11s %-10s %-6s\n', 'd [m]', 'R [bit/s]', ...
    'SISO', 'bestes MIMO', 'MIMO/SISO', 'N opt');
out.rows = [];
for di = 1:nD
    s = D{di};
    if isempty(s), continue; end
    for Rq = [1e5 1e6 1e8 1e9 1e10]
        [~, i] = min(abs(log10(s.R) - log10(Rq)));
        % Den TATSAECHLICHEN Rasterpunkt ausweisen, nicht den angefragten
        if abs(log10(s.R(i)/Rq)) > log10(1.25)
            continue   % kein Punkt in der Naehe -- lieber weglassen
        end
        if ~isfinite(s.siso(i)) && ~isfinite(s.mimo(i)), continue; end
        fprintf('%-8g %-11.3g %-11.3g %-11.3g %-10.3f %-6d\n', ...
            opts.distances(di), s.R(i), s.siso(i), s.mimo(i), s.ratio(i), s.Nbest(i));
        out.rows(end+1,:) = [opts.distances(di), s.R(i), s.siso(i), s.mimo(i), ...
            s.ratio(i), s.Nbest(i)]; %#ok<AGROW>
    end
end

fprintf('\n---- Umschlagpunkt und Abdeckung ----\n');
for di = 1:nD
    s = D{di};
    if isempty(s), continue; end
    fprintf('d = %-6g Umschlag bei R = %-10.3g bit/s', opts.distances(di), s.cross);
    if isfinite(s.awgnUpTo)
        warnStr = '';
        if isfinite(s.cross) && s.cross <= s.awgnUpTo
            warnStr = '  <<< Umschlag LIEGT IM AWGN-Band, nur QAM-intern gueltig';
        end
        fprintf('\n          AWGN-Gaenge schlagen bestes QAM bis R = %.3g bit/s%s\n', ...
            s.awgnUpTo, warnStr);
        fprintf('         ');
    end
    fprintf('   endlich bis:');
    for k = 1:nN
        v = s.R(isfinite(s.E(:,k)));
        if isempty(v), fprintf('  %dx%d: --', opts.Ns(k), opts.Ns(k));
        else, fprintf('  %dx%d: %.2g', opts.Ns(k), opts.Ns(k), max(v)); end
    end
    fprintf('\n');
end

save(fullfile(figDir, sprintf('%s_summary.mat', opts.prefix)), 'out');
fprintf('\n%s und %s_summary.mat in %s\n', figName, opts.prefix, figDir);
end

% =======================================================================
function s = localLoad(rd, opts)
%LOCALLOAD  E_bit je (Rate, N), bestes M -- plus SISO/MIMO-Vergleich.
nN = numel(opts.Ns);
first = true;
for M = opts.Ms
    f = fullfile(rd, sprintf('qam_M%d_fc%gGHz.mat', M, opts.fcGHz));
    if ~isfile(f), continue; end
    S = load(f);
    if first
        s.R = S.RVec(:).';
        s.E = inf(numel(s.R), nN);
        first = false;
    end
    assert(numel(S.RVec) == numel(s.R), 'sisomimo:grid', '%s: anderes Ratenraster', f);
    % Spalten ueber N_t identifizieren, NICHT ueber die Position
    cfgs = S.antennaConfigsUsed;
    for c = 1:numel(cfgs)
        % Cell-Array (so legt arrayfun(...,'UniformOutput',false) es ab)
        % oder Struct-Array -- beides kann aus dem .mat kommen.
        if iscell(cfgs), cc = cfgs{c}; else, cc = cfgs(c); end
        k = find(opts.Ns == cc.N_t, 1);
        if isempty(k), continue; end
        e = S.E_per_bit_all(:, c);
        better = e < s.E(:,k);
        s.E(better, k) = e(better);
    end
end
if first, s = []; return; end
s.E(~isfinite(s.E)) = NaN;

% --- AWGN-Framework-Gaenge: wo schlagen sie das beste QAM? ---
% ZXM, Pulse/IR, NA-QAM und QAM M >= 1024 sind Gasts Originalkurven: AWGN,
% kein Fading, nicht unser ADC-Modell. Sie gehoeren NICHT in den Vergleich
% (anderer Kanal), aber sie gewinnen ueber weite Ratenbaender -- und
% unterhalb davon ist die Auswertung keine Gearbox-Entscheidung mehr,
% sondern ein Gang, den der Gearbox verworfen haette. Deshalb wird das
% Band gemessen und in der Abbildung hinterlegt.
ff = dir(fullfile(rd, '*.mat'));
eAwgn = inf(1, numel(s.R));
s.awgnGears = {};
for k = 1:numel(ff)
    isOurs = false;
    for M = opts.Ms
        if strcmp(ff(k).name, sprintf('qam_M%d_fc%gGHz.mat', M, opts.fcGHz))
            isOurs = true; break
        end
    end
    if isOurs, continue; end
    T = load(fullfile(rd, ff(k).name));
    if ~isfield(T, 'E_per_bit') || numel(T.RVec) ~= numel(s.R), continue; end
    eAwgn = min(eAwgn, T.E_per_bit(:).');   % min(NaN,x) = x in MATLAB
    s.awgnGears{end+1} = ff(k).name;
end
eAwgn(~isfinite(eAwgn)) = NaN;
s.eAwgn = eAwgn;
bestQam = min(s.E, [], 2, 'omitnan').';
s.awgnBeats = s.eAwgn < bestQam;           % NaN-Vergleiche sind false
if any(s.awgnBeats)
    s.awgnUpTo = max(s.R(s.awgnBeats));
else
    s.awgnUpTo = NaN;
end

kS = find(opts.Ns == 1, 1);
assert(~isempty(kS), 'sisomimo:noSiso', 'N = 1 ist nicht in opts.Ns.');
s.siso = s.E(:, kS).';
mimoCols = setdiff(1:nN, kS);
s.mimo = min(s.E(:, mimoCols), [], 2, 'omitnan');
s.mimo = s.mimo.';
s.ratio = s.mimo ./ s.siso;

% optimales N ueber ALLE Konfigurationen, SISO eingeschlossen
[~, iAll] = min(s.E, [], 2, 'omitnan');
s.Nbest = opts.Ns(iAll);
s.Nbest(all(isnan(s.E), 2)) = NaN;

% Umschlagpunkt: ERSTE Rate, ab der MIMO dauerhaft guenstiger bleibt.
% Nicht die erste Ueberkreuzung -- die kann ein einzelner Ausreisser sein.
win = s.ratio < 1;
ok  = isfinite(s.ratio);
s.cross = NaN;
idx = find(ok);
for j = 1:numel(idx)
    rest = idx(j:end);
    if all(win(rest))
        s.cross = s.R(idx(j));
        break
    end
end
end

function localAwgnBand(ax, s)
%LOCALAWGNBAND  Ratenbereich hinterlegen, in dem ein AWGN-Framework-Gang
%   (ZXM, Pulse/IR, NA-QAM, QAM M>=1024) das beste QAM schlaegt. Dort ist
%   die QAM-Auswertung keine Gearbox-Entscheidung -- siehe localLoad.
if ~isfield(s, 'awgnUpTo') || ~isfinite(s.awgnUpTo), return; end
xr = xregion(ax, min(s.R), s.awgnUpTo);
set(xr, 'FaceColor', [0.55 0.55 0.58], 'FaceAlpha', 0.13, 'EdgeColor', 'none');
uistack(xr, 'bottom');
end

function localStyle(ax, INK2)
hold(ax, 'on'); grid(ax, 'on'); box(ax, 'off');
set(ax, 'XScale', 'log', 'FontSize', 11, 'XColor', INK2, 'YColor', INK2, 'GridAlpha', 0.12);
end
