function out = analyze_best_gear(opt)
%ANALYZE_BEST_GEAR  Welcher Gang gewinnt wo -- je Kanal und je ADC-Regel.
%
%   out = analyze_best_gear();
%   out = analyze_best_gear(figures=false);
%
%   ZWEI ABBILDUNGEN, weil "Gang" zwei Dinge heissen kann:
%
%   TEIL A (aus 3b): die gewaehlte KONFIGURATION innerhalb von QAM. Je
%   Kanal und ADC-Regel ein Feld, ueber der Distanz die Antennenzahl, die
%   das Gearbox waehlt -- getrennt fuer MUX und BF, mit Markierung, welcher
%   Modus dort guenstiger ist. Die Modulationsordnung steht als Zahl am
%   Punkt, wo sie von M = 4 abweicht (sie ist in rund 94 % der Zellen 4).
%
%   TEIL B (aus 3a): die GANG-FAMILIE ueber der Rate. Hier konkurrieren
%   alle Gaenge des Gearbox -- Pulse-Energy, Pulse-Arbitrary, ZXM, NA-QAM
%   und QAM -- und QAM tritt dreifach an: als SISO, als Multiplexing und
%   als Beamforming. Je Distanz und ADC-Regel ein Feld.
%
%   WARUM QAM-SISO EINE EIGENE KATEGORIE IST: bei N = 1 sind MUX und BF
%   dasselbe System, die Kurven sind identisch. Ohne eigene Kategorie
%   waere der Gewinner dort willkuerlich einer von beiden, und der
%   Eindruck entstuende, Multiplexing oder Beamforming "gewinne" in einem
%   Bereich, in dem gar keine Mehrantennenuebertragung stattfindet.
%
%   DIE NICHT-QAM-GAENGE HAENGEN NICHT VON KANAL UND ADC-REGEL AB. Sie
%   kommen aus Gasts SISO-Kurven, die der Export unveraendert in jeden
%   Variantenordner kopiert. In Teil B sind sie deshalb in jedem Feld
%   dieselben; nur die QAM-Kategorien aendern sich mit der Regel. Das ist
%   kein Fehler der Abbildung, sondern der Grund, warum der Vergleich der
%   ADC-Regeln ueberhaupt nur fuer QAM gestellt wird.
arguments
    opt.figures (1,1) logical = true
    opt.save (1,1) logical = true
    opt.fcGHz (1,1) double = 28
    opt.Ms (1,:) double = [4 16 64 256]          % MIMO-faehige Ordnungen
    opt.MsAll (1,:) double = [4 16 64 256 1024]  % inkl. der SISO-only-Ordnung
    opt.Ns3a (1,:) double = [1 2 4 8 16]
    opt.dist3a (1,:) double = [50 500 5000]
    opt.rules (1,:) string = ["fixedB" "scaledB"]
end

resDir = gearboxphy.paths.resultsDir('');
figDir = fullfile(resDir, 'cmp_figures');
if opt.save && ~isfolder(figDir), mkdir(figDir); end

% ---- TEIL A ------------------------------------------------------------
% Setzt auf analyze_bf_vs_mux_qam auf, statt das Laden und die
% symmetrische Maskierung ein zweites Mal zu schreiben -- EINE Quelle fuer
% die Fairnessregel, sonst laufen die beiden Auswertungen auseinander.
cmp = analyze_bf_vs_mux_qam(figures=false, save=false);
d = cmp.grid.distances; rates = cmp.grid.rates; D = cmp.cells;

fprintf('\n================================================================\n');
fprintf(' TEIL A -- gewaehlte Konfiguration je Kanal und ADC-Regel\n');
fprintf('================================================================\n');
for ri = 1:numel(rates)
    fprintf('\n---- R_eff = %.0e bit/s ----\n', rates(ri));
    fprintf('%-10s %-10s %s\n', 'Kanal', 'ADC', 'Distanz -> N(MUX)/N(BF), * = dieser Modus guenstiger');
    for k = 1:numel(D)
        fprintf('%-10s %-10s', D(k).chan, D(k).rule);
        for i = localNearest(d, [10 100 1000 10000])
            nm = D(k).Nmux(i,ri); nb = D(k).Nbf(i,ri);
            if ~isfinite(nm) || ~isfinite(nb), fprintf('%14s', '-'); continue; end
            if D(k).flag(i,ri) == "=", mk = '=';            % dasselbe System
            elseif D(k).q(i,ri) < 1,    mk = 'B';           % BF guenstiger
            else,                       mk = 'M';           % MUX guenstiger
            end
            fprintf('%10s%-4s', sprintf('%g/%g', nm, nb), ['(' mk ')']);
        end
        fprintf('\n');
    end
end

% ---- TEIL B ------------------------------------------------------------
B = localBestGear(resDir, opt);
fprintf('\n================================================================\n');
fprintf(' TEIL B -- welche Gang-FAMILIE gewinnt, ueber der Rate\n');
fprintf('================================================================\n');
for k = 1:numel(B)
    fprintf('\n---- d = %g m, %s ----\n', B(k).distance, B(k).rule);
    [u, ~, ic] = unique(B(k).winner(isfinite(B(k).winner)), 'stable');
    Rfin = B(k).R(isfinite(B(k).winner));
    for j = 1:numel(u)
        sel = ic == j;
        fprintf('   %-16s von %8.2e bis %8.2e bit/s (%d Punkte)\n', ...
                B(k).names(u(j)), min(Rfin(sel)), max(Rfin(sel)), sum(sel));
    end
end

out = struct('partA', D, 'grid', cmp.grid, 'partB', B);
if opt.figures
    localFigA(D, d, rates, figDir, opt);
    localFigB(B, figDir, opt);
end
if opt.save
    f = fullfile(figDir, 'best_gear_summary.mat');
    save(f, 'out');
    fprintf('\nZusammenfassung: %s\n', f);
end
end

% =======================================================================
function B = localBestGear(resDir, opt)
%LOCALBESTGEAR  Je (Distanz, ADC-Regel): welcher Gang haelt das Minimum.
%   Kategorien: die Nicht-QAM-Gaenge wie sie sind, plus QAM dreifach
%   (SISO / Multiplexing / Beamforming).
names = ["Pulse-Energy" "Pulse-Arbitrary" "ZXM" "NA-QAM" "QAM SISO" ...
         "QAM-MUX" "QAM-BF"];
B = struct('distance',{}, 'rule',{}, 'R',{}, 'E',{}, 'winner',{}, 'names',{});
for rule = opt.rules
    for dd = opt.dist3a
        rdM = fullfile(resDir, sprintf('cmp_mux_%s_d%d', rule, dd));
        rdB = fullfile(resDir, sprintf('cmp_bf_%s_d%d',  rule, dd));
        if ~isfolder(rdM) || ~isfolder(rdB), continue; end

        % --- Nicht-QAM: SISO, kanal- und regelunabhaengig (s. Kopf) ----
        [Rref, ePE] = localGear(rdM, 'pulseenergy',    1,    opt);
        [~,    ePA] = localGear(rdM, 'pulsearbitrary', 1,    opt);
        [~,    eNA] = localGear(rdM, 'naqam',          1024, opt);
        eZX = [];
        for mtx = [1 2 3]
            [~, e] = localGear(rdM, 'zxm', mtx, opt);
            if isempty(e), continue; end
            if isempty(eZX), eZX = e; else, eZX = min(eZX, e); end
        end
        if isempty(Rref), continue; end

        % --- QAM: Wuerfel beider Modi, symmetrisch maskiert ------------
        cm = localQamCube(rdM, opt); cb = localQamCube(rdB, opt);
        if isempty(cm) || isempty(cb), continue; end
        both = isfinite(cm) & isfinite(cb);
        cm(~both) = NaN; cb(~both) = NaN;
        iS = find(opt.Ns3a == 1, 1);
        eSISO = squeeze(min(cm(:,:,iS), [], 2)).';          % N = 1
        keep = opt.Ns3a >= 2;
        eMUX = squeeze(min(min(cm(:,:,keep), [], 3), [], 2)).';
        eBF  = squeeze(min(min(cb(:,:,keep), [], 3), [], 2)).';

        E = [ePE(:) ePA(:) eZX(:) eNA(:) eSISO(:) eMUX(:) eBF(:)].';
        [~, w] = min(E, [], 1, 'omitnan');
        w = double(w);
        w(all(~isfinite(E), 1)) = NaN;
        B(end+1) = struct('distance',dd, 'rule',rule, 'R',Rref, 'E',E, ...
                          'winner',w, 'names',names); %#ok<AGROW>
    end
end
end

function [R, e] = localGear(rd, gearName, order, opt)
%LOCALGEAR  E_per_bit eines Gangs (schon Huellkurve ueber die
%   Antennenkonfigurationen -- bei den Nicht-QAM-Gaengen ist das SISO).
R = []; e = [];
f = fullfile(rd, sprintf('%s_M%d_fc%gGHz.mat', gearName, order, opt.fcGHz));
if ~isfile(f), return; end
T = load(f);
R = T.RVec(:).'; e = T.E_per_bit(:).';
end

function cube = localQamCube(rd, opt)
%LOCALQAMCUBE  QAM als (nR x nM x nN), aus E_per_bit_all plus
%   antennaConfigsUsed -- NICHT aus E_per_bit, das schon ueber die
%   Antennenkonfigurationen minimiert ist und sich nicht mehr maskieren
%   laesst (dieselbe Begruendung wie in analyze_bf_vs_mux_qam).
cube = [];
for mi = 1:numel(opt.MsAll)
    f = fullfile(rd, sprintf('qam_M%d_fc%gGHz.mat', opt.MsAll(mi), opt.fcGHz));
    if ~isfile(f), continue; end
    T = load(f);
    if isempty(cube)
        cube = nan(numel(T.RVec), numel(opt.MsAll), numel(opt.Ns3a));
    end
    cfg = T.antennaConfigsUsed;
    if iscell(cfg) && isscalar(cfg) && iscell(cfg{1}), cfg = cfg{1}; end
    for ci = 1:numel(cfg)
        c = cfg{ci};
        if isstruct(c), nt = c.N_t; else, nt = c(1); end
        ni = find(opt.Ns3a == nt, 1);
        if isempty(ni) || ci > size(T.E_per_bit_all, 2), continue; end
        cube(:, mi, ni) = T.E_per_bit_all(:, ci);
    end
end
end

function i = localNearest(d, targets)
i = arrayfun(@(t) find(abs(d - t) == min(abs(d - t)), 1), targets);
end

function localFigA(D, d, rates, figDir, opt)
%LOCALFIGA  Gewaehlte Antennenzahl ueber der Distanz, je Kanal/Regel.
for ri = 1:numel(rates)
    fig = figure('Position',[60 60 1250 620], 'Color','w');
    nk = numel(D); nc = 3; nr = ceil(nk/nc);
    for k = 1:nk
        ax = subplot(nr, nc, k); hold(ax,'on'); grid(ax,'on');
        nm = D(k).Nmux(:,ri); nb = D(k).Nbf(:,ri);
        stairs(ax, d, nm, '-o', 'Color',[0 0.447 0.741], 'MarkerSize',3, ...
               'DisplayName','MUX');
        stairs(ax, d, nb, '--s', 'Color',[0.85 0.325 0.098], 'MarkerSize',3, ...
               'DisplayName','BF');
        % Gewinner markieren: gefuellter Punkt auf der guenstigeren Kurve
        win = D(k).q(:,ri) < 1;  triv = D(k).flag(:,ri) == "=";
        iB = find(win & ~triv);  iM = find(~win & ~triv);
        plot(ax, d(iB), nb(iB), 's', 'MarkerFaceColor',[0.85 0.325 0.098], ...
             'MarkerEdgeColor','none', 'MarkerSize',6, 'HandleVisibility','off');
        plot(ax, d(iM), nm(iM), 'o', 'MarkerFaceColor',[0 0.447 0.741], ...
             'MarkerEdgeColor','none', 'MarkerSize',6, 'HandleVisibility','off');
        % M nur dort als Zahl, wo es von 4 abweicht
        for i = 1:numel(d)
            if isfinite(D(k).Mmux(i,ri)) && D(k).Mmux(i,ri) ~= 4
                text(ax, d(i), nm(i), sprintf(' %g', D(k).Mmux(i,ri)), ...
                     'FontSize',7, 'Color',[0 0.447 0.741]);
            end
        end
        set(ax, 'XScale','log', 'YScale','log', 'YTick',[1 2 4 8 16], ...
            'YLim',[0.8 22]);
        xlabel(ax,'Distanz [m]'); ylabel(ax,'gewaehltes N');
        title(ax, sprintf('%s, %s', D(k).chan, D(k).rule), 'FontSize',9);
        if k == 1, legend(ax,'Location','northwest','FontSize',7); end
    end
    sgtitle(fig, sprintf(['Gewaehlte Antennenzahl, R_{eff} = %.0e bit/s ' ...
        '(gefuellt = dieser Modus guenstiger; Zahl = M, falls nicht 4)'], rates(ri)));
    if opt.save
        exportgraphics(fig, fullfile(figDir, ...
            sprintf('best_gear_config_R%.0e.png', rates(ri))), 'Resolution',150);
    end
end
end

function localFigB(B, figDir, opt)
%LOCALFIGB  Gewinnender Gang ueber der Rate, als Band je Feld.
if isempty(B), return; end
fig = figure('Position',[60 60 1250 620], 'Color','w');
nk = numel(B); nc = 3; nr = ceil(nk/nc);
C = lines(numel(B(1).names));
for k = 1:nk
    ax = subplot(nr, nc, k); hold(ax,'on');
    w = B(k).winner; R = B(k).R;
    for g = 1:numel(B(k).names)
        sel = w == g;
        if ~any(sel), continue; end
        plot(ax, R(sel), g*ones(1,sum(sel)), 's', 'MarkerSize',5, ...
             'MarkerFaceColor',C(g,:), 'MarkerEdgeColor','none');
    end
    set(ax, 'XScale','log', 'YTick',1:numel(B(k).names), ...
        'YTickLabel',B(k).names, 'YLim',[0.5 numel(B(k).names)+0.5], ...
        'FontSize',7);
    grid(ax,'on'); xlabel(ax,'R_{eff} [bit/s]');
    title(ax, sprintf('d = %g m, %s', B(k).distance, B(k).rule), 'FontSize',9);
end
sgtitle(fig, 'Welcher Gang haelt das Minimum (QAM dreifach: SISO / MUX / BF)');
if opt.save
    exportgraphics(fig, fullfile(figDir, 'best_gear_family.png'), 'Resolution',150);
end
end
