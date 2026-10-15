function out = analyze_dbf_dac(opt)
%ANALYZE_DBF_DAC  Auswertung der DAC-Studie: was kostet die endliche
%   DAC-Aufloesung das digitale Beamforming, und wie stark haengt die
%   Antwort am DAC-Leistungsmodell.
%
%   out = analyze_dbf_dac();
%   out = analyze_dbf_dac(figures=false, save=false);
%
%   Liest results/dbfdac_distance_<kanal>_<lo>_<modell>.mat (digital) und
%   results/abfdac_distance_<variante>_<modell>.mat (analog, laeuft in der
%   Studie nur als Vergleich mit). Reine Nachbearbeitung, Sekunden, kein
%   Pool -- darf am Arbeitsplatz laufen.
%
%   DAS MASS IST q = E_bit(endlicher DAC) / E_bit(idealer DAC), jeweils als
%   HUELLKURVE ueber (M, N). Beide Seiten duerfen ihre beste Konfiguration
%   waehlen, denn genau das tut das Gearbox; q > 1 heisst, die endliche
%   Aufloesung kostet. Alles andere (gewaehlte Stufe, DAC-Anteil) wird an
%   der Konfiguration gelesen, die die endliche Seite gewaehlt hat -- sonst
%   stammen die Zahlen einer Zeile aus verschiedenen Systemen.
%
%   DER STANDARDFALL IST DIE GEMEINSAME AUSSTEUERUNG (E9): E, Ebest und
%   kBest kommen aus den _common-Ordnern. Die antennenweise Aussteuerung
%   steht als Eper daneben und beantwortet eine andere Frage -- was sie
%   WERT waere. Sie setzt hinter jedem DAC eine stufenlose Verstaerkung
%   voraus, die im Energiebudget niemand bezahlt.
%
%   VIER ABBILDUNGEN je Rate, in results/dbfdac_figures/:
%     dac_price_R<rate>.png    q ueber der Distanz -- die Hauptaussage
%     dac_level_R<rate>.png    gewaehlte Stufe kBest: wie viele Zusatzbits
%                              sich lohnen
%     dac_scaling_R<rate>.png  antennenweise gegen gemeinsam (E9)
%     dac_vs_analog_R<rate>.png  digital gegen die analogen Varianten
%   dazu summary.csv mit je (Kanal, LO, Modell, Rate, Distanz) einer Zeile.
%
%   WAS DIESE AUSWERTUNG NICHT BEANTWORTET: ob `survey` die Vorgabe des
%   DAC-Leistungsmodells wird. Sie zeigt, wie weit die drei Modelle die
%   Antwort auseinanderziehen; die Entscheidung bleibt eine Entscheidung
%   (README.md, offener Punkt).
arguments
    opt.figures (1,1) logical = true
    opt.save (1,1) logical = true
end

resDir = gearboxphy.paths.resultsDir('');
fd = dir(fullfile(resDir, 'dbfdac_distance_*.mat'));
assert(~isempty(fd), 'analyze_dbf_dac:noResults', ...
    ['Keine dbfdac_distance_*.mat in %s -- erst run_dbf_dac_distance ' ...
     '(docs/HPC_RUNBOOK_DAC.md, Schritt 3).'], resDir);
figDir = gearboxphy.paths.resultsDir('dbfdac_figures');
if opt.save && ~isfolder(figDir), mkdir(figDir); end

% ---------- digitale Seite einlesen ----------
D = struct('channel', {}, 'lo', {}, 'model', {}, 'CFG', {}, 'q', {}, ...
           'Ebest', {}, 'Eideal', {}, 'kBest', {}, 'dacShare', {}, ...
           'Mbest', {}, 'Nbest', {}, 'perGain', {}, 'levels', {});
for i = 1:numel(fd)
    T = load(fullfile(fd(i).folder, fd(i).name));
    % dacScaleStandard IST PFLICHT, und nicht aus Ordnungsliebe: in Dateien
    % von vor dem 2026-10-12 ist E die ANTENNENWEISE Aussteuerung und
    % Ecommon der Vergleich -- seit E9 ist es umgekehrt. Beide Formen tragen
    % Eideal, Ebest und kBest, eine Pruefung auf Feldnamen allein merkt den
    % Unterschied also NICHT, und q waere stillschweigend die Antwort auf
    % die andere Frage. Das Feld fehlt den alten Dateien, und daran
    % scheitert diese Auswertung absichtlich -- wie localDone im Treiber.
    localRequire(T, fd(i).name, ["Eideal" "Ebest" "kBest" "EbestDac" "dacLevels" ...
                                 "CFG" "dacScaleStandard"]);
    assert(string(T.dacScaleStandard) == "common", 'analyze_dbf_dac:scaleStandard', ...
        ['%s ist mit dacScaleStandard = "%s" gerechnet. Diese Auswertung liest E ' ...
         'und Ebest als die GEMEINSAME Aussteuerung (E9) und wuerde die Zahlen ' ...
         'sonst falsch beschriften.'], fd(i).name, string(T.dacScaleStandard));

    % Loecher melden, nicht uebergehen -- ein verworfener Antennenkandidat
    % (E7) macht eine Zelle NaN, und die Huellkurve nimmt sie dann still
    % weniger. +data/findFeasibilityHoles.m erklaert die Signatur.
    H = gearboxphy.data.findFeasibilityHoles(T.Ebest, T.CFG);
    if height(H) > 0
        warning('analyze_dbf_dac:holes', ...
            ['%s: %d Zelle(n) sind NaN, obwohl dieselbe Konfiguration bei ' ...
             'GROESSERER Distanz erreichbar ist -- das kann keine Physik sein. ' ...
             'Betroffen (M,N): %s. Nachrechnen, siehe E7.'], ...
            fd(i).name, height(H), mat2str(unique([H.M H.N], 'rows')));
    end

    [eb, mb, nb, idx] = localEnvelope(T.Ebest);
    ei = localEnvelope(T.Eideal);                     % eigene beste Konfiguration
    kb = localAt(T.kBest, idx);
    ds = localAt(T.EbestDac, idx) ./ eb;
    pg = NaN(size(eb));
    if isfield(T, 'Eper') && ~isempty(T.Eper)
        pg = localEnvelope(min(T.Eper, [], 5)) ./ eb;  % < 1: antennenweise billiger
    end

    % q < 1 IST UNMOEGLICH, und die Pruefung ist keine Formsache: E4 deckelt
    % jede DAC-Kurve beim Export an der Ideal-DAC-Kurve
    % (+data/capDacCurvesAgainstIdeal.m), also gilt zellweise
    % SE(endlich) <= SE(ideal) und damit E_bit(endlich) >= E_bit(ideal).
    % Das ueberlebt auch die Huellkurve: wenn jede Zelle groesser ist, ist
    % das Minimum groesser. Ein q < 1 heisst deshalb nicht "die
    % Quantisierung hilft", sondern dass etwas vorgelagert nicht stimmt --
    % am ehesten ungedeckelt exportierte Kurven (Export vor E4 wiederholen).
    qq = eb ./ ei;
    % TOLERANZ, UND SIE IST NICHT KOSMETISCH. E4 deckelt je ZELLE, also gilt
    % E_bit(endlich) >= E_bit(ideal) fuer dieselbe (M,N) im selben
    % Optimierungslauf. Die Huellkurven der beiden Seiten entstehen aber aus
    % UNABHAENGIGEN Mehrfachstarts, und multistartOptimize ist nicht
    % geseedet -- die endliche Seite kann deshalb knapp unter der idealen
    % landen, ohne dass etwas falsch ist. Gemessen am Cluster-Lauf vom
    % 2026-10-15: min q = 0.9914, 4 von 1000 Zellen, also 0.86 % -- in der
    % Groessenordnung der 0.42 %, die der Golden Master als Streuung zeigt.
    %
    % Das echte Artefakt sieht voellig anders aus: ungedeckelte Kurven
    % ergaben am selben Tag min q = 0.005 in 797 von 1000 Zellen. Zwischen
    % 0.86 % und 99.5 % liegen zwei Groessenordnungen, die Schwelle ist also
    % unkritisch zu setzen. 2 % trennt beides sauber.
    QTOL = 0.02;
    unter = qq < 1 - QTOL;
    knapp = qq < 1 - 1e-9 & ~unter;
    if any(unter(:))
        warning('analyze_dbf_dac:qBelowOne', ...
            ['%s: q < %.2f in %d Zelle(n), kleinstes q = %.6f. Das kann nicht ' ...
             'die Streuung des Optimierers sein -- E4 deckelt die DAC-Kurven an ' ...
             'der Ideal-DAC-Kurve. Verdacht: die Kurvenordner stammen aus einem ' ...
             'Export vor E4 oder ohne Deckelungsreferenz ' ...
             '(export:noDacCapRef).'], ...
            fd(i).name, 1-QTOL, sum(unter(:)), min(qq(unter)));
    elseif any(knapp(:))
        fprintf(['   %s: %d Zelle(n) knapp unter q = 1 (kleinstes %.4f) -- ' ...
                 'Streuung des ungeseedeten Optimierers, kein Befund.\n'], ...
            fd(i).name, sum(knapp(:)), min(qq(knapp)));
    end

    D(end+1) = struct('channel', string(T.channel), 'lo', string(T.lo), ...
        'model', string(T.dacModel), 'CFG', T.CFG, 'q', qq, ...
        'Ebest', eb, 'Eideal', ei, 'kBest', kb, 'dacShare', ds, ...
        'Mbest', mb, 'Nbest', nb, 'perGain', pg, 'levels', T.dacLevels(:)'); %#ok<AGROW>
end

% ---------- analoge Vergleichsdateien ----------
A = struct('variant', {}, 'model', {}, 'CFG', {}, 'Ebest', {});
fa = dir(fullfile(resDir, 'abfdac_distance_*.mat'));
for i = 1:numel(fa)
    T = load(fullfile(fa(i).folder, fa(i).name));
    if ~isfield(T, 'E'), continue; end
    A(end+1) = struct('variant', string(T.variant), 'model', string(T.dacModel), ...
        'CFG', T.CFG, 'Ebest', localEnvelope(T.E)); %#ok<AGROW>
end

out.digital = D; out.analog = A;
out.models  = unique([D.model]);
out.channels = unique([D.channel]);

% ---------- Konsolenbefund ----------
fprintf('\n=== Preis der endlichen DAC-Aufloesung, q = E_bit(endlich)/E_bit(ideal) ===\n');
fprintf('%-7s %-10s %-12s %-10s %-12s %-10s\n', 'Kanal', 'LO', 'DAC-Modell', 'max q', 'bei d [m]', 'Stufen');
for i = 1:numel(D)
    [mx, li] = max(D(i).q(:));
    [di, ~] = ind2sub(size(D(i).q), li);
    st = unique(D(i).kBest(isfinite(D(i).kBest)));
    fprintf('%-7s %-10s %-12s %-10.4f %-12.0f %-10s\n', D(i).channel, D(i).lo, ...
        D(i).model, mx, D(i).CFG.distances(di), mat2str(D(i).levels(st(:)')));
end
fprintf('\nq = 1 bedeutet: die endliche Aufloesung kostet nichts, weil das Gearbox\n');
fprintf('auf eine Konfiguration ausweicht, in der sie nicht bindet.\n');

% ---------- Abbildungen ----------
if opt.figures
    rates = D(1).CFG.rates;
    for ri = 1:numel(rates)
        localFigPrice(D, ri, figDir, opt.save);
        localFigLevel(D, ri, figDir, opt.save);
        localFigScaling(D, ri, figDir, opt.save);
        localFigVsAnalog(D, A, ri, figDir, opt.save);
    end
end

% ---------- Tabelle ----------
if opt.save
    out.table = localTable(D);
    writetable(out.table, fullfile(figDir, 'summary.csv'));
    save(fullfile(figDir, 'summary.mat'), '-struct', 'out');
    fprintf('\nAbbildungen und summary.csv in %s\n', figDir);
end
end

% =====================================================================
function localRequire(T, name, fields)
%LOCALREQUIRE  Fehlende Felder benennen, statt zehn Zeilen tiefer an einem
%   Indexfehler zu scheitern. Dateien von vor AP7/E9 tragen nicht alles.
fehlt = fields(~isfield(T, fields));
if ~isempty(fehlt)
    error('analyze_dbf_dac:oldFormat', ...
        ['%s fehlen die Felder %s. Die Datei stammt aus einem Lauf vor E9/AP7 -- ' ...
         'run_dbf_dac_distance neu starten (sie wird dann ohnehin neu gerechnet, ' ...
         'weil localDone sie verwirft). ACHTUNG bei dacScaleStandard: in jenen '  ...
         'Dateien bedeutet E die antennenweise Aussteuerung, nicht die '  ...
         'gemeinsame.'], name, strjoin(fehlt, ', '));
end
end

function [e, Mb, Nb, idx] = localEnvelope(E)
%LOCALENVELOPE  Minimum ueber (M, N) je (Distanz, Rate), mit dem Index.
%   E ist [nD nR nM nN]; eine fuenfte Dimension ist vorher zu mindern.
[nD, nR, nM, nN] = size(E);
e = nan(nD, nR); Mb = e; Nb = e; idx = nan(nD, nR);
for di = 1:nD
    for ri = 1:nR
        c = reshape(E(di, ri, :, :), [nM nN]);
        [m, k] = min(c(:));
        if isnan(m), continue; end
        [mi, ni] = ind2sub([nM nN], k);
        e(di, ri) = m; Mb(di, ri) = mi; Nb(di, ri) = ni;
        idx(di, ri) = sub2ind([nD nR nM nN], di, ri, mi, ni);
    end
end
end

function v = localAt(X, idx)
%LOCALAT  Dieselbe Zelle aus einem zweiten Feld lesen.
v = nan(size(idx));
ok = isfinite(idx);
v(ok) = X(idx(ok));
end

function T = localTable(D)
%LOCALTABLE  Eine Zeile je (Kanal, LO, Modell, Rate, Distanz).
c = {}; 
for i = 1:numel(D)
    [nD, nR] = size(D(i).q);
    for di = 1:nD
        for ri = 1:nR
            % M und N nur, wo die Zelle ueberhaupt erreichbar war. Mbest
            % ist dort NaN, und CFG.Ms(NaN) waere ein Indexfehler -- nicht
            % hypothetisch: am oberen Distanzende ist reichlich NaN.
            mi = D(i).Mbest(di,ri); ni = D(i).Nbest(di,ri);
            Mv = NaN; Nv = NaN;
            if isfinite(mi), Mv = D(i).CFG.Ms(mi); end
            if isfinite(ni), Nv = D(i).CFG.Ns(ni); end
            c(end+1, :) = {char(D(i).channel), char(D(i).lo), char(D(i).model), ...
                D(i).CFG.rates(ri), D(i).CFG.distances(di), ...
                D(i).Eideal(di,ri), D(i).Ebest(di,ri), D(i).q(di,ri), ...
                D(i).kBest(di,ri), D(i).dacShare(di,ri), D(i).perGain(di,ri), ...
                Mv, Nv}; %#ok<AGROW>
        end
    end
end
T = cell2table(c, 'VariableNames', {'kanal','lo','dacModell','rate_bps','distance_m', ...
    'Ebit_ideal','Ebit_endlich','q','stufe','dacAnteil','perAntenneGegenGemeinsam','M','N'});
end

function localFigPrice(D, ri, figDir, doSave)
%LOCALFIGPRICE  q ueber der Distanz, eine Spalte je DAC-Modell.
mods = unique([D.model]);
f = figure('Visible', 'off', 'Position', [100 100 420*numel(mods) 380]);
for mi = 1:numel(mods)
    subplot(1, numel(mods), mi); hold on; grid on
    sel = find([D.model] == mods(mi));
    for k = sel
        semilogx(D(k).CFG.distances, D(k).q(:, ri), '-o', 'LineWidth', 1.2, ...
            'MarkerSize', 3, 'DisplayName', sprintf('%s / %s', D(k).channel, D(k).lo));
    end
    yline(1, 'k--', 'idealer DAC', 'HandleVisibility', 'off');
    set(gca, 'XScale', 'log'); xlabel('Distanz [m]');
    if mi == 1, ylabel('q = E_{bit}(endlich) / E_{bit}(ideal)'); end
    title(sprintf('DAC-Modell %s', mods(mi)), 'Interpreter', 'none');
    legend('Location', 'best', 'Interpreter', 'none');
end
sgtitle(sprintf('Preis der endlichen DAC-Aufloesung, R = %g bit/s', D(1).CFG.rates(ri)));
localSave(f, figDir, sprintf('dac_price_R%g.png', D(1).CFG.rates(ri)), doSave);
end

function localFigLevel(D, ri, figDir, doSave)
%LOCALFIGLEVEL  Welche DAC-Stufe das Gearbox waehlt.
mods = unique([D.model]);
f = figure('Visible', 'off', 'Position', [100 100 420*numel(mods) 380]);
for mi = 1:numel(mods)
    subplot(1, numel(mods), mi); hold on; grid on
    sel = find([D.model] == mods(mi));
    for k = sel
        lv = D(k).kBest(:, ri);
        ok = isfinite(lv);
        bits = nan(size(lv)); bits(ok) = D(k).levels(lv(ok));
        stairs(D(k).CFG.distances, bits, 'LineWidth', 1.2, ...
            'DisplayName', sprintf('%s / %s', D(k).channel, D(k).lo));
    end
    set(gca, 'XScale', 'log'); xlabel('Distanz [m]'); ylim([-0.3 3.3]);
    if mi == 1, ylabel('gewaehlte Stufe [Bit ueber 1/2 log_2 M]'); end
    title(sprintf('DAC-Modell %s', mods(mi)), 'Interpreter', 'none');
    legend('Location', 'best', 'Interpreter', 'none');
end
sgtitle(sprintf('Gewaehlte DAC-Aufloesung, R = %g bit/s', D(1).CFG.rates(ri)));
localSave(f, figDir, sprintf('dac_level_R%g.png', D(1).CFG.rates(ri)), doSave);
end

function localFigScaling(D, ri, figDir, doSave)
%LOCALFIGSCALING  Was die antennenweise Aussteuerung wert WAERE (E9).
f = figure('Visible', 'off', 'Position', [100 100 560 380]);
hold on; grid on
for k = 1:numel(D)
    if all(~isfinite(D(k).perGain(:, ri))), continue; end
    semilogx(D(k).CFG.distances, D(k).perGain(:, ri), '-', 'LineWidth', 1.2, ...
        'DisplayName', sprintf('%s / %s / %s', D(k).channel, D(k).lo, D(k).model));
end
yline(1, 'k--', 'gleich teuer', 'HandleVisibility', 'off');
set(gca, 'XScale', 'log'); xlabel('Distanz [m]');
ylabel('E_{bit}(je Antenne) / E_{bit}(gemeinsam)');
title(sprintf(['Antennenweise gegen gemeinsame Aussteuerung, R = %g bit/s\n' ...
    '< 1: antennenweise waere billiger -- bezahlt wird sie im Modell nicht'], ...
    D(1).CFG.rates(ri)));
legend('Location', 'best', 'Interpreter', 'none');
localSave(f, figDir, sprintf('dac_scaling_R%g.png', D(1).CFG.rates(ri)), doSave);
end

function localFigVsAnalog(D, A, ri, figDir, doSave)
%LOCALFIGVSANALOG  Digital mit endlichem DAC gegen die analogen Varianten.
mods = unique([D.model]);
f = figure('Visible', 'off', 'Position', [100 100 420*numel(mods) 380]);
for mi = 1:numel(mods)
    subplot(1, numel(mods), mi); hold on; grid on
    for k = find([D.model] == mods(mi))
        loglog(D(k).CFG.distances, D(k).Ebest(:, ri), '-', 'LineWidth', 1.4, ...
            'DisplayName', sprintf('digital %s/%s', D(k).channel, D(k).lo));
    end
    for k = find([A.model] == mods(mi))
        loglog(A(k).CFG.distances, A(k).Ebest(:, ri), '--', 'LineWidth', 1.0, ...
            'DisplayName', sprintf('analog %s', A(k).variant));
    end
    set(gca, 'XScale', 'log', 'YScale', 'log'); xlabel('Distanz [m]');
    if mi == 1, ylabel('E_{bit} [J/bit]'); end
    title(sprintf('DAC-Modell %s', mods(mi)), 'Interpreter', 'none');
    legend('Location', 'best', 'Interpreter', 'none', 'FontSize', 7);
end
sgtitle(sprintf('Digital mit endlichem DAC gegen analog, R = %g bit/s', D(1).CFG.rates(ri)));
localSave(f, figDir, sprintf('dac_vs_analog_R%g.png', D(1).CFG.rates(ri)), doSave);
end

function localSave(f, figDir, name, doSave)
if doSave
    exportgraphics(f, fullfile(figDir, name), 'Resolution', 150);
end
close(f);
end
