% RUN_ZXM_VS_QAM_STUDY  Lohnt es sich, EINE QAM-Verbindung durch n
%   PARALLELE ZXM-Verbindungen zu ersetzen?
%
%   In MATLAB in diesen Ordner wechseln und
%
%       run_zxm_vs_qam_study
%
%   eintippen. Alles Einstellbare steht im KONFIGURATIONSBLOCK unten.
%
%   FRAGE: dieselbe Gesamtrate R wird entweder von EINER QAM-Verbindung
%   getragen oder von n parallelen ZXM-Verbindungen mit je R/n. Weil
%   E_bit bereits pro Bit normiert ist, hat die Kette die Energie je Bit
%   E_bit_ZXM(R/n) -- ohne zusaetzlichen Faktor n. Verglichen wird also
%   E_bit_QAM(R) gegen E_bit_ZXM(R/n).
%
%   ANNAHME, die im Ergebnis steckt: die n Verbindungen sind unabhaengige
%   Hardware ohne gegenseitige Stoerung. Das ist die fuer ZXM
%   OPTIMISTISCHE Lesart.
%
%   AUSGABE
%     * Tabelle je n: wo ist QAM teurer, um welchen Faktor, bei welcher Rate
%     * Abbildung 1: E_bit ueber R, Basis plus eine Kurve je n
%     * Abbildung 2: maximaler Vorteil ueber n -- zeigt, welches n am
%       meisten bringt und ab wann weiteres Aufteilen wieder schadet
%     * out_*.mat mit allen Zahlen zum Weiterrechnen

% ======================================================================
% KONFIGURATION
% ======================================================================
resultsDir  = 'results_beamforming_d50';  % welcher Sweep
fcGHz       = 28;                          % Traeger [GHz]
baseOrder   = 256;                         % QAM-Ordnung der Basis
baseAntenna = "1x1";                       % "1x1" = QAM ohne Beamforming
                                            % "best" = QAM darf auch Antennen
                                            %          nutzen (fairer Vergleich)
nShow       = [1 2 4 8 16 32];             % n-Werte fuer Tabelle + Abb. 1
nSweep      = 1:48;                        % feines n-Gitter fuer Abb. 2
% ======================================================================

figDir = fullfile(resultsDir,'figures');
if ~exist(figDir,'dir'), mkdir(figDir); end

% --- Tabelle + Abbildung 1 --------------------------------------------
out = analyze_zxm_vs_qam(resultsDir=resultsDir, fcGHz=fcGHz, ...
        nList=nShow, baseOrder=baseOrder, baseAntenna=baseAntenna, ...
        outFile=fullfile(figDir, sprintf('zxm_vs_qam%d_fc%gGHz_%s.png', ...
                                          baseOrder, fcGHz, baseAntenna)));

% --- feiner n-Sweep, nur Zahlen ---------------------------------------
sw = analyze_zxm_vs_qam(resultsDir=resultsDir, fcGHz=fcGHz, ...
        nList=nSweep, baseOrder=baseOrder, baseAntenna=baseAntenna, ...
        verbose=false, plot=false);

g = sw.maxGain; g(~sw.anyWin) = NaN;
[gBest, kBest] = max(g);
fprintf('\nBestes n: %d  ->  %.2fx guenstiger als %s, bei R = %.3g bit/s\n', ...
    nSweep(kBest), gBest, sw.baseTag, sw.RatMaxGain(kBest));
nWin = nSweep(sw.anyWin);
if isempty(nWin)
    fprintf('Fuer KEIN n im Gitter ist QAM teurer.\n');
else
    fprintf('QAM ist teuer fuer n = %d .. %d\n', min(nWin), max(nWin));
end

% --- Abbildung 2: Vorteil ueber n -------------------------------------
INK=[0.043 0.043 0.043]; INK2=[0.322 0.318 0.306];
fig = figure('Position',[100 100 1000 480],'Color','w');
tl = tiledlayout(1,2,'TileSpacing','compact','Padding','compact');

ax1 = nexttile; hold(ax1,'on'); grid(ax1,'on'); box(ax1,'off');
plot(ax1, nSweep, g, '-o', 'Color',[0 0.4470 0.7410], 'LineWidth',2, ...
     'MarkerSize',4,'MarkerFaceColor',[0 0.4470 0.7410],'MarkerEdgeColor','w');
if ~isnan(gBest)
    plot(ax1, nSweep(kBest), gBest, 'p', 'MarkerSize',14, ...
        'MarkerFaceColor',[0.8500 0.3250 0.0980],'MarkerEdgeColor','w');
    text(ax1, nSweep(kBest), gBest*1.06, sprintf('  n = %d', nSweep(kBest)), ...
        'FontSize',11,'FontWeight','bold','Color',INK);
end
yline(ax1, 1, '--', 'Color',[.5 .5 .5]);
set(ax1,'XScale','log','YScale','log','FontSize',11.5,'XColor',INK2,'YColor',INK2,'GridAlpha',0.12);
xlabel(ax1,'n (parallel ZXM links)','FontSize',12.5,'Color',INK2);
ylabel(ax1,'max E_{bit} advantage over baseline','FontSize',12.5,'Color',INK2);
title(ax1,'How much does splitting buy?','FontSize',13,'Color',INK,'FontWeight','bold');

ax2 = nexttile; hold(ax2,'on'); grid(ax2,'on'); box(ax2,'off');
lo = sw.Rlo; hi = sw.Rhi;
for k = 1:numel(nSweep)
    if sw.anyWin(k)
        plot(ax2, [lo(k) hi(k)], [nSweep(k) nSweep(k)], '-', ...
            'Color',[0 0.4470 0.7410 0.75], 'LineWidth',3);
    end
end
set(ax2,'XScale','log','YScale','log','FontSize',11.5,'XColor',INK2,'YColor',INK2,'GridAlpha',0.12);
xlabel(ax2,'aggregate rate R [bit/s]','FontSize',12.5,'Color',INK2);
ylabel(ax2,'n','FontSize',12.5,'Color',INK2);
title(ax2,'Where the QAM link is the more expensive option','FontSize',13,'Color',INK,'FontWeight','bold');
title(tl, sprintf('%s,  f_c = %g GHz,  %s', resultsDir, fcGHz, sw.baseTag), ...
      'FontSize',13.5,'Color',INK,'FontWeight','bold','Interpreter','none');

f2 = fullfile(figDir, sprintf('zxm_vs_qam%d_fc%gGHz_%s_nsweep.png', baseOrder, fcGHz, baseAntenna));
exportgraphics(fig, f2, 'Resolution', 200);
fprintf('geschrieben: %s\n', f2);

matFile = fullfile(resultsDir, sprintf('zxm_vs_qam%d_fc%gGHz_%s.mat', baseOrder, fcGHz, baseAntenna));
save(matFile, 'out', 'sw');
fprintf('Zahlen gespeichert: %s\n', matFile);
