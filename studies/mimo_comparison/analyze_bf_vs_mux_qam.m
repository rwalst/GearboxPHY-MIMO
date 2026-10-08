function out = analyze_bf_vs_mux_qam(opt)
%ANALYZE_BF_VS_MUX_QAM  Beamforming gegen Multiplexing, QAM, ueber KANAL,
%   ADC-REGEL und DISTANZ in einer Auswertung.
%
%   out = analyze_bf_vs_mux_qam();
%   out = analyze_bf_vs_mux_qam(figures=false, save=false);
%
%   Fasst zusammen, was die Einzelabbildungen getrennt zeigen
%   (analyze_mimo_comparison = Rate, analyze_adc_rule = ADC-Regel,
%   analyze_rice_comparison = Kanal) und stellt die EINE Frage, die daraus
%   folgt: wann ist Beamforming guenstiger als Multiplexing, und wovon
%   haengt die Antwort ab.
%
%   DATENQUELLEN, beide bereits gerechnet:
%     results/cmp_distance_<variante>.mat   (Schritt 3b) -- E, Etx, Erx,
%        Epa, Eadc je (Distanz x Rate x M x N). 25 Distanzen 10 m..10 km,
%        Raten 1e6 und 1e9, M in {4,16,64,256}. Das ist die Hauptquelle:
%        alle 11 Varianten tragen dasselbe Raster, sind also direkt
%        vergleichbar (geprueft, siehe localLoad).
%     results/cmp_<variante>_d<d>/qam_M<M>_fc28GHz.mat  (Schritt 3a) --
%        100 Ratenpunkte bei 50/500/5000 m, aber nur fuer K = 0.
%
%   DAS MASS ist das Verhaeltnis q = E_bit(BF) / E_bit(MUX), jeweils als
%   HUELLKURVE ueber (M, N): jeder Modus darf seine beste Konfiguration
%   waehlen, denn genau das tut das Gearbox. q < 1 heisst BF guenstiger.
%
%   ZWEI STRUKTURELLE VORBEHALTE, die die Funktion selbst markiert und die
%   man ohne sie falsch liest:
%
%   1. "trivial" -- waehlen BEIDE Modi N = 1, sind sie dasselbe System und
%      q = 1 ist keine Aussage ueber BF gegen MUX. Das betrifft bei
%      R = 1e6 alle Distanzen unter rund 1 km.
%   2. "randbegrenzt" -- waehlt ein Modus das GROESSTE verfuegbare N, ist
%      sein Optimum vom Raster abgeschnitten und q eine untere Schranke an
%      den Unterschied. Bei N <= 4 (Rice-Varianten) trifft das ab rund
%      300 m beide Modi, das Ergebnis dort sagt also mehr ueber das Raster
%      als ueber die Physik.
%
%   KANALACHSE: K = 0 (Rayleigh), 3, 30 und der Rang-1-Grenzfall. Fuer BF
%   ist der Grenzfall NICHT ein Rice-Lauf mit K = inf, sondern das
%   idealisierte BF (AWGN plus Gewinn N_t*N_r, runQamSweepBfIdeal) -- es
%   trifft lambda_max = N_t*N_r exakt, was bei K -> inf gilt. Die Spalte
%   ist deshalb als Grenzfall gekennzeichnet, nicht als Rice-Punkt.
%
%   ADC-ACHSE: fixedB und scaledB. alphabetB fehlt noch, weil es nur fuer
%   MUX gerechnet ist (bei BF kommt EIN Strom an, das beobachtete Alphabet
%   ist M unabhaengig von N_t, alphabetB ist dort also identisch zu
%   fixedB) und der Export dafuer noch nicht gelaufen ist.
arguments
    opt.figures (1,1) logical = true
    opt.save (1,1) logical = true
    opt.fcGHz (1,1) double = 28
    opt.Ms (1,:) double = [4 16 64 256]     % M=1024 nur SISO, s. Kopf
    opt.dTab (1,:) double = [10 100 316 1000 3162 10000]  % Tabellenspalten
    opt.Ns3a (1,:) double = [1 2 4 8 16]    % kanonische N-Liste der 3a-Wuerfel
    opt.capN (1,1) double = Inf             % alle Varianten auf N <= capN deckeln
end

% WOZU capN: die Kanalachse ist nur vergleichbar, wenn alle Kanaele auf
% DEMSELBEN N-Raster stehen. Heute reichen K = 0 und Rang 1 bis N = 16, die
% Rice-Laeufe nur bis 4 -- die Reihe der Schnittdistanzen ueber den Kanal
% mischt also zwei Rasterweiten und ist kein Kanaltrend. Mit capN = 4
% rechnet die Funktion alles gleich und liefert die lesbare Reihe; ohne
% capN nutzt jede Variante, was sie hat. Beide Sichten gehoeren in eine
% Darstellung, und zwar beschriftet.

resDir = gearboxphy.paths.resultsDir('');
figDir = fullfile(resDir, 'cmp_figures');
if opt.save && ~isfolder(figDir), mkdir(figDir); end

% ---- Variantentabelle: Kanal x Modus x Regel ---------------------------
% 'bfLimit' markiert die Spalte, in der BF nicht Rice, sondern das
% idealisierte Modell ist (siehe Kopf).
V = struct('chan',{}, 'rule',{}, 'mux',{}, 'bf',{}, 'bfLimit',{});
V(end+1) = struct('chan',"K=0",    'rule',"fixedB",  'mux',"mux_fixedB",       'bf',"bf_fixedB",        'bfLimit',false);
V(end+1) = struct('chan',"K=0",    'rule',"scaledB", 'mux',"mux_scaledB",      'bf',"bf_scaledB",       'bfLimit',false);
V(end+1) = struct('chan',"K=0",    'rule',"alphabetB",'mux',"mux_alphabetB",    'bf',"bf_fixedB",        'bfLimit',false);
% alphabetB GEGEN bf_fixedB, und das ist kein Fluechtigkeitsfehler: bei
% Beamforming kommt EIN Strom an, das beobachtete Alphabet ist M
% unabhaengig von N_t, und adcBitsRule(M,Nt,Nr,"alphabetB") faellt dort mit
% fixedB zusammen. Ein eigener BF-alphabetB-Lauf existiert deshalb nicht --
% er waere bitgleich. Siehe runQamSweepAlphabet1.m "NUR MULTIPLEXING".
V(end+1) = struct('chan',"K=3",    'rule',"scaledB", 'mux',"mux_scaledB_K3",   'bf',"bf_scaledB_K3",    'bfLimit',false);
V(end+1) = struct('chan',"K=30",   'rule',"scaledB", 'mux',"mux_scaledB_K30",  'bf',"bf_scaledB_K30",   'bfLimit',false);
V(end+1) = struct('chan',"Rang 1", 'rule',"scaledB", 'mux',"mux_scaledB_KInf", 'bf',"bfideal_scaledB",  'bfLimit',true);
% RANG 1 GIBT ES NUR FUER scaledB. Ein fixedB-Rang-1-Lauf auf der
% MUX-Seite existiert nicht (runQamSweepMuxRank1 rechnet scaledB), und
% mux_fixedB gegen bfideal_fixedB zu stellen waere KEIN Kanalvergleich:
% links Rayleigh, rechts AWGN. Die Zeile stand hier zunaechst und fiel
% genau daran auf -- bei N = 1 muessen beide Modi IDENTISCH sein, sie gab
% aber 0.998. Fuer scaledB stimmt die Probe (q = 1.000 bei N = 1), weil
% dort beide Seiten denselben Grenzfall meinen: H = 1 deterministisch.

% ---- laden und auf das gemeinsame Raster pruefen -----------------------
[D, ref] = localLoadAll(V, resDir, opt.Ms, opt.capN);
d = ref.distances; rates = ref.rates; Ns = ref.Ns; Ms = ref.Ms;

fprintf('\n');
fprintf('================================================================\n');
fprintf(' BF gegen MUX, QAM: Kanal x ADC-Regel x Distanz\n');
fprintf('================================================================\n');
fprintf(' Raster: %d Distanzen %g..%g m | Raten %s | M %s | N %s\n', ...
    numel(d), min(d), max(d), mat2str(rates), mat2str(Ms), mat2str(Ns));
fprintf(' Mass: q = E_bit(BF)/E_bit(MUX), Huellkurve ueber (M,N). q<1: BF guenstiger.\n');
fprintf(' Marken: [=] beide N=1 (dasselbe System, q trivial 1)\n');
fprintf('         [R] ein Modus am groessten N (randbegrenzt, q ist Schranke)\n\n');

% ---- Haupttabelle: q ueber Distanz, je Kanal/Regel/Rate ---------------
iTab = localNearest(d, opt.dTab);
for ri = 1:numel(rates)
    fprintf('---- R_eff = %.0e bit/s --------------------------------------\n', rates(ri));
    fprintf('%-10s %-9s', 'Kanal', 'ADC');
    fprintf('%12s', compose("%gm", d(iTab))); fprintf('\n');
    for k = 1:numel(D)
        q = D(k).q(:, ri); fl = D(k).flag(:, ri);
        fprintf('%-10s %-9s', D(k).chan, D(k).rule);
        for i = iTab
            if ~isfinite(q(i)), fprintf('%12s', '-');
            else, fprintf('%10.3f%-2s', q(i), fl(i)); end
        end
        fprintf('\n');
    end
    fprintf('\n');
end

% ---- Schnittdistanz: wo kippt q durch 1 -------------------------------
fprintf('---- Schnittdistanz d* (q = 1), nur ueber NICHT-triviale Punkte -\n');
fprintf('%-10s %-9s %14s %14s\n', 'Kanal', 'ADC', 'R=1e6', 'R=1e9');
for k = 1:numel(D)
    fprintf('%-10s %-9s', D(k).chan, D(k).rule);
    for ri = 1:numel(rates)
        ds = localCross(d, D(k).q(:,ri), D(k).flag(:,ri));
        if isnan(ds), fprintf('%14s', 'keine');
        else,         fprintf('%14.0f', ds); end
    end
    fprintf('\n');
end

% ---- Woher kommt der Unterschied: Energieanteile ----------------------
fprintf('\n---- Aufschluesselung am jeweiligen Optimum, R = 1e9 ----------\n');
fprintf('   Anteile am E_bit in %% (Tx, Rx, PA, ADC), MUX | BF\n');
riHi = numel(rates);
for k = 1:numel(D)
    fprintf('%-10s %-9s\n', D(k).chan, D(k).rule);
    for i = localNearest(d, [100 1000 10000])
        a = D(k).shareMux(i,:,riHi); b = D(k).shareBf(i,:,riHi);
        if all(isnan(a)) || all(isnan(b)), continue; end
        fprintf('   d=%5.0fm  MUX %4.0f %4.0f %4.0f %4.0f  |  BF %4.0f %4.0f %4.0f %4.0f', ...
                d(i), a*100, b*100);
        fprintf('   (M,N): (%g,%g) | (%g,%g)\n', ...
                D(k).Mmux(i,riHi), D(k).Nmux(i,riHi), D(k).Mbf(i,riHi), D(k).Nbf(i,riHi));
    end
end

% ---- Rate als Achse, aus 3a (nur K = 0) -------------------------------
A = localRateAxis(resDir, opt);
if ~isempty(A)
    fprintf('\n---- Ratenachse aus 3a (nur K=0): q bei festen Distanzen ------\n');
    fprintf('%-9s %-7s', 'ADC', 'd [m]');
    fprintf('%11s', compose("%.0e", A(1).Rshow)); fprintf('\n');
    for k = 1:numel(A)
        fprintf('%-9s %-7g', A(k).rule, A(k).distance);
        for j = 1:numel(A(k).qShow)
            if isfinite(A(k).qShow(j)), fprintf('%11.3f', A(k).qShow(j));
            else, fprintf('%11s', '-'); end
        end
        fprintf('\n');
    end
end

out = struct('grid', ref, 'cells', D, 'rateAxis', A, 'variants', V);

if opt.figures
    localFigures(D, A, d, rates, figDir, opt);
end
if opt.save
    f = fullfile(resDir, 'cmp_figures', 'bf_vs_mux_qam_summary.mat');
    save(f, 'out');
    fprintf('\nZusammenfassung: %s\n', f);
end
end

% =======================================================================
function [D, ref] = localLoadAll(V, resDir, Msel, capN)
%LOCALLOADALL  3b-Dateien laden, Huellkurven und Marken bilden.
%   Prueft, dass alle Varianten auf DEMSELBEN Raster liegen -- ohne das
%   waere jedes Verhaeltnis zwischen zwei Varianten bedeutungslos.
D = struct('chan',{}, 'rule',{}, 'q',{}, 'flag',{}, 'Mmux',{}, 'Nmux',{}, ...
           'Mbf',{}, 'Nbf',{}, 'shareMux',{}, 'shareBf',{}, 'bfLimit',{});
ref = [];
for k = 1:numel(V)
    [Em, Cm, Sm] = localOne(resDir, V(k).mux);
    [Eb, Cb, Sb] = localOne(resDir, V(k).bf);
    if isempty(Em) || isempty(Eb)
        warning('bfmux:missing', '%s / %s (%s, %s) fehlt - Zeile uebersprungen.', ...
                V(k).mux, V(k).bf, V(k).chan, V(k).rule);
        continue
    end
    if isempty(ref)
        ref = struct('distances',Cm.distances(:).', 'rates',Cm.rates(:).', ...
                     'Ms',Cm.Ms(:).', 'Ns',Cm.Ns(:).');
    end
    localSameGrid(Cm, ref, V(k).mux); localSameGrid(Cb, ref, V(k).bf);

    % Nur die gewaehlten M behalten (M=1024 ist SISO-only, s. Kopf)
    keepM = ismember(double(Cm.Ms(:).'), Msel);
    % GEMEINSAME N-MENGE. Seit 3b je Variante so weit rechnet, wie ihre
    % Kurven reichen, koennen die beiden Seiten eines Paares verschiedene
    % Ns tragen (z.B. mux_scaledB_KInf noch 1..4, bfideal_scaledB schon
    % 1..16). Verglichen wird dann ueber den Schnitt -- alles andere waere
    % entweder ein Formfehler oder ein unfairer Vergleich.
    NsM = double(Cm.Ns(:).'); NsB = double(Cb.Ns(:).');
    NsK = intersect(NsM, NsB, 'stable');
    NsK = NsK(NsK <= capN);                 % s. Kopf
    assert(~isempty(NsK), 'analyze_bf_vs_mux_qam:noCommonN', ...
        '%s und %s haben keine gemeinsame Antennenzahl.', V(k).mux, V(k).bf);
    [~, iM] = ismember(NsK, NsM); [~, iB] = ismember(NsK, NsB);
    Em = Em(:,:,keepM,iM); Eb = Eb(:,:,keepM,iB);
    for f = ["tx","rx","pa","adc"]
        Sm.(f) = Sm.(f)(:,:,keepM,iM); Sb.(f) = Sb.(f)(:,:,keepM,iB);
    end
    MsK = double(Cm.Ms(keepM));

    % SYMMETRISCHE MASKE, und hier sitzt die Fairness des Vergleichs:
    % fehlt eine (M,N)-Kombination auf EINER Seite, wird sie auf BEIDEN
    % verworfen. Sonst gewinnt der Modus mit der vollstaendigeren
    % Kurvenmenge allein durch die groessere Auswahl -- genau die
    % Asymmetrie, gegen die die Studie aufgebaut ist. Betrifft real:
    % mux_fixedB fehlt M=256 bei 8x8/16x16, mux_alphabetB fehlt alles mit
    % B > 20, die Rice-Varianten rechnen nur N <= 4.
    both = isfinite(Em) & isfinite(Eb);
    Em(~both) = NaN; Eb(~both) = NaN;
    [em, Mm, Nm, im] = localEnv(Em, MsK, NsK);
    [eb, Mb, Nb, ib] = localEnv(Eb, MsK, NsK);
    q = eb ./ em;

    nd = size(Em,1); nr = size(Em,2);
    flag = repmat("  ", nd, nr);
    flag(Nm == 1 & Nb == 1) = "=";                       % dasselbe System
    atEdge = (Nm == max(NsK)) | (Nb == max(NsK));   % max der GEMEINSAMEN Menge
    flag(atEdge & flag ~= "=") = "R";                    % randbegrenzt

    D(end+1) = struct('chan',V(k).chan, 'rule',V(k).rule, 'q',q, 'flag',flag, ...
        'Mmux',Mm, 'Nmux',Nm, 'Mbf',Mb, 'Nbf',Nb, ...
        'shareMux',localShares(Sm, im), 'shareBf',localShares(Sb, ib), ...
        'bfLimit',V(k).bfLimit); %#ok<AGROW>
end
assert(~isempty(D), 'analyze_bf_vs_mux_qam:noData', ...
    'Keine einzige Variante vollstaendig - erst Schritt 3b ausfuehren.');
end

function [E, C, S] = localOne(resDir, name)
f = fullfile(resDir, sprintf('cmp_distance_%s.mat', name));
if ~isfile(f), E = []; C = []; S = []; return; end
T = load(f);
E = T.E; C = T.CFG;
S = struct('tx',T.Etx, 'rx',T.Erx, 'pa',T.Epa, 'adc',T.Eadc);
end

function localSameGrid(C, ref, name)
%LOCALSAMEGRID  Distanzen, Raten und Ms MUESSEN gleich sein -- sonst
%   vergleicht man Aepfel mit Birnen. Ns darf abweichen: der 3b-Treiber
%   rechnet je Variante so weit, wie ihre Kurven reichen, und die
%   symmetrische Maske in localLoadAll sorgt fuer die Fairness.
assert(isequal(C.distances(:).', ref.distances) && isequal(C.rates(:).', ref.rates) ...
    && isequal(double(C.Ms(:).'), double(ref.Ms)), ...
    'analyze_bf_vs_mux_qam:grid', ...
    ['%s liegt auf einem anderen Distanz-/Raten-/M-Raster als die erste ' ...
     'Variante. Ein Verhaeltnis zwischen beiden waere bedeutungslos -- 3b ' ...
     'fuer beide mit derselben CFG neu rechnen.'], name);
end

function [e, Mopt, Nopt, idx] = localEnv(E, Ms, Ns)
%LOCALENV  Huellkurve min ueber (M,N) plus die gewaehlte Konfiguration.
[nd, nr, nM, nN] = size(E);
e = nan(nd,nr); Mopt = nan(nd,nr); Nopt = nan(nd,nr); idx = nan(nd,nr);
for i = 1:nd
    for r = 1:nr
        A = reshape(E(i,r,:,:), nM, nN);
        if ~any(isfinite(A(:))), continue; end
        [e(i,r), li] = min(A(:));
        [mi, ni] = ind2sub([nM nN], li);
        Mopt(i,r) = Ms(mi); Nopt(i,r) = Ns(ni); idx(i,r) = li;
    end
end
end

function sh = localShares(S, idx)
%LOCALSHARES  Anteile Tx/Rx/PA/ADC am E_bit, am jeweiligen Optimum.
[nd, nr] = size(idx);
sh = nan(nd, 4, nr);
fn = ["tx","rx","pa","adc"];
for i = 1:nd
    for r = 1:nr
        if ~isfinite(idx(i,r)), continue; end
        v = zeros(1,4);
        for j = 1:4
            A = S.(fn(j)); A = reshape(A(i,r,:,:), 1, []);
            v(j) = A(idx(i,r));
        end
        tot = sum(v);
        if tot > 0, sh(i,:,r) = v / tot; end
    end
end
end

function i = localNearest(d, targets)
i = arrayfun(@(t) find(abs(d - t) == min(abs(d - t)), 1), targets);
end

function ds = localCross(d, q, flag)
%LOCALCROSS  Distanz, an der q durch 1 geht -- triviale Punkte (beide N=1)
%   werden ausgelassen, dort ist q == 1 keine Aussage.
ok = isfinite(q) & flag ~= "=";
dd = d(ok); qq = q(ok);
if numel(qq) < 2, ds = NaN; return; end
s = sign(log(qq));
k = find(s(1:end-1) > 0 & s(2:end) <= 0, 1);     % von MUX-besser zu BF-besser
if isempty(k), ds = NaN; return; end
ds = interp1(log(qq(k:k+1)), log(dd(k:k+1)), 0);
ds = exp(ds);
end

function A = localRateAxis(resDir, opt)
%LOCALRATEAXIS  3a: q ueber der Rate, bei 50/500/5000 m. Nur K = 0, weil
%   nur dafuer 3a gerechnet ist.
A = struct('rule',{}, 'distance',{}, 'R',{}, 'q',{}, 'Rshow',{}, 'qShow',{});
Rshow = [1e4 1e6 1e8 1e10];
for rule = ["fixedB","scaledB"]
    for dd = [50 500 5000]
        cm = localCube3a(resDir, sprintf('mux_%s_d%d', rule, dd), opt);
        cb = localCube3a(resDir, sprintf('bf_%s_d%d', rule, dd), opt);
        if isempty(cm) || isempty(cb), continue; end
        % SYMMETRISCHE MASKE wie im 3b-Teil: fehlt eine (M,N)-Kombination
        % auf einer Seite, wird sie auf beiden verworfen.
        Am = cm.E; Ab = cb.E;
        both = isfinite(Am) & isfinite(Ab);
        Am(~both) = NaN; Ab(~both) = NaN;
        R = cm.R;
        q = squeeze(min(min(Ab,[],3),[],2)).' ./ squeeze(min(min(Am,[],3),[],2)).';
        qs = nan(1, numel(Rshow));
        for j = 1:numel(Rshow)
            [~, i] = min(abs(R - Rshow(j)));
            if abs(log10(R(i)/Rshow(j))) < 0.1, qs(j) = q(i); end
        end
        A(end+1) = struct('rule',rule, 'distance',dd, 'R',R, 'q',q, ...
                          'Rshow',Rshow, 'qShow',qs); %#ok<AGROW>
    end
end
end

function o = localCube3a(resDir, folder, opt)
%LOCALCUBE3A  3a-Ordner als Wuerfel E(nR x nM x nN) statt als Huellkurve.
%   E_per_bit in den Gear-Dateien ist SCHON das Minimum ueber die
%   Antennenkonfigurationen -- damit laesst sich nicht mehr symmetrisch
%   maskieren, und ein Modus mit vollstaendigerer Kurvenmenge gewinnt
%   allein durch die groessere Auswahl. Deshalb E_per_bit_all zusammen mit
%   antennaConfigsUsed, aufgespannt auf eine kanonische N-Liste.
rd = fullfile(resDir, sprintf('cmp_%s', folder));
o = [];
if ~isfolder(rd), return; end
R = []; cube = []; Ns = [];
for mi = 1:numel(opt.Ms)
    f = fullfile(rd, sprintf('qam_M%d_fc%gGHz.mat', opt.Ms(mi), opt.fcGHz));
    if ~isfile(f), continue; end
    T = load(f);
    if isempty(R)
        R = T.RVec(:).';
        Ns = opt.Ns3a;
        cube = nan(numel(R), numel(opt.Ms), numel(Ns));
    end
    cfg = T.antennaConfigsUsed;
    if iscell(cfg) && isscalar(cfg) && iscell(cfg{1}), cfg = cfg{1}; end
    Eall = T.E_per_bit_all;
    for ci = 1:numel(cfg)
        c = cfg{ci};
        if isstruct(c), nt = c.N_t; else, nt = c(1); end
        ni = find(Ns == nt, 1);
        if isempty(ni) || ci > size(Eall,2), continue; end
        cube(:, mi, ni) = Eall(:, ci);
    end
end
if ~isempty(cube), o = struct('R',R, 'E',cube, 'Ns',Ns); end
end

function localFigures(D, A, d, rates, figDir, opt)
%LOCALFIGURES  Zwei Abbildungen: q ueber Distanz (je Rate) und q ueber Rate.
C = lines(numel(D));
fig = figure('Position',[100 100 1100 420], 'Color','w');
for ri = 1:numel(rates)
    ax = subplot(1, numel(rates), ri); hold(ax,'on'); grid(ax,'on');
    for k = 1:numel(D)
        q = D(k).q(:,ri); fl = D(k).flag(:,ri);
        show = isfinite(q) & fl ~= "=";       % triviale Punkte weglassen
        plot(ax, d(show), q(show), '-o', 'Color', C(k,:), 'MarkerSize',3, ...
             'DisplayName', sprintf('%s, %s', D(k).chan, D(k).rule));
    end
    yline(ax, 1, 'k--', 'HandleVisibility','off');
    set(ax, 'XScale','log', 'YScale','log');
    xlabel(ax, 'Distanz [m]'); ylabel(ax, 'E_{bit}(BF) / E_{bit}(MUX)');
    title(ax, sprintf('R_{eff} = %.0e bit/s', rates(ri)));
    if ri == 1, legend(ax, 'Location','southwest', 'FontSize',8); end
end
sgtitle(fig, 'BF gegen MUX: Kanal und ADC-Regel ueber der Distanz');
if opt.save
    exportgraphics(fig, fullfile(figDir, 'bf_vs_mux_qam_distance.png'), 'Resolution',150);
end

if ~isempty(A)
    fig2 = figure('Position',[100 100 900 380], 'Color','w');
    ax = axes(fig2); hold(ax,'on'); grid(ax,'on');
    st = ["-","--"];
    for k = 1:numel(A)
        ls = st(1 + (A(k).rule == "scaledB"));
        plot(ax, A(k).R, A(k).q, ls, 'DisplayName', ...
             sprintf('%s, d=%g m', A(k).rule, A(k).distance));
    end
    yline(ax, 1, 'k--', 'HandleVisibility','off');
    set(ax, 'XScale','log', 'YScale','log');
    xlabel(ax, 'R_{eff} [bit/s]'); ylabel(ax, 'E_{bit}(BF) / E_{bit}(MUX)');
    title(ax, 'BF gegen MUX ueber der Rate (K = 0, aus Schritt 3a)');
    legend(ax, 'Location','best', 'FontSize',8);
    if opt.save
        exportgraphics(fig2, fullfile(figDir, 'bf_vs_mux_qam_rate.png'), 'Resolution',150);
    end
end
end
