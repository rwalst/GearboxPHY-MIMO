function out = analyze_rank1_geometry(opts)
%ANALYZE_RANK1_GEOMETRY  Drei Architekturen im Rang-1-Kanal auf EINER Achse:
%   Multiplexing, digitales BF, analoges BF -- Option A (alle broadside) und
%   Option B (alle ueber dieselben 32 Richtungen). README.md in diesem Ordner.
%
%   out = analyze_rank1_geometry();
%   out = analyze_rank1_geometry(files=F, figures=false);   % F: Struct wie unten
%
%   Reine Nachbearbeitung, Sekunden, darf am Arbeitsplatz laufen.
%   Vorher: run_rank1_geometry_distance.
%
%   EINGANG (results/):
%     A  MUX     cmp_distance_mux_scaledB_KInf.mat
%        digital dbfdac_distance_r1b_lo12p5mW_survey.mat       (Ebest)
%     B  MUX     cmp_distance_mux_scaledB_r1ang.mat             (N <= 4)
%        digital dbfdac_distance_losd_lo12p5mW_survey.mat      (Ebest)
%     beide, analog  abfdac_distance_abfKInf_<ps>_survey.mat, ps = active,
%                    passive_comp, passive_pen. Gewinn N^2 bei jedem Winkel,
%                    also fuer A und B dieselbe Kurve.
%
%   MASS: E_bit [J/bit], je (Distanz, Rate) das Minimum ueber (M, N) -- wie
%   alle Auswertungen der Studie. DIE MASKE IST GEMEINSAM: eine
%   (M, N)-Zelle zaehlt nur, wenn sie bei ALLEN fuenf Eingaengen (MUX,
%   digital, drei analoge Varianten) endlich ist. Sonst gewaenne die
%   Architektur mit der vollstaendigeren Kurvenmenge allein durch die
%   groessere Auswahl. Fuer B heisst das N <= 4 auf ALLEN Seiten.
%
%   DREI SCHNITTE:
%     A      broadside, volles N-Raster
%     A4     broadside, N <= 4 -- das Gegenstueck zu B
%     B      32 Richtungen, N <= 4
%   A4 gegen B isoliert den Winkel: gleiche Hardware, gleiches Raster,
%   nur die Geometrie wechselt. A gegen A4 zeigt, was die Deckelung N <= 4
%   allein ausmacht.
%
%   VERHAELTNISSE (q < 1: Zaehler guenstiger):
%     qDig  = E(digital) / E(MUX)
%     qAna  = E(analog_ps) / E(digital), je Phasenschiebertyp
%   Dazu je (Distanz, Rate) der Gewinner unter {MUX, digital, analog_ps}
%   und die Schnittdistanzen d* aller Paare (log-linear interpoliert, JEDER
%   Vorzeichenwechsel, nicht nur der letzte). Am Rand des N-Rasters steht
%   ein [R]: dort ist das Verhaeltnis eine Schranke, nicht der Wert.
%
%   AUSGABE: results/rank1_geometry/summary.csv, summary.mat, und je Rate
%   eine Abbildung rank1_geometry_<rate>.png (wenn figures = true).
arguments
    opts.files struct = struct()
    opts.figures (1,1) logical = true
    opts.save (1,1) logical = true
    opts.outDir (1,1) string = "rank1_geometry"
end

F = localDefaultFiles();
for f = fieldnames(opts.files).'
    assert(isfield(F, f{1}), 'analyze_rank1_geometry:files', 'Unbekannter Eingang "%s".', f{1});
    F.(f{1}) = opts.files.(f{1});
end
PS = ["active" "passive_comp" "passive_pen"];

% ---- Laden, laut melden, was fehlt ------------------------------------
names = string(struct2cell(F)).';
fehlt = names(~arrayfun(@(n) isfile(gearboxphy.paths.resultsDir(n)), names));
if ~isempty(fehlt)
    error('analyze_rank1_geometry:missing', ...
        'Es fehlen in results/: %s. Erst run_rank1_geometry_distance.', strjoin(fehlt, ', '));
end
L = @(n) load(gearboxphy.paths.resultsDir(n));
S.muxA = L(F.muxA); S.muxB = L(F.muxB);
S.digA = L(F.digA); S.digB = L(F.digB);
for p = PS, S.("ana_" + p) = L(F.("ana_" + p)); end

% ---- Raster pruefen: Distanzen, Raten, M muessen gleich sein -----------
C0 = S.muxA.CFG;
for k = string(fieldnames(S)).'
    C = S.(k).CFG;
    assert(isequal(C.distances(:), C0.distances(:)) && isequal(C.rates(:), C0.rates(:)) ...
        && isequal(C.Ms(:), C0.Ms(:)) && C.fcGHz == C0.fcGHz, ...
        'analyze_rank1_geometry:grid', '%s liegt auf einem anderen Raster als %s.', k, F.muxA);
end
for k = ["digA" "digB"]
    assert(isfield(S.(k), 'dacScaleStandard') && string(S.(k).dacScaleStandard) == "common", ...
        'analyze_rank1_geometry:dacScale', ...
        ['%s ist nicht im Format nach E9 (gemeinsame Aussteuerung als Standard). ' ...
         'Ebest bedeutete dort etwas anderes -- run_dbf_dac_distance neu laufen lassen.'], k);
end

dist = C0.distances(:).'; rates = C0.rates(:).'; Ms = double(C0.Ms(:).');
cuts = struct('name', {"A", "A4", "B"}, ...
              'mux',  {"muxA", "muxA", "muxB"}, ...
              'dig',  {"digA", "digA", "digB"}, ...
              'capN', {Inf, 4, 4}, ...
              'label', {"Rang 1, broadside", "Rang 1, broadside, N <= 4", "Rang 1, 32 Richtungen, N <= 4"});

R = struct([]);
rows = {};
for c = cuts
    % gemeinsames N-Raster aller fuenf Eingaenge, gedeckelt
    Ns = double(S.(c.mux).CFG.Ns(:).');
    for k = [c.dig, "ana_" + PS]
        Ns = intersect(Ns, double(S.(k).CFG.Ns(:).'), 'stable');
    end
    Ns = Ns(Ns <= c.capN);
    E = struct();
    E.mux = localPick(S.(c.mux).E, S.(c.mux).CFG.Ns, Ns);
    E.dig = localPick(S.(c.dig).Ebest, S.(c.dig).CFG.Ns, Ns);
    for p = PS, E.(p) = localPick(S.("ana_" + p).E, S.("ana_" + p).CFG.Ns, Ns); end
    % GEMEINSAME MASKE ueber alle fuenf
    keys = string(fieldnames(E)).';
    ok = true(size(E.mux));
    for k = keys, ok = ok & isfinite(E.(k)); end
    env = struct(); Nsel = struct();
    for k = keys
        X = E.(k); X(~ok) = NaN;
        [env.(k), Nsel.(k)] = localEnv(X, Ns);
    end
    q = struct('dig', env.dig ./ env.mux);
    for p = PS, q.(p) = env.(p) ./ env.dig; end
    edge = struct();
    for k = keys, edge.(k) = Nsel.(k) == max(Ns); end

    fprintf('\n================ %s (N in %s) ================\n', c.label, mat2str(Ns));
    for ri = 1:numel(rates)
        fprintf('\nRate %.0e bit/s   q_dig = E_dig/E_mux,  q_<ps> = E_analog/E_dig   [R] = Rand N = %d\n', rates(ri), max(Ns));
        fprintf('%8s | %-12s | %-12s %-12s %-12s | Gewinner (active / passive_comp / passive_pen)\n', ...
            'd [m]', 'q_dig', 'q_active', 'q_pas_comp', 'q_pas_pen');
        for di = 1:numel(dist)
            % Gewinner; liegen mehrere innerhalb 0.5 % am Minimum, stehen
            % alle da ("MUX=digital") -- ein Vorsprung im Optimiererrauschen
            % ist keiner.
            w = strings(1, numel(PS));
            cand = ["MUX" "digital" "analog"];
            for pi_ = 1:numel(PS)
                v = [env.mux(di,ri), env.dig(di,ri), env.(PS(pi_))(di,ri)];
                if all(isnan(v)), w(pi_) = "-"; continue, end
                w(pi_) = strjoin(cand(v <= min(v) * 1.005), '=');
            end
            fprintf('%8.0f | %s | %s %s %s | %s\n', dist(di), ...
                localQ(q.dig(di,ri), edge.mux(di,ri) | edge.dig(di,ri)), ...
                localQ(q.active(di,ri), edge.active(di,ri) | edge.dig(di,ri)), ...
                localQ(q.passive_comp(di,ri), edge.passive_comp(di,ri) | edge.dig(di,ri)), ...
                localQ(q.passive_pen(di,ri), edge.passive_pen(di,ri) | edge.dig(di,ri)), ...
                strjoin(w, ' / '));
            rows(end+1, :) = {char(c.name), rates(ri), dist(di), env.mux(di,ri), env.dig(di,ri), ...
                env.active(di,ri), env.passive_comp(di,ri), env.passive_pen(di,ri), ...
                Nsel.mux(di,ri), Nsel.dig(di,ri), Nsel.active(di,ri), Nsel.passive_comp(di,ri), Nsel.passive_pen(di,ri), ...
                char(strjoin(w, '/'))}; %#ok<AGROW>
        end
        fprintf('   d* digital/MUX: %s\n', localCross(q.dig(:,ri), dist));
        for p = PS
            fprintf('   d* analog(%s)/digital: %s\n', p, localCross(q.(p)(:,ri), dist));
        end
    end
    R(end+1).name = c.name; R(end).label = c.label; R(end).Ns = Ns; %#ok<AGROW>
    R(end).env = env; R(end).Nsel = Nsel; R(end).q = q;
end

% ---- A4 gegen B: was der Winkel allein ausmacht -------------------------
iA4 = find([R.name] == "A4"); iB = find([R.name] == "B");
fprintf('\n================ Winkeleffekt: B / A4 (gleiches N-Raster) ================\n');
for ri = 1:numel(rates)
    fprintf('Rate %.0e:  E_mux B/A4 = %s\n', rates(ri), ...
        localRange(R(iB).env.mux(:,ri) ./ R(iA4).env.mux(:,ri)));
    fprintf('             E_dig B/A4 = %s\n', ...
        localRange(R(iB).env.dig(:,ri) ./ R(iA4).env.dig(:,ri)));
end

out = struct('cuts', R, 'files', F, 'distances', dist, 'rates', rates, 'Ms', Ms);
if opts.save
    od = gearboxphy.paths.resultsDir(opts.outDir);
    if ~isfolder(od), mkdir(od); end
    T = cell2table(rows, 'VariableNames', {'cut', 'rate', 'distance', 'E_mux', 'E_dig', ...
        'E_ana_active', 'E_ana_passive_comp', 'E_ana_passive_pen', ...
        'N_mux', 'N_dig', 'N_active', 'N_passive_comp', 'N_passive_pen', 'winner'});
    writetable(T, fullfile(od, 'summary.csv'));
    save(fullfile(od, 'summary.mat'), 'out');
    fprintf('\ngeschrieben: %s\n', od);
end
if opts.figures
    localFigures(R, dist, rates, gearboxphy.paths.resultsDir(opts.outDir), opts.save);
end
end

% ========================================================================
function F = localDefaultFiles()
F = struct( ...
    'muxA', "cmp_distance_mux_scaledB_KInf.mat", ...
    'digA', "dbfdac_distance_r1b_lo12p5mW_survey.mat", ...
    'muxB', "cmp_distance_mux_scaledB_r1ang.mat", ...
    'digB', "dbfdac_distance_losd_lo12p5mW_survey.mat", ...
    'ana_active', "abfdac_distance_abfKInf_active_survey.mat", ...
    'ana_passive_comp', "abfdac_distance_abfKInf_passive_comp_survey.mat", ...
    'ana_passive_pen', "abfdac_distance_abfKInf_passive_pen_survey.mat");
end

function X = localPick(E, NsFile, Ns)
%LOCALPICK  Die Spalten der gewuenschten N, in deren Reihenfolge.
[tf, idx] = ismember(Ns, double(NsFile(:).'));
assert(all(tf), 'analyze_rank1_geometry:Ns', 'N = %s fehlt im Eingang.', mat2str(Ns(~tf)));
X = E(:, :, :, idx);
end

function [e, Nsel] = localEnv(X, Ns)
%LOCALENV  Minimum ueber (M, N) je (Distanz, Rate) und das gewaehlte N.
[nD, nR, nM, nN] = size(X);
Y = reshape(X, nD, nR, nM*nN);
[e, i] = min(Y, [], 3, 'omitnan');
[~, ni] = ind2sub([nM nN], i);
Nsel = Ns(ni);
Nsel(isnan(e)) = NaN;
end

function s = localQ(q, atEdge)
if isnan(q), s = sprintf('%-12s', '   -'); return, end
t = sprintf('%7.3f', q);
if atEdge, t = [t ' [R]']; end
s = sprintf('%-12s', t);
end

function s = localCross(q, d)
%LOCALCROSS  Alle Vorzeichenwechsel von q - 1, log-linear interpoliert.
%   GLEICHSTAND (|q - 1| < TIE_TOL) ZAEHLT NICHT ALS SEITE. Waehlen beide
%   Architekturen N = 1, ist es dasselbe System, und q springt allein durch
%   das Optimiererrauschen um 1.000 herum (gemessen: 0.998..1.002). Ohne
%   das Band meldete die Auswertung dort Schnittdistanzen, die keine sind.
%   Ein Wechsel wird zwischen den letzten beiden Punkten AUSSERHALB des
%   Bandes mit verschiedenem Vorzeichen interpoliert.
TIE_TOL = 0.005;
q = q(:).'; d = d(:).';
sg = sign(q - 1); sg(abs(q - 1) < TIE_TOL | isnan(q)) = 0;
s = strings(1, 0); j = 0;
for i = 1:numel(q)
    if sg(i) == 0, continue, end
    if j > 0 && sg(i) ~= sg(j)
        x0 = log10(d(j)); x1 = log10(d(i));
        x = x0 + (1 - q(j)) * (x1 - x0) / (q(i) - q(j));
        if q(j) < 1, dir_ = 'Zaehler wird teurer'; else, dir_ = 'Zaehler wird guenstiger'; end
        s(end+1) = sprintf('%.0f m (%s)', 10^x, dir_); %#ok<AGROW>
    end
    j = i;
end
if isempty(s)
    v = sg(sg ~= 0);
    if all(isnan(q)), s = "keine Daten";
    elseif isempty(v), s = sprintf("kein Wechsel, ueberall Gleichstand (|q-1| < %.3f)", TIE_TOL);
    elseif all(v < 0), s = "kein Wechsel, Zaehler guenstiger oder gleich";
    else, s = "kein Wechsel, Nenner guenstiger oder gleich"; end
else
    s = strjoin(s, ', ');
end
end

function s = localRange(r)
r = r(~isnan(r));
if isempty(r), s = '-'; return, end
s = sprintf('%.3f .. %.3f (Median %.3f)', min(r), max(r), median(r));
end

function localFigures(R, dist, rates, od, doSave)
col = lines(5);                         % MATLAB-Standardfarben
for ri = 1:numel(rates)
    fh = figure('Visible', 'off', 'Position', [100 100 1200 420]);
    tl = tiledlayout(fh, 1, numel(R), 'TileSpacing', 'compact');
    for c = 1:numel(R)
        ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on');
        set(ax, 'XScale', 'log', 'YScale', 'log');
        e = R(c).env;
        plot(ax, dist, e.mux(:,ri), '-o', 'Color', col(1,:), 'DisplayName', 'MUX');
        plot(ax, dist, e.dig(:,ri), '-s', 'Color', col(2,:), 'DisplayName', 'digital BF');
        plot(ax, dist, e.active(:,ri), '--', 'Color', col(3,:), 'DisplayName', 'analog, active PS');
        plot(ax, dist, e.passive_comp(:,ri), '-.', 'Color', col(4,:), 'DisplayName', 'analog, passive (comp.)');
        plot(ax, dist, e.passive_pen(:,ri), ':', 'Color', col(5,:), 'DisplayName', 'analog, passive (penalty)');
        title(ax, R(c).label); xlabel(ax, 'distance [m]'); ylabel(ax, 'E_{bit} [J/bit]');
        if c == 1, legend(ax, 'Location', 'northwest'); end
    end
    title(tl, sprintf('Rank-1 channel, 28 GHz, %.0e bit/s', rates(ri)));
    if doSave
        exportgraphics(fh, fullfile(od, sprintf('rank1_geometry_%.0e.png', rates(ri))), 'Resolution', 150);
    end
    close(fh);
end
end
