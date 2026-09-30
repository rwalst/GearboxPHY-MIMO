function fig = plot_optimal_gear_nt_color(resultsDir, fcGHz, outFile, sisoExcludeQamOrders)
%PLOT_OPTIMAL_GEAR_NT_COLOR  Gewaehltes Gear ueber der Rate, Farbe der
%   Kurve = gewaehlte Antennenzahl N_t. fcGHz darf MEHRERE Traeger
%   enthalten; die werden dann zu Panels EINER Abbildung.
%
%   fig = plot_optimal_gear_nt_color(resultsDir, fcGHz, outFile)
%
%   WARUM PANELS UND NICHT MEHRERE ABBILDUNGEN: drei einzelne Abbildungen
%   nebeneinander auf eine Folie gelegt schrumpfen jede auf ein Drittel der
%   Breite -- samt Achsenbeschriftung, die dann bei etwa 6 pt landet. In
%   EINER Abbildung stehen die zehn Gear-Namen nur EINMAL ganz links, die
%   restliche Breite gehoert den Kurven.
%
%   Gegenueber plot_gear_and_antennas.m: dort traegt ein ZWEITES Panel die
%   Antennenzahl. Liegt N_t auf der FARBE, ist das zweite Panel
%   ueberfluessig, und man sieht unmittelbar, welcher Gearwechsel mit einem
%   Antennenwechsel zusammenfaellt und welcher nicht.
%
%   Die gestrichelte SISO-only-Kurve bleibt (sie zeigt, dass die
%   Gearwechsel ohne MIMO bei anderen Raten liegen), ist aber NEUTRAL GRAU:
%   sie trifft keine Antennenwahl, sondern ist per Konstruktion 1x1. Farbe
%   bedeutet damit ausschliesslich "so viele Antennen wurden GEWAEHLT".
%   sisoExcludeQamOrders (Default 4): QAM-Ordnungen, die AUS DER
%   SISO-ONLY-KURVE herausgenommen werden. ACHTUNG, das ist eine bewusste
%   Abweichung: die gestrichelte Kurve ist damit NICHT mehr das argmin ueber
%   alle Gears, sondern das argmin ueber alle Gears OHNE diese Ordnungen.
%   Die farbige MIMO+SISO-Kurve bleibt unangetastet, also vergleichen die
%   beiden Kurven streng genommen unterschiedliche Gear-Mengen. [] stellt
%   das reine argmin wieder her.
if nargin < 1 || isempty(resultsDir), resultsDir = 'results'; end
if nargin < 4, sisoExcludeQamOrders = 4; end
if nargin < 2 || isempty(fcGHz),      fcGHz = 8;             end
if nargin < 3 || isempty(outFile)
    if isscalar(fcGHz)
        outFile = fullfile(resultsDir,'figures', ...
            sprintf('optimal_gear_nt_color_fc%gGHz.png',fcGHz));
    else
        outFile = fullfile(resultsDir,'figures','optimal_gear_nt_color.png');
    end
end

nFc = numel(fcGHz);
D = cell(1,nFc);
for a = 1:nFc
    D{a} = localWinners(resultsDir, fcGHz(a), sisoExcludeQamOrders);
end

% Gear-Achse und Farbskala EINMAL fuer alle Panels bestimmen, sonst
% bedeuten dieselbe Zeile bzw. dieselbe Farbe in zwei Panels
% Verschiedenes.
yLab = D{1}.yLab; nGear = numel(yLab);
allNt = [];
for a = 1:nFc, allNt = [allNt; D{a}.nt(~isnan(D{a}.nt))]; end %#ok<AGROW>
ntVals = unique(allNt).';
if isempty(ntVals), ntVals = 1; end
C = lines(numel(ntVals));
ntLabels = containers.Map('KeyType','double','ValueType','char');
for a = 1:nFc
    kk = D{a}.ntLab.keys;
    for i = 1:numel(kk), ntLabels(kk{i}) = D{a}.ntLab(kk{i}); end
end

INK=[0.043 0.043 0.043]; INK2=[0.322 0.318 0.306];
% ZWEI PANELS JE ZEILE. Drei nebeneinander auf 16:9 werden sehr breit und
% sehr flach -- beim E_bit-Bild blieben je Panel nur rund 2.5 Zoll Hoehe.
% Im 2x2-Raster sind die Panels hoeher, und die frei bleibende vierte
% Kachel nimmt die Legende auf, statt sie in ein Datenpanel zu quetschen.
nCol = min(nFc,2); nRow = ceil(nFc/nCol);
% Kleinere Leinwand bei groesserer Schrift (wie plot_ebit_mimo_configs.m):
% bei 1340 px Breite und rund 8 Zoll Darstellungsbreite schrumpft 11.5 pt
% auf etwa 6.6 pt. Mit 960 px liegt der Faktor bei ~0.81 statt ~0.57.
fig = figure('Position',[100 100 240+360*nCol 70+290*nRow],'Color','w');
tl = tiledlayout(nRow,nCol,'TileSpacing','compact','Padding','compact');

for a = 1:nFc
    ax = nexttile; hold(ax,'on'); grid(ax,'on'); box(ax,'off');
    set(ax,'XScale','log','FontSize',14,'XColor',INK2,'YColor',INK2,'GridAlpha',0.12);
    % SISO-only zuerst (liegt hinten), neutral grau -- diese Kurve trifft
    % keine Antennenwahl, Grau heisst hier "Referenz".
    localStep(ax, D{a}.R, D{a}.ys, ones(size(D{a}.R)), ntVals, C, '--', 1.6, [0.45 0.45 0.45]);
    localStep(ax, D{a}.R, D{a}.ym, D{a}.nt, ntVals, C, '-', 2.6);
    set(ax,'YLim',[0.4 nGear+0.6],'YTick',1:nGear);
    if mod(a-1,nCol) == 0
        set(ax,'YTickLabel',cellstr(yLab));   % Gear-Namen je Zeile nur links
    else
        set(ax,'YTickLabel',[]);
    end
    xlim(ax,[min(D{a}.R) max(D{a}.R)]);
    title(ax, sprintf('f_c = %g GHz', fcGHz(a)),'FontSize',17,'Color',INK,'FontWeight','bold');
end

% Legende: in die freie Kachel, sonst in das erste Panel.
if nFc < nRow*nCol
    axL = nexttile; axis(axL,'off'); hold(axL,'on'); loc = 'west'; fsz = 17;
else
    axL = nexttile(1); loc = 'northwest'; fsz = 14;
end
hL = gobjects(0); lbl = {};
for v = ntVals
    hL(end+1) = plot(axL,NaN,NaN,'-','Color',C(ntVals==v,:),'LineWidth',2.8); %#ok<AGROW>
    if isKey(ntLabels, v)
        lbl{end+1} = ntLabels(v); %#ok<AGROW>
    else
        lbl{end+1} = sprintf('%dx%d', v, v); %#ok<AGROW>   % nur fuer Ergebnisse vor antennaConfigsUsed
    end
end
hL(end+1) = plot(axL,NaN,NaN,'--','Color',[.45 .45 .45],'LineWidth',1.8);
lbl{end+1} = 'SISO only';
legend(axL,hL,lbl,'Location',loc,'Box','off','FontSize',fsz,'TextColor',INK2);
xlabel(tl,'R_{eff} [bit/s]','FontSize',16,'Color',INK2);
title(tl,'Selected gear  -  colour = number of antennas N_t', ...
      'FontSize',18,'Color',INK,'FontWeight','bold');

exportgraphics(fig,outFile,'Resolution',200);
fprintf('geschrieben: %s\n', outFile);
end

% =======================================================================
function W = localWinners(resultsDir, fcGHz, sisoExcludeQamOrders)
pat = sprintf('*_fc%gGHz.mat', fcGHz);
f = dir(fullfile(resultsDir, pat));
assert(~isempty(f), 'plot_optimal_gear_nt_color:noData','Keine %s in %s', pat, resultsDir);
rec = struct('gear',{},'order',{},'R',{},'E',{},'Esiso',{},'Nt',{});
% N_t -> "N_txN_r": die Beschriftung kommt aus den TATSAECHLICH gerechneten
% Konfigurationen, nicht aus der Annahme N_r = N_t -- eine nicht-quadratische
% Konfiguration (z.B. 2x4) waere sonst still falsch beschriftet.
ntLab = containers.Map('KeyType','double','ValueType','char');
for i = 1:numel(f)
    tok = regexp(erase(f(i).name,'.mat'),'^(.+?)_M(\d+)_fc','tokens','once');
    if isempty(tok) || strcmp(tok{1},'naqam'), continue; end   % naqam = Referenz
    S = load(fullfile(resultsDir,f(i).name));
    if isfield(S,'antennaConfigsUsed')
        for ci = 1:numel(S.antennaConfigsUsed)
            c_ = S.antennaConfigsUsed{ci};
            ntLab(c_.N_t) = sprintf('%dx%d', c_.N_t, c_.N_r);
        end
    end
    e = S.E_per_bit(:); e(~isfinite(e)) = inf;
    es = e;
    if isfield(S,'E_per_bit_all') && ~isempty(S.E_per_bit_all)
        es = S.E_per_bit_all(:,1); es(~isfinite(es)) = inf;    % Spalte 1 = 1x1
    end
    nt = nan(size(e)); if isfield(S,'Optimal_N_t'), nt = S.Optimal_N_t(:); end
    rec(end+1) = struct('gear',tok{1},'order',str2double(tok{2}), ...
                        'R',S.RVec(:),'E',e,'Esiso',es,'Nt',nt); %#ok<AGROW>
end
lens = arrayfun(@(r) numel(r.R), rec);
rec = rec(lens == mode(lens));

prio  = {'pulseenergy','pulsearbitrary','zxm','qam'};
disp_ = {'Pulse-Energy','Pulse-Arbitrary','ZXM','QAM'};
keys = unique(arrayfun(@(r) sprintf('%s|%d', r.gear, r.order), rec,'UniformOutput',false));
gk = strings(numel(keys),1); go = zeros(numel(keys),1);
for i=1:numel(keys)
    q = split(string(keys{i}),'|'); gk(i)=q(1); go(i)=double(q(2));
end
[~,ord] = sortrows([arrayfun(@(g) find(strcmp(prio,g),1), gk) go]);
gk = gk(ord); go = go(ord); nGear = numel(gk);
yLab = strings(nGear,1);
for i=1:nGear
    switch gk(i)
        case "qam", yLab(i) = sprintf('QAM M=%d', go(i));
        case "zxm", yLab(i) = sprintf('ZXM M_{Tx}=%d', go(i));
        otherwise,  yLab(i) = disp_{strcmp(prio,gk(i))};
    end
end

R = rec(1).R; n = numel(R);
E = inf(n,nGear); Es = inf(n,nGear); NT = nan(n,nGear);
for i = 1:numel(rec)
    j = find(gk==string(rec(i).gear) & go==rec(i).order,1);
    E(:,j) = rec(i).E; Es(:,j) = rec(i).Esiso; NT(:,j) = rec(i).Nt;
end
[bm,im] = min(E,[],2);  okm = isfinite(bm);
% Ausgeschlossene QAM-Ordnungen aus der SISO-Spaltenmenge nehmen (nur Es!).
% inf statt Loeschen, damit die Spaltenindizes -> yLab-Zeilen gueltig bleiben.
if ~isempty(sisoExcludeQamOrders)
    drop = (gk == "qam") & ismember(go, sisoExcludeQamOrders(:));
    Es(:, drop) = inf;
end
[bs,is] = min(Es,[],2); oks = isfinite(bs);
W.R = R; W.yLab = yLab;
W.ym = nan(n,1); W.ym(okm) = im(okm);
W.ys = nan(n,1); W.ys(oks) = is(oks);
W.nt = nan(n,1); for k = find(okm).', W.nt(k) = NT(k,im(k)); end
W.ntLab = ntLab;
end

% -----------------------------------------------------------------------
function localStep(ax, R, y, nt, ntVals, C, style, lw, fixedCol)
%LOCALSTEP  Treppenkurve, Segment fuer Segment in der Farbe des dort
%   gueltigen N_t. stairs() kann das nicht: es zeichnet EINE Linie in EINER
%   Farbe. Deshalb je Ratenintervall ein waagerechtes und ein senkrechtes
%   Stueck einzeln, was den Farbwechsel exakt an die Stufe legt.
if nargin < 9, fixedCol = []; end
n = numel(R);
for k = 1:n-1
    if isnan(y(k)), continue; end
    if isempty(fixedCol)
        ci = find(ntVals == nt(k), 1);
        if isempty(ci), ci = 1; end
        col = C(ci,:);
    else
        col = fixedCol;
    end
    line(ax, [R(k) R(k+1)], [y(k) y(k)], 'Color', col, 'LineStyle', style, 'LineWidth', lw);
    if ~isnan(y(k+1)) && y(k+1) ~= y(k)
        % Die Senkrechte gehoert zum FOLGENDEN Zustand: dort wechselt das
        % Gear, und die Farbe soll den dann gueltigen N_t zeigen.
        if isempty(fixedCol)
            cj = find(ntVals == nt(k+1), 1);
            if isempty(cj), cj = ci; end
            colv = C(cj,:);
        else
            colv = fixedCol;
        end
        line(ax, [R(k+1) R(k+1)], [y(k) y(k+1)], 'Color', colv, 'LineStyle', style, 'LineWidth', lw);
    end
end
end
