function out = analyze_downlink_multiuser(opts)
%ANALYZE_DOWNLINK_MULTIUSER  Downlink: EIN Sender, 1 Nutzer mit Rate x
%   gegen n Nutzer mit je x/n.
%
%   out = analyze_downlink_multiuser(Name, Wert, ...)
%
%   SYSTEMMODELL
%   ------------
%   Beide Faelle liefern dieselbe Gesamtrate x an die Luftschnittstelle.
%
%     Fall A  1 Sender  ->  1 Empfaenger mit Rate x
%     Fall B  1 Sender  ->  n Empfaenger mit je Rate x/n
%
%   Deshalb wird die Energie je Komponente auf die Sende- und die
%   Empfangsseite aufgeteilt (PowerBudget_all aus dem Sweep):
%
%     E_tx = PA + DAC + LO_Tx + Mix_Tx        [J/bit]
%     E_rx = LNA + LO_Rx + Mix_Rx + ADC       [J/bit]
%
%   Als Metrik dient die Energie pro AGGREGIERTEM Bit, also bezogen auf
%   x, nicht auf die Rate des einzelnen Nutzers:
%
%     Fall A:  E_A(x)   = E_tx(x) + E_rx(x)          (= gespeichertes E_bit)
%     Fall B:  E_B(x,n) = E_tx(x_tx) + E_rx(x/n)
%
%   Der Term E_rx(x/n) traegt den n-fachen Aufwand bereits in sich: die
%   Gesamtempfangsleistung ist n*P_rx(x/n) = n*(x/n)*E_rx(x/n), geteilt
%   durch x bleibt genau E_rx(x/n). Feste Empfaengerterme (vor allem der
%   LO) erscheinen darin also n-fach pro aggregiertem Bit - das ist der
%   Preis dafuer, die Rate auf mehrere Geraete aufzuteilen.
%
%   txModel legt fest, was der eine Sender kostet:
%     "shared"  (Default) x_tx = x. Eine Sendekette traegt die volle
%               Gesamtrate, feste Sendeterme (LO_Tx) werden EINMAL
%               bezahlt. Das entspricht "ein Tx" im Wortsinn und passt
%               zu Zeit-/Frequenzmultiplex ueber die n Nutzer.
%     "perUser" x_tx = x/n. Der Sender betreibt n getrennte Ketten mit je
%               x/n, feste Sendeterme fallen n-fach an. Obergrenze der
%               Senderkosten; die Wahrheit liegt fuer SDMA dazwischen.
%               ACHTUNG: die Bandbreitenschranke B <= eta*f_c gilt im
%               Sweep PRO STRECKE. In "perUser" duerfen die n Ketten sie
%               deshalb jede fuer sich ausschoepfen, der Sender belegt
%               also bis zu n*eta*f_c Spektrum. Die grossen Gewinne, die
%               dieser Modus jenseits der Reichweite von Fall A zeigt,
%               sind zu einem guten Teil genau dieses Extra-Spektrum und
%               keine Effizienz. "shared" haelt die Schranke ein.
%
%   ANNAHMEN: die n Nutzerstrecken stoeren sich nicht (orthogonal in Zeit
%   oder Frequenz), alle n Nutzer verwenden dieselbe Konfiguration und
%   stehen in derselben Entfernung. Interferenz und Scheduling sind nicht
%   modelliert - die Lesart ist damit fuer Fall B optimistisch.
%
%   BEISPIELE
%       analyze_downlink_multiuser();
%       analyze_downlink_multiuser(fcGHz=8, nList=[1 2 4 8]);
%       analyze_downlink_multiuser(txModel="perUser");
%       analyze_downlink_multiuser(baseAntenna="best");   % fairer Basisfall
arguments
    opts.resultsDir (1,1) string = "results_beamforming_d50"
    opts.fcGHz (1,1) double = 28
    opts.nList (1,:) double = [1 2 4 8 16]
    opts.baseGear (1,1) string = "QAM"
    opts.baseOrder (1,1) double = 256
    opts.baseAntenna (1,1) string {mustBeMember(opts.baseAntenna,["1x1","best"])} = "1x1"
    opts.userGear (1,:) string = "ZXM"
    opts.userAntenna (1,1) string {mustBeMember(opts.userAntenna,["1x1","best"])} = "best"
    opts.txModel (1,1) string {mustBeMember(opts.txModel,["shared","perUser"])} = "shared"
    opts.verbose (1,1) logical = true
    opts.plot (1,1) logical = true
    opts.outFile (1,1) string = ""
end

cat = localCatalogue(opts.resultsDir, opts.fcGHz);
assert(~isempty(cat), 'keine Ergebnisdateien fuer %g GHz in %s', opts.fcGHz, opts.resultsDir);

% ---- Fall A: Basisstrecke -------------------------------------------
isBase = [cat.gear] == opts.baseGear & [cat.order] == opts.baseOrder;
if opts.baseAntenna == "1x1"
    isBase = isBase & [cat.N_t] == 1 & [cat.N_r] == 1;
end
assert(any(isBase), 'Basisfall %s M=%d (%s) nicht in %s gefunden', ...
    opts.baseGear, opts.baseOrder, opts.baseAntenna, opts.resultsDir);
base = cat(isBase);

x = base(1).R(:);                       % Gesamtrate, gemeinsames Raster
EA_cand = nan(numel(x), numel(base));
for i = 1:numel(base)
    EA_cand(:,i) = base(i).Etx + base(i).Erx;
end
[EA, iA] = min(EA_cand, [], 2, 'omitnan');
deadA = all(isnan(EA_cand),2);
EA(deadA) = NaN;
EAtx = nan(numel(x),1); EArx = nan(numel(x),1);
for r = 1:numel(x)
    if ~deadA(r)
        EAtx(r) = base(iA(r)).Etx(r);
        EArx(r) = base(iA(r)).Erx(r);
    end
end
baseTag = sprintf('%s M=%d, %s', opts.baseGear, opts.baseOrder, opts.baseAntenna);

% ---- Fall B: Kandidaten der n Nutzer --------------------------------
isUser = ismember([cat.gear], opts.userGear);
if opts.userAntenna == "1x1"
    isUser = isUser & [cat.N_t] == 1 & [cat.N_r] == 1;
end
assert(any(isUser), 'keine Kandidaten fuer userGear=%s in %s', ...
    strjoin(opts.userGear,','), opts.resultsDir);
usr = cat(isUser);

nN = numel(opts.nList);
EB = nan(numel(x), nN);
EBtx = nan(numel(x), nN);
EBrx = nan(numel(x), nN);
winner = strings(numel(x), nN);

for k = 1:nN
    n = opts.nList(k);
    if opts.txModel == "shared", xtx = x; else, xtx = x/n; end
    xrx = x/n;
    cand   = nan(numel(x), numel(usr));
    candTx = nan(numel(x), numel(usr));
    candRx = nan(numel(x), numel(usr));
    for i = 1:numel(usr)
        candTx(:,i) = localLogterp(usr(i).R, usr(i).Etx, xtx);
        candRx(:,i) = localLogterp(usr(i).R, usr(i).Erx, xrx);
        cand(:,i)   = candTx(:,i) + candRx(:,i);
    end
    [EB(:,k), ib] = min(cand, [], 2, 'omitnan');
    dead = all(isnan(cand), 2);
    EB(dead,k) = NaN;
    for r = 1:numel(x)
        if ~dead(r)
            EBtx(r,k) = candTx(r,ib(r));
            EBrx(r,k) = candRx(r,ib(r));
            winner(r,k) = usr(ib(r)).label;
        end
    end
end

% ---- Auswertung ------------------------------------------------------
gain = EA ./ EB;                        % > 1: Aufteilen auf n Nutzer gewinnt
out = struct('x',x,'EA',EA,'EAtx',EAtx,'EArx',EArx,'EB',EB,'EBtx',EBtx,'EBrx',EBrx,'gain',gain, ...
             'winner',{winner},'baseTag',baseTag,'n',opts.nList,'opts',opts, ...
             'baseWinner',{string({base(iA).label})'});
out.anyWin = false(1,nN); out.maxGain = nan(1,nN);
out.xLo = nan(1,nN); out.xHi = nan(1,nN); out.xAtMax = nan(1,nN); out.tagAtMax = strings(1,nN);
for k = 1:nN
    sel = isfinite(gain(:,k)) & gain(:,k) > 1;
    out.anyWin(k) = any(sel);
    if any(sel)
        idx = find(sel);
        [out.maxGain(k), im] = max(gain(idx,k));
        im = idx(im);
        out.xLo(k) = min(x(sel)); out.xHi(k) = max(x(sel));
        out.xAtMax(k) = x(im); out.tagAtMax(k) = winner(im,k);
    end
end

if opts.verbose, localReport(out); end
if opts.plot
    if opts.outFile == ""
        opts.outFile = fullfile(opts.resultsDir, 'figures', sprintf( ...
            'downlink_multiuser_%s_M%d_%s_fc%gGHz_%s.png', lower(opts.baseGear), ...
            opts.baseOrder, opts.baseAntenna, opts.fcGHz, opts.txModel));
        out.opts.outFile = opts.outFile;
    end
    localPlot(out);
end
end

% =======================================================================
function cat = localCatalogue(rd, fcGHz)
%LOCALCATALOGUE  Eine Zeile je (Gear, Ordnung, Antennenkonfiguration) mit
%   den nach Sende- und Empfangsseite getrennten Energien.
% Zuordnung der Budget-Felder zu Sende- und Empfangsseite. Nicht jedes
% Gear liefert jedes Feld: pulseGear.m kennt im Energiedetektor-Zweig
% weder LO_Rx noch Mix_Rx, dafuer EnergyDetector. Deshalb wird ueber die
% TATSAECHLICH vorhandenen Felder summiert und jedes unbekannte Feld
% loest einen Fehler aus - so kann eine spaeter hinzugefuegte Komponente
% nicht stillschweigend aus der Bilanz fallen.
TXF = {'PA','DAC','LO_Tx','Mix_Tx'};
RXF = {'LNA','LO_Rx','Mix_Rx','ADC','EnergyDetector'};
PRE = {'qam','QAM'; 'zxm','ZXM'; 'naqam','NA-QAM'; ...
       'pulseenergy','Pulse-Energy'; 'pulsearbitrary','Pulse-Arbitrary'};

files = dir(fullfile(rd, sprintf('*_fc%gGHz.mat', fcGHz)));
cat = struct('gear',{},'order',{},'N_t',{},'N_r',{},'R',{},'Etx',{},'Erx',{},'label',{});
for f = 1:numel(files)
    tok = regexp(files(f).name, '^([a-z]+)_M(\d+)_fc', 'tokens', 'once');
    if isempty(tok), continue, end
    j = find(strcmp(PRE(:,1), tok{1}), 1);
    if isempty(j), continue, end
    S = load(fullfile(rd, files(f).name));
    if ~isfield(S,'PowerBudget_all') || isempty(S.PowerBudget_all)
        warning('analyze:noBudget','%s hat kein PowerBudget_all - uebersprungen.', files(f).name);
        continue
    end
    [nR, nC] = size(S.PowerBudget_all);
    for c = 1:nC
        etx = nan(nR,1); erx = nan(nR,1);
        for r = 1:nR
            b = S.PowerBudget_all{r,c};
            if isstruct(b)
                fn = fieldnames(b);
                unknown = setdiff(fn, [TXF RXF]);
                assert(isempty(unknown), 'analyze:budgetField', ...
                    ['unbekanntes Budget-Feld %s in %s - es muss in ' ...
                     'analyze_downlink_multiuser.m der Sende- oder ' ...
                     'Empfangsseite zugeordnet werden.'], ...
                    strjoin(unknown,','), files(f).name);
                etx(r) = sum(cellfun(@(nm) b.(nm), intersect(fn, TXF, 'stable')));
                erx(r) = sum(cellfun(@(nm) b.(nm), intersect(fn, RXF, 'stable')));
            end
        end
        e.gear  = string(PRE{j,2});
        e.order = str2double(tok{2});
        e.N_t   = S.antennaConfigsUsed{c}.N_t;
        e.N_r   = S.antennaConfigsUsed{c}.N_r;
        e.R     = S.RVec(:);
        e.Etx   = etx; e.Erx = erx;
        if e.gear == "ZXM"
            e.label = sprintf('ZXM M_{Tx}=%d %dx%d', e.order, e.N_t, e.N_r);
        elseif ismember(e.gear, ["QAM","NA-QAM"])
            e.label = sprintf('%s M=%d %dx%d', e.gear, e.order, e.N_t, e.N_r);
        else
            e.label = sprintf('%s %dx%d', e.gear, e.N_t, e.N_r);
        end
        cat(end+1) = e; %#ok<AGROW>
    end
end
end

% -----------------------------------------------------------------------
function v = localLogterp(R, y, xq)
%LOCALLOGTERP  Interpolation in log-log, ausserhalb des Rasters NaN.
ok = isfinite(y) & y > 0 & isfinite(R);
v = nan(size(xq));
if nnz(ok) >= 2
    v = 10.^interp1(log10(R(ok)), log10(y(ok)), log10(xq), 'linear', NaN);
end
end

% -----------------------------------------------------------------------
function localReport(out)
o = out.opts;
fprintf('\n==== Downlink: 1 Nutzer @ x  vs.  n Nutzer @ x/n ====\n');
fprintf('Ergebnisse : %s, f_c = %g GHz\n', o.resultsDir, o.fcGHz);
fprintf('Fall A     : %s\n', out.baseTag);
fprintf('Fall B     : %s, Antennen: %s\n', strjoin(o.userGear,'/'), o.userAntenna);
if o.txModel == "shared", xtxTag = "x"; else, xtxTag = "x/n"; end
fprintf('Sendemodell: %s  (x_tx = %s)\n', o.txModel, xtxTag);
if o.txModel == "perUser"
    fprintf(['HINWEIS    : die n Sendeketten schoepfen B <= eta*f_c jede fuer sich aus,\n' ...
             '             der Sender belegt also bis zu n-faches Spektrum. Gewinne\n' ...
             '             jenseits der Reichweite von Fall A sind zum Teil Bandbreite.\n']);
end
fprintf('\n');
fprintf('%-4s %-6s %-26s %-12s %-12s %s\n', ...
    'n','B>A?','x-Bereich [bit/s]','max Gewinn','bei x','beste Nutzer-Konfig');
for k = 1:numel(o.nList)
    if out.anyWin(k)
        fprintf('%-4d %-6s %-26s %-12s %-12.3g %s\n', o.nList(k), 'ja', ...
            sprintf('%.3g .. %.3g', out.xLo(k), out.xHi(k)), ...
            sprintf('%.2fx', out.maxGain(k)), out.xAtMax(k), out.tagAtMax(k));
    else
        fprintf('%-4d %-6s %-26s %-12s %-12s %s\n', o.nList(k), 'nein','-','-','-','-');
    end
end

% Aufschluesselung an der Stelle, an der Fall A am guenstigsten ist
[~, ia] = min(out.EA);
fprintf('\nAufschluesselung bei x = %.3g bit/s (Optimum von Fall A):\n', out.x(ia));
fprintf('  A  %-26s E = %9.3g   (tx %9.3g / rx %9.3g)\n', out.baseWinner(ia), ...
    out.EA(ia), out.EAtx(ia), out.EArx(ia));
for k = 1:numel(o.nList)
    if isfinite(out.EB(ia,k))
        fprintf('  B  n=%-3d %-22s E = %9.3g   (tx %9.3g / rx %9.3g)  ->  %.2fx\n', ...
            o.nList(k), out.winner(ia,k), out.EB(ia,k), out.EBtx(ia,k), ...
            out.EBrx(ia,k), out.gain(ia,k));
    else
        fprintf('  B  n=%-3d %-22s  -\n', o.nList(k), '(nicht realisierbar)');
    end
end
fprintf('\n');
end

% -----------------------------------------------------------------------
function localPlot(out)
o = out.opts; x = out.x; nL = o.nList;
C = lines(max(numel(nL),3));
INK=[0.043 0.043 0.043]; INK2=[0.322 0.318 0.306];
fig = figure('Position',[100 100 1180 560],'Color','w');
tl = tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');

ax = nexttile(tl); hold(ax,'on'); grid(ax,'on'); box(ax,'off');
set(ax,'XScale','log','YScale','log','FontSize',12,'XColor',INK2,'YColor',INK2,'GridAlpha',0.12);
h = plot(ax, x, out.EA, 'k-','LineWidth',2.8,'DisplayName',['A: 1 user @ x, ' char(out.baseTag)]);
for k = 1:numel(nL)
    h(end+1) = plot(ax, x, out.EB(:,k), '-','Color',C(k,:),'LineWidth',1.9, ...
        'DisplayName',sprintf('B: n=%d users @ x/%d', nL(k), nL(k))); %#ok<AGROW>
end
xlabel(ax,'aggregate rate x [bit/s]','FontSize',13,'Color',INK2);
ylabel(ax,'E_{bit} per aggregate bit [J/bit]','FontSize',13,'Color',INK2);
title(ax,'Energy per bit','FontSize',13.5,'Color',INK,'FontWeight','bold');
legend(ax,h,'Location','southwest','Box','off','FontSize',10.5,'TextColor',INK2);

ax2 = nexttile(tl); hold(ax2,'on'); grid(ax2,'on'); box(ax2,'off');
set(ax2,'XScale','log','YScale','log','FontSize',12,'XColor',INK2,'YColor',INK2,'GridAlpha',0.12);
yline(ax2,1,'k--','LineWidth',1.4);
for k = 1:numel(nL)
    plot(ax2, x, out.gain(:,k), '-','Color',C(k,:),'LineWidth',1.9);
end
xlabel(ax2,'aggregate rate x [bit/s]','FontSize',13,'Color',INK2);
ylabel(ax2,'E_A / E_B','FontSize',13,'Color',INK2);
title(ax2,'Gain from splitting (>1: n users cheaper)', ...
    'FontSize',13.5,'Color',INK,'FontWeight','bold');

title(tl, sprintf('Downlink, one transmitter, f_c = %g GHz, d = %s, tx model "%s"', ...
    o.fcGHz, localDist(o.resultsDir), o.txModel),'FontSize',14,'Color',INK,'FontWeight','bold');

if o.outFile ~= ""
    d = fileparts(o.outFile);
    if ~isempty(d) && ~isfolder(d), mkdir(d); end
    exportgraphics(fig, o.outFile, 'Resolution', 200);
    fprintf('geschrieben: %s\n', o.outFile);
end
end

% -----------------------------------------------------------------------
function s = localDist(rd)
t = regexp(char(rd), 'd(\d+)', 'tokens', 'once');
if isempty(t), s = '?'; else, s = [t{1} ' m']; end
end
