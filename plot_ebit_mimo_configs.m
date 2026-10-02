function fig = plot_ebit_mimo_configs(resultsDir, order, outFile, fcList)
%PLOT_EBIT_MIMO_CONFIGS  E_bit JE Antennenkonfiguration ueber R_eff, fuer EINE
%   QAM-Ordnung -- eine Kurve pro MIMO-Konfiguration.
%
%   fig = plot_ebit_mimo_configs(resultsDir, order, outFile)   (Default: M=16)
%
%   Der Gear-Plot zeigt nur den GEWINNER je Rate. Hier stehen stattdessen alle
%   Kandidaten nebeneinander, also was jede Antennenkonfiguration FUER SICH
%   kosten wuerde -- damit wird sichtbar, WIE GROSS der Abstand am Umschalt-
%   punkt ist und nicht nur, DASS umgeschaltet wird. Moeglich ist das, weil
%   runSweep.m seit der MIMO-Erweiterung E_per_bit_all speichert (Spalte i =
%   antennaConfigsUsed{i}), nicht nur die Gewinnerspalte.
%
%   Die Kurven enden dort, wo die jeweilige Konfiguration die Zielrate nicht
%   mehr erreicht -- genau dieses Abreissen ist die Aussage: mehr Antennen
%   verschieben die erreichbare Maximalrate nach rechts.
if nargin < 1 || isempty(resultsDir), resultsDir = 'results'; end
if nargin < 2 || isempty(order), order = 16; end
if nargin < 3 || isempty(outFile)
    outFile = fullfile(resultsDir,'figures',sprintf('ebit_mimo_configs_M%d.png',order));
end
% fcList (GHz) waehlt die Traeger aus. Ohne Angabe werden alle genommen,
% die ein gemeinsames Ratengitter haben -- bei drei Traegern im Ordner
% ergaebe das drei Panels, von denen nur zwei auf die Folie sollen.
if nargin < 4, fcList = []; end

f = dir(fullfile(resultsDir,sprintf('qam_M%d_fc*.mat',order)));
if isempty(f)
    error('plot_ebit_mimo_configs:noData','Keine qam_M%d_fc*.mat in %s', order, resultsDir);
end

% Nur Traeger mit dem haeufigsten (= konsistenten) Ratengitter, wie im
% Gear-Plot: im Ordner koennen Laeufe mit unterschiedlichem RVec liegen.
if ~isempty(fcList)
    keepFc = false(1,numel(f));
    for i = 1:numel(f)
        v = str2double(regexp(f(i).name,'fc([\d.]+)GHz','tokens','once'));
        keepFc(i) = any(abs(fcList - v) < 1e-9);
    end
    f = f(keepFc);
    assert(~isempty(f), 'plot_ebit_mimo_configs:noCarrier', ...
        'Keine Datei fuer die angeforderten Traeger in %s', resultsDir);
end

S = arrayfun(@(x) load(fullfile(resultsDir,x.name)), f);
lens = arrayfun(@(s) numel(s.RVec), S);
keep = lens == mode(lens);
if any(~keep)
    warning('plot_ebit_mimo_configs:mixedGrid', ...
        '%d Datei(en) mit abweichendem Ratengitter weggelassen.', sum(~keep));
end
S = S(keep); f = f(keep);
fcs = arrayfun(@(x) str2double(regexp(x.name,'fc([\d.]+)GHz','tokens','once')), f);
[fcs, si] = sort(fcs); S = S(si);

% Farben/Marker richten sich nach der ANZAHL der Konfigurationen, nicht nach
% einer festen Vierer-Liste: der Multiplexing-Sweep hat 4 Kandidaten
% {1,2,4,8}, der Beamforming-Sweep 7 (bis 64x64), und eine feste Liste
% laeuft dort schlicht aus dem Index ("Index exceeds array bounds").
% lines(n) ist genau die MATLAB-Standardreihenfolge, beginnt also weiterhin
% mit Blau/Rot/Gelb.
nCfgMax = max(arrayfun(@(x) numel(x.antennaConfigsUsed), S));
C = lines(nCfgMax);
INK=[0.043 0.043 0.043]; INK2=[0.322 0.318 0.306];

nF = numel(S);
% Zwei Panels je Zeile (siehe plot_optimal_gear_nt_color.m): drei
% nebeneinander ergeben auf 16:9 ein sehr flaches Bild.
nCol = min(nF,2); nRow = ceil(nF/nCol);
% Kleinere Leinwand bei groesserer Schrift: bei 1340 px Breite und rund
% 8 Zoll Darstellungsbreite schrumpft 11.5 pt auf etwa 6.8 pt. Mit 960 px
% liegt der Faktor bei ~0.83 statt ~0.59, das Seitenverhaeltnis bleibt.
fig = figure('Position',[100 100 240+360*nCol 70+290*nRow],'Color','w');
tl = tiledlayout(nRow,nCol,'TileSpacing','compact','Padding','compact');

for a = 1:nF
    ax = nexttile; hold(ax,'on'); grid(ax,'on'); box(ax,'off');
    set(ax,'XScale','log','YScale','log','FontSize',15, ...
        'XColor',INK2,'YColor',INK2,'GridAlpha',0.12);
    R = S(a).RVec(:);
    cfg = S(a).antennaConfigsUsed;
    E = S(a).E_per_bit_all;
    h = gobjects(1,numel(cfg));
    ex = nan(1,numel(cfg)); ey = nan(1,numel(cfg)); et = strings(1,numel(cfg));
    for i = 1:numel(cfg)
        e = E(:,i); ok = isfinite(e);
        % DURCHGEZOGEN, ohne Marker: bei 400 Ratenpunkten und einem Marker
        % alle 6 Punkte liegen rund 67 weiss umrandete Marker auf der
        % Kurve, und die weissen Raender zerschneiden die Linie optisch zu
        % einer Strichpunktlinie -- obwohl der LineStyle schon '-' war.
        % Identitaet traegt ohnehin die Farbe plus das Label am Kurvenende.
        h(i) = plot(ax, R(ok), e(ok), '-', 'Color',C(i,:), 'LineWidth',2.2, ...
            'DisplayName',sprintf('%dx%d', cfg{i}.N_t, cfg{i}.N_r));
        if any(ok)
            k = find(ok,1,'last');
            ex(i) = R(k); ey(i) = e(k);
            et(i) = sprintf('%dx%d', cfg{i}.N_t, cfg{i}.N_r);
        end
    end

    % Label ans Kurvenende -- dort steht die maximal erreichbare Rate, der
    % eigentliche Punkt der Grafik. Bei 8 GHz enden die vier Konfigurationen
    % aber fast uebereinander, deshalb werden die Beschriftungen in
    % log-y auf einen Mindestabstand auseinandergeschoben, statt sich zu
    % ueberdecken. Die Reihenfolge bleibt dabei erhalten.
    vis = find(~isnan(ey));
    if ~isempty(vis)
        [~,si] = sort(ey(vis)); si = vis(si);
        % Mindestabstand in DEKADEN, nicht in Pixeln: die y-Achse umfasst
        % rund sieben Dekaden, 0.13 davon waeren nur ~10 px und damit
        % weniger als eine Zeilenhoehe.
        % Mit mehr Kurven muss der Faecher enger stehen, sonst laufen die
        % Beschriftungen bei 7 Konfigurationen ueber die Achse hinaus.
        % Der Mindestabstand haengt an der SCHRIFTGROESSE: mit 13 pt statt
        % 10 pt auf einer kleineren Leinwand deckt eine Zeile rund eine
        % halbe Dekade ab, 0.24 reichte nicht mehr und die vier Label
        % liefen ineinander.
        ly = log10(ey(si)); minSep = min(0.5, 2.0/max(numel(si)-1,1));
        for q = 2:numel(si)
            if ly(q)-ly(q-1) < minSep, ly(q) = ly(q-1)+minSep; end
        end
        for q = 1:numel(si)
            i = si(q);
            % Duenne Fuehrungslinie, damit das verschobene Label eindeutig
            % seiner Kurve zugeordnet bleibt.
            plot(ax, [ex(i) ex(i)*1.15], [ey(i) 10^ly(q)], '-', ...
                 'Color',[C(i,:) 0.55],'LineWidth',0.75,'HandleVisibility','off');
            text(ax, ex(i)*1.20, 10^ly(q), char(et(i)), ...
                'Color',INK,'FontSize',13,'FontWeight','bold', ...
                'HorizontalAlignment','left','VerticalAlignment','middle');
        end
    end
    xlim(ax,[min(R) max(R)*6]);
    title(ax,sprintf('f_c = %g GHz', fcs(a)),'FontSize',17,'Color',INK,'FontWeight','bold');
    xlabel(ax,'R_{eff} [bit/s]','FontSize',16,'Color',INK2);
    if mod(a-1,nCol) == 0
        ylabel(ax,'E_{bit} [J/bit]','FontSize',16,'Color',INK2);
    end
end
% Legende in die freie Kachel, sonst ins erste Panel.
if nF < nRow*nCol
    axL = nexttile; axis(axL,'off'); hold(axL,'on');
    hL = gobjects(1,numel(cfg));
    for i = 1:numel(cfg)
        hL(i) = plot(axL,NaN,NaN,'-','Color',C(i,:),'LineWidth',2.6, ...
            'DisplayName',sprintf('%dx%d', cfg{i}.N_t, cfg{i}.N_r));
    end
    legend(axL,hL,'Location','west','Box','off','FontSize',17,'TextColor',INK2);
else
    legend(h,'Location','southwest','Box','off','FontSize',14,'TextColor',INK2);
end
title(tl, sprintf('Energy per bit per antenna configuration, QAM M=%d', order), ...
      'FontSize',18,'Color',INK,'FontWeight','bold');

exportgraphics(fig,outFile,'Resolution',200);
fprintf('geschrieben: %s\n', outFile);
end
