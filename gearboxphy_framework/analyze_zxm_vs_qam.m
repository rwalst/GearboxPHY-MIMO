function out = analyze_zxm_vs_qam(opts)
%ANALYZE_ZXM_VS_QAM  Lohnt es sich, EINE QAM-Verbindung durch n PARALLELE
%   ZXM-Verbindungen zu ersetzen?
%
%   out = analyze_zxm_vs_qam(Name, Wert, ...)
%
%   Beispiele:
%       analyze_zxm_vs_qam();                                  % Defaults
%       analyze_zxm_vs_qam(fcGHz=8, nList=[1 2 4]);
%       analyze_zxm_vs_qam(baseAntenna="best");                % fairer Basisfall
%
%   VERGLEICHSLOGIK: dieselbe Gesamtrate R wird entweder von EINER
%   QAM-Verbindung getragen oder von n parallelen ZXM-Verbindungen mit je
%   R/n. Energie PRO BIT ist bereits normiert, deshalb gilt fuer die Kette
%       n * P(R/n) / R = n * E_bit(R/n)*(R/n) / R = E_bit(R/n),
%   also KEIN zusaetzlicher Faktor n -- verglichen wird schlicht
%   E_bit_QAM(R) gegen E_bit_ZXM(R/n).
%
%   ANNAHME: die n Verbindungen sind unabhaengige Hardware und stoeren
%   sich nicht gegenseitig. Das ist die fuer ZXM OPTIMISTISCHE Lesart;
%   Interferenz zwischen den n Verbindungen ist nicht modelliert.
%
%   baseAntenna steuert, wie hart der Basisfall ist:
%     "1x1"  QAM ohne Beamforming (Default) -- guenstig fuer ZXM, weil ZXM
%            seine Antennen nutzen darf und QAM nicht.
%     "best" QAM darf ebenfalls seine beste Antennenkonfiguration waehlen.
%            Das ist der faire Vergleich; nimm ihn, bevor du aus dem
%            Ergebnis ein Argument machst.
arguments
    opts.resultsDir (1,1) string = "results_beamforming_d50"
    opts.fcGHz (1,1) double = 28
    opts.nList (1,:) double = [1 2 4 8 16 32]
    opts.baseOrder (1,1) double = 256
    opts.baseAntenna (1,1) string {mustBeMember(opts.baseAntenna,["1x1","best"])} = "1x1"
    opts.verbose (1,1) logical = true
    opts.plot (1,1) logical = true
    opts.outFile (1,1) string = ""
end

rd = opts.resultsDir;
if opts.outFile == ""
    opts.outFile = fullfile(rd,'figures', ...
        sprintf('zxm_vs_qam%d_fc%gGHz_%s.png', opts.baseOrder, opts.fcGHz, opts.baseAntenna));
end

% ---- Basis: QAM ------------------------------------------------------
bf = fullfile(rd, sprintf('qam_M%d_fc%gGHz.mat', opts.baseOrder, opts.fcGHz));
assert(isfile(bf), 'Basisdatei fehlt: %s', bf);
B = load(bf);
R = B.RVec(:);
if opts.baseAntenna == "1x1"
    i11 = find(cellfun(@(c) c.N_t==1 && c.N_r==1, B.antennaConfigsUsed), 1);
    assert(~isempty(i11), 'keine 1x1-Spalte in %s', bf);
    Eq = B.E_per_bit_all(:, i11);
    baseTag = sprintf('QAM M=%d, 1x1', opts.baseOrder);
else
    Eall = B.E_per_bit_all; Eall(~isfinite(Eall)) = inf;
    Eq = min(Eall, [], 2);
    baseTag = sprintf('QAM M=%d, best antenna cfg', opts.baseOrder);
end
Eq(~isfinite(Eq)) = NaN;

% ---- ZXM: bestes (M_Tx, Antennenkonfiguration) je Rate ----------------
zf = dir(fullfile(rd, sprintf('zxm_M*_fc%gGHz.mat', opts.fcGHz)));
assert(~isempty(zf), 'keine ZXM-Dateien fuer %g GHz in %s', opts.fcGHz, rd);
Ez = []; tag = strings(1,0);
for i = 1:numel(zf)
    S = load(fullfile(rd, zf(i).name));
    ordv = str2double(regexp(zf(i).name,'_M(\d+)_','tokens','once'));
    for j = 1:numel(S.antennaConfigsUsed)
        e = S.E_per_bit_all(:,j); e(~isfinite(e)) = inf;
        Ez(:,end+1) = e; %#ok<AGROW>
        tag(end+1) = sprintf('M_{Tx}=%d %dx%d', ordv, ...
            S.antennaConfigsUsed{j}.N_t, S.antennaConfigsUsed{j}.N_r); %#ok<AGROW>
    end
end
[EzBest, iz] = min(Ez, [], 2);
EzBest(~isfinite(EzBest)) = NaN;

% ---- Vergleich je n ---------------------------------------------------
lR = log10(R); lE = log10(EzBest); ok = isfinite(lE);
nN = numel(opts.nList);
out = struct('R',R,'Eqam',Eq,'EzxmBest',EzBest,'winnerTag',{tag(iz)}, ...
             'n',opts.nList,'baseTag',baseTag,'opts',opts);
out.Ezxm_at = nan(numel(R), nN);
out.anyWin = false(1,nN); out.maxGain = nan(1,nN);
out.Rlo = nan(1,nN); out.Rhi = nan(1,nN); out.RatMaxGain = nan(1,nN);

for k = 1:nN
    Ez_at = 10.^interp1(lR(ok), lE(ok), log10(R/opts.nList(k)), 'linear', NaN);
    out.Ezxm_at(:,k) = Ez_at;
    sel = isfinite(Ez_at) & isfinite(Eq) & (Ez_at < Eq);
    out.anyWin(k) = any(sel);
    if any(sel)
        g = Eq(sel)./Ez_at(sel);
        [out.maxGain(k), im] = max(g);
        Rs = R(sel);
        out.Rlo(k) = min(Rs); out.Rhi(k) = max(Rs); out.RatMaxGain(k) = Rs(im);
    end
end

if opts.verbose
    fprintf('\n=== %s, f_c = %g GHz ===\n', rd, opts.fcGHz);
    fprintf('Basis     : %s\n', baseTag);
    fprintf('Vergleich : n parallele ZXM-Verbindungen mit je R/n\n\n');
    fprintf('%-5s %-6s %-26s %-14s %-12s\n','n','QAM>','Ratenbereich [bit/s]','max Vorteil','bei R');
    for k = 1:nN
        if out.anyWin(k)
            fprintf('%-5d %-6s %-26s %-14s %-12.3g\n', opts.nList(k), 'ja', ...
                sprintf('%.3g .. %.3g', out.Rlo(k), out.Rhi(k)), ...
                sprintf('%.2fx', out.maxGain(k)), out.RatMaxGain(k));
        else
            fprintf('%-5d %-6s %-26s %-14s %-12s\n', opts.nList(k), 'nein','-','-','-');
        end
    end
end

if opts.plot
    localPlot(out);
end
end

% -----------------------------------------------------------------------
function localPlot(out)
R = out.R; nL = out.n;
C = lines(max(numel(nL),3));
INK=[0.043 0.043 0.043]; INK2=[0.322 0.318 0.306];
fig = figure('Position',[100 100 1000 620],'Color','w');
ax = axes(fig); hold(ax,'on'); grid(ax,'on'); box(ax,'off');
set(ax,'XScale','log','YScale','log','FontSize',12, ...
    'XColor',INK2,'YColor',INK2,'GridAlpha',0.12);
h = plot(ax, R, out.Eqam, 'k-', 'LineWidth',2.8, 'DisplayName',[out.baseTag ' (baseline)']);
for k = 1:numel(nL)
    h(end+1) = plot(ax, R, out.Ezxm_at(:,k), '-', 'Color',C(k,:), 'LineWidth',1.9, ...
        'DisplayName',sprintf('%d x ZXM @ R/%d', nL(k), nL(k))); %#ok<AGROW>
end
xlabel(ax,'aggregate rate R [bit/s]','FontSize',13,'Color',INK2);
ylabel(ax,'E_{bit} [J/bit]','FontSize',13,'Color',INK2);
title(ax, sprintf('%s vs. n parallel ZXM links, f_c = %g GHz', out.baseTag, out.opts.fcGHz), ...
    'FontSize',13.5,'Color',INK,'FontWeight','bold');
legend(ax,h,'Location','southwest','Box','off','FontSize',10.5,'TextColor',INK2);
exportgraphics(fig,out.opts.outFile,'Resolution',200);
fprintf('geschrieben: %s\n', out.opts.outFile);
end
