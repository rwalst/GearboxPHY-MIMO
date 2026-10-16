function out = analyze_analog_bf_mixed(opt)
%ANALYZE_ANALOG_BF_MIXED  Auswertung der Mischformen: lohnt es, nur EINE
%   Seite analog zu bauen -- und welche?
%
%   out = analyze_analog_bf_mixed();
%   out = analyze_analog_bf_mixed(figures=false, save=false);
%
%   Liest results/abfmix_distance_<variante>_<lo>.mat aus
%   run_analog_bf_mixed_distance und daneben die REINEN Architekturen aus
%   run_analog_bf_distance (results/abf_distance_*_envelope.mat). Dass das
%   geht, ist kein Zufall: beide Treiber rechnen auf demselben Raster
%   (2 Raten, 25 Distanzen, M = 4..256, N = 1..16, 28 GHz), und der Kopf von
%   run_analog_bf_mixed_distance nennt die Referenzen ausdruecklich.
%
%   DIE FRAGE IST NICHT "wie teuer ist die Mischform", sondern ob sie BEIDE
%   reinen Formen schlaegt. Eine Mischform, die nur besser als die digitale
%   ist, ist keine Empfehlung -- dann baut man ganz analog. Deshalb ist das
%   Mass
%
%       q = E_bit(beste Mischform) / min(E_bit(rein digital), E_bit(rein analog))
%
%   jeweils als Huellkurve ueber (M, N). q < 1 heisst: die Mischform ist
%   guenstiger als alles Reine, und nur dann ist sie eine Aussage.
%
%   JE LO-FALL GETRENNT, und das ist wesentlich: der LO-Aufschlag trifft nur
%   die DIGITALE Seite (N Mischer), die analoge hat einen. Mit geteiltem LO
%   ist digital kuenstlich billig; erst mit 12.5 mW je zusaetzlichem Mischer
%   steht der Vergleich auf realistischen Beinen. Die reine analoge Referenz
%   ist in beiden Faellen dieselbe Datei -- sie hat nichts zu verteilen.
%
%   WELCHE SEITE ANALOG: der zweite Befund. txA_rxD gegen txD_rxA, beide als
%   Huellkurve ueber ihre Phasenschieber-Varianten. Das ist die eigentliche
%   Entwurfsfrage, denn die beiden Seiten kosten Verschiedenes -- der Sender
%   zahlt PA und DAC je Kette, der Empfaenger LNA und ADC.
%
%   VIER ABBILDUNGEN je Rate, in results/abfmix_figures/:
%     mix_ebit_R<rate>.png    E_bit ueber der Distanz, Mischformen und
%                             reine Formen, je LO-Fall eine Spalte
%     mix_vs_pure_R<rate>.png q ueber der Distanz -- die Hauptaussage
%     mix_side_R<rate>.png    welche Seite analog sein sollte
%     mix_shares_R<rate>.png  Phasenschieber- und ADC-Anteil der besten
%                             Mischform: woran es liegt
%   dazu summary.csv.
arguments
    opt.figures (1,1) logical = true
    opt.save (1,1) logical = true
end

resDir = gearboxphy.paths.resultsDir('');
fm = dir(fullfile(resDir, 'abfmix_distance_*.mat'));
assert(~isempty(fm), 'analyze_analog_bf_mixed:noResults', ...
    ['Keine abfmix_distance_*.mat in %s -- erst run_analog_bf_mixed_distance. ' ...
     'Die Studie war bis zuletzt nicht gelaufen (docs/MIMO_TODO.md 3.4).'], resDir);
figDir = gearboxphy.paths.resultsDir('abfmix_figures');
if opt.save && ~isfolder(figDir), mkdir(figDir); end

% ---------- Mischformen ----------
M = struct('variant', {}, 'lo', {}, 'side', {}, 'CFG', {}, 'E', {}, ...
           'psShare', {}, 'adcShare', {});
for i = 1:numel(fm)
    T = load(fullfile(fm(i).folder, fm(i).name));
    [e, ~, ~, idx] = localEnvelope(T.E);
    M(end+1) = struct('variant', string(T.variant), 'lo', string(T.loTag), ...
        'side', localSide(string(T.variant)), 'CFG', T.CFG, 'E', e, ...
        'psShare', localAt(T.Eps, idx) ./ e, ...
        'adcShare', localAt(T.Eadc, idx) ./ e); %#ok<AGROW>
end

% ---------- reine Architekturen als Referenz ----------
% Der LO-Fall gehoert zur DIGITALEN Referenz: dbf_ideal und
% dbf_ideal_lo12p5mW. ACHTUNG, seit der Migration auf die neuen
% Hardwaremodelle sind die beiden dieselbe Konfiguration -- die Vorgabe ist
% loDistributionModel "per_mixer" mit 12,5 mW bei 28 GHz, und dbf_ideal
% uebergibt nichts, bekommt also genau das. Die analoge Referenz ist beiden
% gemein.
%
% DAS ADC-MODELL IM DATEINAMEN KOMMT AUS DEN DATEN, nicht aus einer
% Konstante. Hier stand '_envelope.mat' fest verdrahtet; seit
% run_analog_bf_distance nur noch "quantile5" rechnet (Nutzerentscheidung
% 2026-10-15), fand das keine einzige Referenz mehr und die Auswertung brach
% mit noReferences ab -- ein umgestellter Erzeuger und ein nicht
% mitgezogener Verbraucher. Der eigene Lauf schreibt sein adcModel mit, und
% genau das muss die Referenz tragen: verglichen werden darf nur innerhalb
% EINES ADC-Modells.
adcTag = string(load(fullfile(fm(1).folder, fm(1).name), 'adcModel').adcModel);
P = struct('name', {}, 'kind', {}, 'E', {}, 'CFG', {});
for nm = ["dbf_ideal" "dbf_ideal_lo12p5mW" "abf_active" "abf_passive_comp" "abf_passive_pen"]
    p = fullfile(resDir, sprintf('abf_distance_%s_%s.mat', nm, adcTag));
    if ~isfile(p)
        warning('analyze_analog_bf_mixed:noReference', ...
            ['%s fehlt -- die reine %s-Referenz fehlt damit im Vergleich. ' ...
             'Erst run_analog_bf_distance.'], p, nm);
        continue
    end
    T = load(p, 'E', 'CFG');
    % RASTER PRUEFEN, NICHT ANNEHMEN. Der Kopf von
    % run_analog_bf_mixed_distance sagt zu, dass beide Treiber auf
    % demselben Raster rechnen -- aber eine Zusage im Kommentar ist keine
    % Pruefung. Weicht es ab, bricht sonst spaeter eine Division mit
    % "Arrays have incompatible sizes" ab (so passiert), oder, schlimmer:
    % die Groessen passen zufaellig und die Verhaeltnisse vergleichen
    % verschiedene Distanzen.
    localSameGrid(M(1).CFG, T.CFG, nm);
    kind = "analog"; if startsWith(nm, "dbf"), kind = "digital"; end
    P(end+1) = struct('name', nm, 'kind', kind, 'E', localEnvelope(T.E), 'CFG', T.CFG); %#ok<AGROW>
end
assert(~isempty(P), 'analyze_analog_bf_mixed:noReferences', ...
    ['Keine einzige reine Referenz gefunden. Ohne sie ist die Frage dieser ' ...
     'Studie nicht beantwortbar -- sie lautet nicht "wie teuer", sondern ' ...
     '"besser als rein?".']);

out.mixed = M; out.pure = P;
los = unique([M.lo]);

% ---------- Befund je LO-Fall ----------
fprintf('\n=== Mischform gegen die reinen Architekturen ===\n');
fprintf('q = E_bit(beste Mischform) / min(rein digital, rein analog), Huellkurve ueber (M,N)\n\n');
fprintf('%-10s %-8s %-10s %-12s %s\n', 'LO-Fall', 'Rate', 'min q', 'bei d [m]', 'Fenster mit q < 1');
Q = struct('lo', {}, 'q', {}, 'qDig', {}, 'qAna', {}, 'CFG', {});
for lo = los
    [q, qd, qa, CFG] = localQ(M, P, lo);
    Q(end+1) = struct('lo', lo, 'q', q, 'qDig', qd, 'qAna', qa, 'CFG', CFG); %#ok<AGROW>
    for ri = 1:numel(CFG.rates)
        [mn, di] = min(q(:, ri));
        win = CFG.distances(q(:, ri) < 1 - 1e-12);
        if isempty(win)
            w = 'keines -- rein ist immer mindestens so guenstig';
        else
            w = sprintf('%.0f .. %.0f m (%d von %d Punkten)', min(win), max(win), ...
                numel(win), numel(CFG.distances));
        end
        fprintf('%-10s %-8.0e %-10.4f %-12.0f %s\n', lo, CFG.rates(ri), mn, ...
            CFG.distances(di), w);
    end
end
out.q = Q;

% ---------- welche Seite analog ----------
fprintf('\n=== Welche Seite analog? r = E_bit(Sender analog) / E_bit(Empfaenger analog) ===\n');
fprintf('%-10s %-8s %-10s %s\n', 'LO-Fall', 'Rate', 'Median r', 'Deutung');
for lo = los
    [r, CFG] = localSideRatio(M, lo);
    % Mit einem VARIANTS-Filter (Vorablauf) kann eine der beiden Seiten
    % fehlen -- dann ist r leer, und r(:,ri) waere ein Indexfehler.
    if isempty(r)
        fprintf('%-10s %-8s %-10s %s\n', lo, '-', '-', ...
            'nur eine Seite vorhanden, kein Vergleich moeglich');
        continue
    end
    for ri = 1:numel(CFG.rates)
        med = median(r(isfinite(r(:, ri)), ri));
        if isnan(med), d = 'keine Aussage (eine Seite fehlt)';
        elseif med < 1, d = 'Sender analog ist guenstiger';
        else,           d = 'Empfaenger analog ist guenstiger';
        end
        fprintf('%-10s %-8.0e %-10.4f %s\n', lo, CFG.rates(ri), med, d);
    end
end

% ---------- Abbildungen ----------
if opt.figures
    CFG = M(1).CFG;
    for ri = 1:numel(CFG.rates)
        localFigEbit(M, P, los, ri, figDir, opt.save);
        localFigVsPure(Q, ri, figDir, opt.save);
        localFigSide(M, los, ri, figDir, opt.save);
        localFigShares(M, los, ri, figDir, opt.save);
    end
end

if opt.save
    out.table = localTable(Q);
    writetable(out.table, fullfile(figDir, 'summary.csv'));
    save(fullfile(figDir, 'summary.mat'), '-struct', 'out');
    fprintf('\nAbbildungen und summary.csv in %s\n', figDir);
end
end

% =====================================================================
function localSameGrid(a, b, name)
%LOCALSAMEGRID  Distanzen und Raten muessen uebereinstimmen, sonst ist jedes
%   Verhaeltnis sinnlos.
for fld = ["distances" "rates"]
    x = a.(fld); y = b.(fld);
    if ~isequal(size(x), size(y)) || max(abs(x(:) - y(:))) > 1e-9 * max(1, max(abs(x(:))))
        error('analyze_analog_bf_mixed:gridMismatch', ...
            ['Das %s-Raster von %s passt nicht zu den Mischformen ' ...
             '(%d gegen %d Punkte%s). Beide Treiber muessen auf demselben ' ...
             'Raster rechnen -- run_analog_bf_distance und ' ...
             'run_analog_bf_mixed_distance teilen den CONFIG-Block absichtlich. ' ...
             'Den aelteren der beiden Laeufe wiederholen.'], ...
            fld, name, numel(y), numel(x), ...
            repmat(", Werte auch verschieden", 1, isequal(size(x), size(y))));
    end
end
end

function s = localSide(name)
%LOCALSIDE  Welche Seite ist analog -- steht im Variantennamen.
if contains(name, "txA_rxD"),     s = "txAnalog";
elseif contains(name, "txD_rxA"), s = "rxAnalog";
else,                             s = "unbekannt";
end
end

function [q, qDig, qAna, CFG] = localQ(M, P, lo)
%LOCALQ  Beste Mischform gegen die beste reine Form, je (Distanz, Rate).
%   Die digitale Referenz haengt am LO-Fall, die analoge nicht.
sel = M([M.lo] == lo);
CFG = sel(1).CFG;
mix = localMin(cat(3, sel.E));
digName = "dbf_ideal"; if lo == "lo12p5mW", digName = "dbf_ideal_lo12p5mW"; end
dig = localPick(P, digName);
ana = localMin(cat(3, P([P.kind] == "analog").E));
qDig = mix ./ dig;
qAna = mix ./ ana;
q = mix ./ min(dig, ana);
end

function [r, CFG] = localSideRatio(M, lo)
%LOCALSIDERATIO  Sender analog gegen Empfaenger analog, je Seite die beste
%   Phasenschieber-Variante.
sel = M([M.lo] == lo);
CFG = sel(1).CFG;
tx = localMin(cat(3, sel([sel.side] == "txAnalog").E));
rx = localMin(cat(3, sel([sel.side] == "rxAnalog").E));
% FEHLT EINE SEITE, gibt es nichts zu teilen -- und tx ./ rx mit einem
% leeren Operanden ist ein Fehler, kein leeres Ergebnis. Erreichbar ueber
% den VARIANTS-Filter eines Vorablaufs; genau so aufgefallen.
if isempty(tx) || isempty(rx)
    r = [];  return
end
r = tx ./ rx;
end

function e = localMin(stack)
%LOCALMIN  Minimum ueber die dritte Dimension, NaN-tolerant.
if isempty(stack), e = []; return; end
e = min(stack, [], 3, 'omitnan');
e(all(isnan(stack), 3)) = NaN;
end

function E = localPick(P, name)
k = find([P.name] == name, 1);
if isempty(k)
    error('analyze_analog_bf_mixed:missingReference', ...
        ['Die Referenz %s fehlt. Sie gehoert zum LO-Fall und ist nicht ' ...
         'ersetzbar: mit geteiltem LO ist digital kuenstlich billig.'], name);
end
E = P(k).E;
end

function [e, Mb, Nb, idx] = localEnvelope(E)
%LOCALENVELOPE  Minimum ueber (M, N) je (Distanz, Rate), mit dem Index.
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
v = nan(size(idx));
ok = isfinite(idx);
v(ok) = X(idx(ok));
end

function T = localTable(Q)
c = {};
for i = 1:numel(Q)
    q = Q(i).q; CFG = Q(i).CFG;
    for di = 1:size(q, 1)
        for ri = 1:size(q, 2)
            c(end+1, :) = {char(Q(i).lo), CFG.rates(ri), CFG.distances(di), ...
                q(di, ri), Q(i).qDig(di, ri), Q(i).qAna(di, ri)}; %#ok<AGROW>
        end
    end
end
T = cell2table(c, 'VariableNames', {'lo','rate_bps','distance_m', ...
    'q_gegen_bestes_rein','q_gegen_digital','q_gegen_analog'});
end

function localFigEbit(M, P, los, ri, figDir, doSave)
f = figure('Visible', 'off', 'Position', [100 100 440*numel(los) 400]);
for li = 1:numel(los)
    subplot(1, numel(los), li); hold on; grid on
    sel = M([M.lo] == los(li));
    for k = 1:numel(sel)
        loglog(sel(k).CFG.distances, sel(k).E(:, ri), '-', 'LineWidth', 1.2, ...
            'DisplayName', char(sel(k).variant));
    end
    digName = "dbf_ideal"; if los(li) == "lo12p5mW", digName = "dbf_ideal_lo12p5mW"; end
    for k = 1:numel(P)
        if P(k).kind == "digital" && P(k).name ~= digName, continue; end
        st = '--'; if P(k).kind == "analog", st = ':'; end
        loglog(P(k).CFG.distances, P(k).E(:, ri), st, 'LineWidth', 1.4, 'Color', [0.3 0.3 0.3], ...
            'DisplayName', sprintf('rein %s: %s', P(k).kind, P(k).name));
    end
    set(gca, 'XScale', 'log', 'YScale', 'log'); xlabel('Distanz [m]');
    if li == 1, ylabel('E_{bit} [J/bit]'); end
    title(sprintf('LO-Fall %s', los(li)), 'Interpreter', 'none');
    legend('Location', 'best', 'Interpreter', 'none', 'FontSize', 7);
end
sgtitle(sprintf('Mischformen und reine Architekturen, R = %g bit/s', M(1).CFG.rates(ri)));
localSave(f, figDir, sprintf('mix_ebit_R%g.png', M(1).CFG.rates(ri)), doSave);
end

function localFigVsPure(Q, ri, figDir, doSave)
f = figure('Visible', 'off', 'Position', [100 100 600 400]); hold on; grid on
for i = 1:numel(Q)
    semilogx(Q(i).CFG.distances, Q(i).q(:, ri), '-o', 'LineWidth', 1.4, 'MarkerSize', 3, ...
        'DisplayName', sprintf('%s: gegen das beste Reine', Q(i).lo));
    semilogx(Q(i).CFG.distances, Q(i).qDig(:, ri), '--', 'LineWidth', 0.9, ...
        'DisplayName', sprintf('%s: gegen rein digital', Q(i).lo));
    semilogx(Q(i).CFG.distances, Q(i).qAna(:, ri), ':', 'LineWidth', 0.9, ...
        'DisplayName', sprintf('%s: gegen rein analog', Q(i).lo));
end
yline(1, 'k-', 'q = 1', 'HandleVisibility', 'off');
set(gca, 'XScale', 'log'); xlabel('Distanz [m]'); ylabel('q');
title(sprintf(['Lohnt die Mischform? R = %g bit/s\n' ...
    'q < 1 nur gegen das BESTE Reine ist die Aussage'], Q(1).CFG.rates(ri)));
legend('Location', 'best', 'Interpreter', 'none', 'FontSize', 7);
localSave(f, figDir, sprintf('mix_vs_pure_R%g.png', Q(1).CFG.rates(ri)), doSave);
end

function localFigSide(M, los, ri, figDir, doSave)
f = figure('Visible', 'off', 'Position', [100 100 600 400]); hold on; grid on
for li = 1:numel(los)
    [r, CFG] = localSideRatio(M, los(li));
    if isempty(r), continue; end
    semilogx(CFG.distances, r(:, ri), '-o', 'LineWidth', 1.3, 'MarkerSize', 3, ...
        'DisplayName', char(los(li)));
end
yline(1, 'k--', 'gleich', 'HandleVisibility', 'off');
set(gca, 'XScale', 'log'); xlabel('Distanz [m]');
ylabel('E_{bit}(Sender analog) / E_{bit}(Empfaenger analog)');
title(sprintf(['Welche Seite sollte analog sein? R = %g bit/s\n' ...
    '< 1: der Sender'], M(1).CFG.rates(ri)));
legend('Location', 'best', 'Interpreter', 'none');
localSave(f, figDir, sprintf('mix_side_R%g.png', M(1).CFG.rates(ri)), doSave);
end

function localFigShares(M, los, ri, figDir, doSave)
f = figure('Visible', 'off', 'Position', [100 100 440*numel(los) 400]);
for li = 1:numel(los)
    subplot(1, numel(los), li); hold on; grid on
    sel = M([M.lo] == los(li));
    for k = 1:numel(sel)
        semilogx(sel(k).CFG.distances, 100*sel(k).psShare(:, ri), '-', 'LineWidth', 1.1, ...
            'DisplayName', sprintf('%s, Phasenschieber', sel(k).variant));
        semilogx(sel(k).CFG.distances, 100*sel(k).adcShare(:, ri), ':', 'LineWidth', 1.1, ...
            'DisplayName', sprintf('%s, ADC', sel(k).variant));
    end
    set(gca, 'XScale', 'log'); xlabel('Distanz [m]');
    if li == 1, ylabel('Anteil an E_{bit} [%]'); end
    title(sprintf('LO-Fall %s', los(li)), 'Interpreter', 'none');
    legend('Location', 'best', 'Interpreter', 'none', 'FontSize', 6);
end
sgtitle(sprintf('Woran es liegt: Phasenschieber- und ADC-Anteil, R = %g bit/s', ...
    M(1).CFG.rates(ri)));
localSave(f, figDir, sprintf('mix_shares_R%g.png', M(1).CFG.rates(ri)), doSave);
end

function localSave(f, figDir, name, doSave)
if doSave
    exportgraphics(f, fullfile(figDir, name), 'Resolution', 150);
end
close(f);
end
