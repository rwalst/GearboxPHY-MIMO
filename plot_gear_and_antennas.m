function fig = plot_gear_and_antennas(resultsDir, outFile)
%PLOT_GEAR_AND_ANTENNAS  Zwei ausgerichtete Panels: WELCHES Gear (Stufenlinie,
%   MIMO+SISO gegen SISO-only) und WIE VIELE Sendeantennen ueber der Rate.
%
%   fig = plot_gear_and_antennas(resultsDir, outFile)
%
%   UNTERSCHIED ZU plotOptimalGearReport.m: dort trugen DREI Kodierungen
%   EINE Linie (y = Gear, Markerform = N_t, Linienstil = MIMO+SISO vs.
%   SISO-only). Die Markerform verlor dabei -- bei ~100 Ratenpunkten
%   ueberlappen die Marker, und o/s/^/d sind in dieser Groesse kaum
%   unterscheidbar. N_t bekommt deshalb ein EIGENES Panel unter dem
%   Gear-Panel, mit gemeinsamer x-Achse. Alles andere bleibt wie gehabt.
%
%   DIE SISO-ONLY-KURVE BLEIBT (gestrichelt) und ist NICHT redundant: der
%   VERSATZ zwischen durchgezogener und gestrichelter Stufe zeigt, dass die
%   Gearwechsel mit MIMO an anderen Raten liegen als ohne -- genau das geht
%   verloren, wenn man nur den Gesamtsieger zeichnet.
%
%   Y-BESCHRIFTUNG: der "order" heisst je nach Gear etwas anderes -- bei QAM
%   die Konstellationsgroesse M, bei ZXM der FTN-Ueberabtastfaktor M_Tx.
%   Pulse-Energy/-Arbitrary haben keinen solchen Parameter und bekommen
%   deshalb gar keine Zahl.
if nargin < 1 || isempty(resultsDir), resultsDir = 'main'; end
if nargin < 2 || isempty(outFile), outFile = fullfile(resultsDir,'figures','gear_and_antennas.png'); end

rec = localLoad(resultsDir);
fcAll = unique([rec.fc]);

% ---- y-Achse: Gears von unten nach oben ordnen ------------------------
prio  = {'pulseenergy','pulsearbitrary','zxm','qam'};
disp_ = {'Pulse-Energy','Pulse-Arbitrary','ZXM','QAM'};
keys = unique(arrayfun(@(r) sprintf('%s|%d', r.gear, r.order), rec,'UniformOutput',false));
gk = strings(numel(keys),1); go = zeros(numel(keys),1);
for i=1:numel(keys)
    parts = split(string(keys{i}),'|'); gk(i)=parts(1); go(i)=double(parts(2));
end
rank = arrayfun(@(g) find(strcmp(prio,g),1), gk);
[~,ord] = sortrows([rank go]); gk = gk(ord); go = go(ord);
nGear = numel(gk);
yLab = strings(nGear,1);
for i=1:nGear
    switch gk(i)
        case "qam", yLab(i) = sprintf('QAM M=%d', go(i));
        case "zxm", yLab(i) = sprintf('ZXM M_{Tx}=%d', go(i));
        otherwise,  yLab(i) = disp_{strcmp(prio,gk(i))};
    end
end

C = [0 0.4470 0.7410; 0.8500 0.3250 0.0980; 0.9290 0.6940 0.1250; 0.4940 0.1840 0.5560];
INK=[0.043 0.043 0.043]; INK2=[0.322 0.318 0.306];
fig = figure('Position',[100 100 1180 780],'Color','w');
tiledlayout(3,1,'TileSpacing','compact','Padding','compact');
axA = nexttile([2 1]); hold(axA,'on'); box(axA,'off'); grid(axA,'on');
axB = nexttile;        hold(axB,'on'); box(axB,'off'); grid(axB,'on');

hC = gobjects(1,numel(fcAll));
allNt = [];
for a = 1:numel(fcAll)
    sel = rec([rec.fc]==fcAll(a));
    R = sel(1).R;
    E = inf(numel(R),nGear); Es = inf(numel(R),nGear); NT = nan(numel(R),nGear);
    for i = 1:numel(sel)
        j = find(gk==string(sel(i).gear) & go==sel(i).order,1);
        E(:,j) = sel(i).E; Es(:,j) = sel(i).Esiso; NT(:,j) = sel(i).Nt;
    end
    [bm,im] = min(E,[],2);  okm = isfinite(bm);
    [bs,is] = min(Es,[],2); oks = isfinite(bs);
    ym = nan(size(R)); ym(okm) = im(okm);
    ys = nan(size(R)); ys(oks) = is(oks);
    nt = nan(size(R)); for k = find(okm).', nt(k) = NT(k,im(k)); end

    hC(a) = stairs(axA,R,ym,'-','Color',C(a,:),'LineWidth',2.2, ...
                   'DisplayName',sprintf('f_c = %g GHz',fcAll(a)));
    stairs(axA,R,ys,'--','Color',C(a,:),'LineWidth',1.5,'HandleVisibility','off');
    stairs(axB,R,nt,'-','Color',C(a,:),'LineWidth',2.2,'HandleVisibility','off');
    allNt = [allNt; nt(~isnan(nt))]; %#ok<AGROW>
end

set(axA,'XScale','log','YLim',[0.4 nGear+0.6],'YTick',1:nGear,'YTickLabel',cellstr(yLab), ...
    'FontSize',11.5,'XColor',INK2,'YColor',INK2,'GridAlpha',0.12,'XTickLabel',[]);
% Ticks aus den TATSAECHLICH gewaehlten Antennenzahlen: fest [1 2 4 8]
% schneidet beim Beamforming-Sweep alles ab N_t=16 unsichtbar weg.
ntTicks = unique(allNt(:)).';
if isempty(ntTicks), ntTicks = 1; end
set(axB,'XScale','log','YScale','log', ...
    'YLim',[0.8 max(ntTicks)*1.35],'YTick',ntTicks, ...
    'YTickLabel',arrayfun(@(v) sprintf('%g',v), ntTicks,'UniformOutput',false), ...
    'FontSize',11.5,'XColor',INK2,'YColor',INK2,'GridAlpha',0.12);
xlim(axA,[min(R) max(R)]); xlim(axB,[min(R) max(R)]);
title(axA,'Which gear is selected','FontSize',13.5,'Color',INK,'FontWeight','bold');
title(axB,'How many transmit antennas','FontSize',12.5,'Color',INK,'FontWeight','bold');
ylabel(axB,'N_t','FontSize',12.5,'Color',INK2);
xlabel(axB,'R_{eff} [bit/s]','FontSize',12.5,'Color',INK2);

% Linienstil-Bedeutung als neutrale graue Dummy-Eintraege -- die Farbe
% traegt die Traegeridentitaet, der Stil die MIMO/SISO-Unterscheidung.
hS(1) = plot(axA,NaN,NaN,'-','Color',[.45 .45 .45],'LineWidth',2.2,'DisplayName','MIMO + SISO');
hS(2) = plot(axA,NaN,NaN,'--','Color',[.45 .45 .45],'LineWidth',1.5,'DisplayName','SISO only');
legend(axA,[hC hS],'Location','northwest','Box','off','FontSize',10.5,'TextColor',INK2);

exportgraphics(fig,outFile,'Resolution',200);
fprintf('geschrieben: %s\n', outFile);
end

% =======================================================================
function rec = localLoad(resultsDir)
%LOCALLOAD  Ergebnisse einlesen; naqam ist die Referenz und kein Gear im
%   Wettbewerb. Nur Traeger mit EINEM konsistenten Ratengitter behalten --
%   im Ordner koennen Laeufe mit unterschiedlichem RVec nebeneinander liegen,
%   die sich nicht gemeinsam darstellen lassen.
f = dir(fullfile(resultsDir,'*.mat'));
if isempty(f), error('plot_gear_and_antennas:noData','Keine .mat in %s', resultsDir); end
rec = struct('fc',{},'gear',{},'order',{},'R',{},'E',{},'Esiso',{},'Nt',{});
for i = 1:numel(f)
    tok = regexp(erase(f(i).name,'.mat'),'^(.+?)_M(\d+)_fc([\d.]+)GHz$','tokens','once');
    if isempty(tok) || strcmp(tok{1},'naqam'), continue; end
    S = load(fullfile(resultsDir,f(i).name));
    e = S.E_per_bit(:); e(~isfinite(e)) = inf;
    es = e;
    if isfield(S,'E_per_bit_all') && ~isempty(S.E_per_bit_all)
        es = S.E_per_bit_all(:,1); es(~isfinite(es)) = inf;   % Spalte 1 = 1x1
    end
    nt = nan(size(e)); if isfield(S,'Optimal_N_t'), nt = S.Optimal_N_t(:); end
    rec(end+1) = struct('fc',str2double(tok{3}),'gear',tok{1},'order',str2double(tok{2}), ...
                        'R',S.RVec(:),'E',e,'Esiso',es,'Nt',nt); %#ok<AGROW>
end
lens = arrayfun(@(r) numel(r.R), rec);
nUse = mode(lens);
drop = unique([rec(lens~=nUse).fc]);
rec = rec(lens==nUse);
if ~isempty(drop)
    warning('plot_gear_and_antennas:mixedGrid', ...
        'Traeger [%s] GHz haben ein anderes Ratengitter und werden weggelassen.', ...
        strjoin(string(drop),', '));
end
end
