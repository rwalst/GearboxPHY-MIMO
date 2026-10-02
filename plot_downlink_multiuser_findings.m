function figs = plot_downlink_multiuser_findings(opts)
%PLOT_DOWNLINK_MULTIUSER_FINDINGS  Drei Abbildungen zu der Frage, ob ein
%   Sender seine Rate besser an einen oder an n Nutzer ausliefert.
%
%   figs = plot_downlink_multiuser_findings(Name, Wert, ...)
%
%   Das Skript ist eigenstaendig: es ruft analyze_downlink_multiuser.m
%   selbst auf (ohne dessen eigene Abbildung) und braucht die .mat aus
%   run_downlink_multiuser_study.m NICHT. Systemmodell, Aufteilung in
%   E_tx/E_rx und die Bedeutung von txModel stehen in
%   analyze_downlink_multiuser.m.
%
%   Die drei Abbildungen beantworten der Reihe nach:
%     1 WARUM   Anteil der Empfangsseite an E_bit ueber der Rate. Solange
%               der Empfaenger dominiert, vervielfacht jedes zusaetzliche
%               Endgeraet genau den teuren Teil.
%     2 WIE VIEL  bestes Verhaeltnis E_A/E_B ueber n, je Traeger und fuer
%               beide Basisfaelle (1x1 und beste Antennenkonfiguration).
%               Ueber 1 lohnt das Aufteilen, darunter nicht.
%     3 WOHIN   Aufschluesselung nach Sende- und Empfangsseite bei einer
%               festen Gesamtrate. Die Sendeseite bleibt stehen, die
%               Empfangsseite waechst mit n - das ist der ganze Effekt.
%
%   BEISPIELE
%       plot_downlink_multiuser_findings();
%       plot_downlink_multiuser_findings(resultsDir="results_beamforming_d5000");
%       plot_downlink_multiuser_findings(atRate=1e9, fcGHzList=28);
arguments
    opts.resultsDir (1,1) string = "results_beamforming_d50"
    opts.fcGHzList (1,:) double = [8 28]
    opts.nList (1,:) double = [1 2 4 8 16 32]
    opts.baseGear (1,1) string = "QAM"
    opts.baseOrder (1,1) double = 256
    opts.userGear (1,:) string = "ZXM"
    opts.txModel (1,1) string {mustBeMember(opts.txModel,["shared","perUser"])} = "shared"
    opts.fcDetail (1,1) double = 28          % Traeger fuer Abbildung 3
    opts.atRate (1,1) double = NaN           % NaN: Optimum von Fall A
    opts.figDir (1,1) string = ""
    opts.save (1,1) logical = true
end

if opts.figDir == "", opts.figDir = fullfile(opts.resultsDir,'figures'); end
if opts.save && ~isfolder(opts.figDir), mkdir(opts.figDir); end

% ---- Rechnen: je Traeger einmal mit 1x1- und einmal mit bester Basis --
nFc = numel(opts.fcGHzList);
A = cell(nFc,1); Bst = cell(nFc,1);
for a = 1:nFc
    A{a}   = localRun(opts, opts.fcGHzList(a), "1x1");
    Bst{a} = localRun(opts, opts.fcGHzList(a), "best");
end

INK  = [0.043 0.043 0.043];
INK2 = [0.322 0.318 0.306];
C    = lines(7);                 % Matlab blau / rot / gelb / ...
dTag = localDist(opts.resultsDir);

% =====================================================================
% Abbildung 1  WARUM: Anteil der Empfangsseite
% =====================================================================
f1 = figure('Position',[100 100 260+420*nFc 560],'Color','w');
tl = tiledlayout(f1,1,nFc,'TileSpacing','compact','Padding','compact');
for a = 1:nFc
    o = A{a};
    ax = nexttile(tl); hold(ax,'on'); grid(ax,'on'); box(ax,'off');
    set(ax,'XScale','log','FontSize',13,'XColor',INK2,'YColor',INK2,'GridAlpha',0.12);
    shareA = 100*o.EArx ./ (o.EAtx + o.EArx);
    shareB = 100*o.EBrx(:,1) ./ (o.EBtx(:,1) + o.EBrx(:,1));   % n = 1
    yline(ax,50,'--','Color',[0.55 0.55 0.55],'LineWidth',1.4,'HandleVisibility','off');
    h = plot(ax,o.x,shareA,'-','Color',C(1,:),'LineWidth',2.4, ...
        'DisplayName',sprintf('%s M=%d, 1x1', opts.baseGear, opts.baseOrder));
    h(2) = plot(ax,o.x,shareB,'-','Color',C(2,:),'LineWidth',2.4, ...
        'DisplayName',sprintf('best %s link', strjoin(opts.userGear,'/')));
    ylim(ax,[0 100]);
    title(ax,sprintf('f_c = %g GHz',opts.fcGHzList(a)), ...
        'FontSize',15,'Color',INK,'FontWeight','bold');
    if a == 1
        ylabel(ax,'receiver share of E_{bit}  [%]','FontSize',14,'Color',INK2);
        legend(ax,h,'Location','southwest','Box','off','FontSize',12,'TextColor',INK2);
    end
end
xlabel(tl,'aggregate rate x [bit/s]','FontSize',14,'Color',INK2);
title(tl,sprintf(['Why splitting is expensive: above 50 %% the receiver ' ...
    'dominates  (d = %s)'], dTag),'FontSize',15,'Color',INK,'FontWeight','bold');
localSave(f1, opts, 'downlink_findings_1_receiver_share.png');

% =====================================================================
% Abbildung 2  WIE VIEL: bestes E_A/E_B ueber n
% =====================================================================
nN = numel(opts.nList);
M = nan(nN, 2*nFc); lab = strings(1,2*nFc); col = zeros(2*nFc,3);
for a = 1:nFc
    for k = 1:nN
        M(k, 2*a-1) = max(A{a}.gain(:,k),   [], 'omitnan');
        M(k, 2*a  ) = max(Bst{a}.gain(:,k), [], 'omitnan');
    end
    lab(2*a-1) = sprintf('%g GHz, base 1x1',  opts.fcGHzList(a));
    lab(2*a  ) = sprintf('%g GHz, base best', opts.fcGHzList(a));
    col(2*a-1,:) = C(a,:);
    col(2*a  ,:) = min(C(a,:) + 0.45, 1);            % hellere Variante
end
f2 = figure('Position',[100 100 1080 580],'Color','w');
ax = axes(f2); hold(ax,'on'); grid(ax,'on'); box(ax,'off');
% Logarithmische Achse: ueber die Entfernungen hinweg reichen die
% Verhaeltnisse von etwa 0.2 bis ueber 500. Linear waere bei 5 km der
% faire Basisfall (rund 2x) neben dem 1x1-Fall (rund 500x) unsichtbar.
% Auf der Log-Achse liegt die Break-even-Linie bei 1 zudem optisch in
% der Mitte, gewinnen und verlieren sind damit gleich gut ablesbar.
set(ax,'FontSize',13,'XColor',INK2,'YColor',INK2,'GridAlpha',0.12, ...
    'Layer','top','YScale','log');
b = bar(ax, categorical(opts.nList, opts.nList, string(opts.nList)), M);
for i = 1:numel(b)
    b(i).FaceColor = col(i,:); b(i).EdgeColor = 'none'; b(i).DisplayName = lab(i);
end
lo = min(M(isfinite(M) & M>0), [], 'all'); hi = max(M(isfinite(M)), [], 'all');
ylim(ax, [10^(floor(log10(lo))-0.05) 10^(ceil(log10(hi))+0.15)]);
yline(ax,1,'k--','LineWidth',1.8,'DisplayName','break-even');

% Zahlenwerte auf die Balken, sonst ist die Log-Achse schwer abzulesen
for i = 1:numel(b)
    v = M(:,i);
    txt = strings(size(v));
    txt(v >= 10)          = compose('%.0f', v(v >= 10));
    txt(v <  10 & v >= 0) = compose('%.2f', v(v < 10 & v >= 0));
    text(ax, b(i).XEndPoints, b(i).YEndPoints, txt, 'Rotation',90, ...
        'HorizontalAlignment','left','VerticalAlignment','middle', ...
        'FontSize',10,'Color',INK2);
end
xlabel(ax,'number of users n  (each at x/n)','FontSize',14,'Color',INK2);
ylabel(ax,'best E_A / E_B over all rates','FontSize',14,'Color',INK2);
title(ax,sprintf(['Does splitting the rate pay?  above 1 yes, below 1 no   ' ...
    '(d = %s, tx model "%s")'], dTag, opts.txModel), ...
    'FontSize',15,'Color',INK,'FontWeight','bold');
legend(ax,'Location','northeast','Box','off','FontSize',12,'TextColor',INK2);
localSave(f2, opts, 'downlink_findings_2_gain_vs_n.png');

% =====================================================================
% Abbildung 3  WOHIN: Aufschluesselung bei fester Gesamtrate
% =====================================================================
a = find(opts.fcGHzList == opts.fcDetail, 1);
assert(~isempty(a), 'fcDetail=%g liegt nicht in fcGHzList', opts.fcDetail);
o = A{a};
if isnan(opts.atRate)
    [~, ir] = min(o.EA);                    % guenstigster Punkt von Fall A
else
    [~, ir] = min(abs(log10(o.x) - log10(opts.atRate)));
end
xEval = o.x(ir);

stk = [o.EAtx(ir) o.EArx(ir); [o.EBtx(ir,:).' o.EBrx(ir,:).']];
cats = ["A: 1 user", "B: n=" + string(opts.nList)];
keep = all(isfinite(stk),2);
f3 = figure('Position',[100 100 1080 580],'Color','w');
ax = axes(f3); hold(ax,'on'); grid(ax,'on'); box(ax,'off');
set(ax,'FontSize',13,'XColor',INK2,'YColor',INK2,'GridAlpha',0.12,'Layer','top');
bb = bar(ax, categorical(cats(keep), cats(keep)), stk(keep,:), 'stacked');
bb(1).FaceColor = C(1,:); bb(1).EdgeColor = 'none'; bb(1).DisplayName = 'transmitter (PA, DAC, LO, Mix)';
bb(2).FaceColor = C(2,:); bb(2).EdgeColor = 'none'; bb(2).DisplayName = 'receivers (LNA, LO, Mix, ADC)';
tot = sum(stk(keep,:),2);
barLab = string(compose('%.2fx', o.EA(ir)./tot));   % compose liefert cellstr
barLab(1) = "reference";                 % Fall A ist der Bezug, nicht 1.00x
text(ax, 1:numel(tot), tot, barLab, ...
    'HorizontalAlignment','center','VerticalAlignment','bottom', ...
    'FontSize',12,'Color',INK,'FontWeight','bold');
ylim(ax,[0 1.18*max(tot)]);
ylabel(ax,'E_{bit} per aggregate bit [J/bit]','FontSize',14,'Color',INK2);
title(ax,sprintf('Transmitter stays flat, receivers scale with n  (x = %.3g bit/s, f_c = %g GHz, d = %s)', ...
    xEval, opts.fcDetail, dTag),'FontSize',15,'Color',INK,'FontWeight','bold');
subtitle(ax,sprintf(['baseline %s M=%d 1x1;  bar labels = E_A/E_B, ' ...
    'above 1 means splitting pays'], opts.baseGear, opts.baseOrder), ...
    'FontSize',12,'Color',INK2);
legend(ax,[bb(1) bb(2)],'Location','northwest','Box','off','FontSize',12,'TextColor',INK2);
localSave(f3, opts, 'downlink_findings_3_tx_rx_split.png');

figs = [f1 f2 f3];

if nargout == 0, clear figs; end
end

% =======================================================================
function o = localRun(opts, fc, baseAnt)
o = analyze_downlink_multiuser( ...
    resultsDir = opts.resultsDir, fcGHz = fc, nList = opts.nList, ...
    baseGear = opts.baseGear, baseOrder = opts.baseOrder, ...
    baseAntenna = baseAnt, userGear = opts.userGear, userAntenna = "best", ...
    txModel = opts.txModel, verbose = false, plot = false);
end

% -----------------------------------------------------------------------
function localSave(fig, opts, name)
if ~opts.save, return, end
p = fullfile(opts.figDir, name);
exportgraphics(fig, p, 'Resolution', 200);
fprintf('geschrieben: %s\n', p);
end

% -----------------------------------------------------------------------
function s = localDist(rd)
t = regexp(char(rd), 'd(\d+)', 'tokens', 'once');
if isempty(t), s = '?'; else, s = [t{1} ' m']; end
end
