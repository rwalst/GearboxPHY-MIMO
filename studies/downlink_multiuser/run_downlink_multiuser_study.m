%RUN_DOWNLINK_MULTIUSER_STUDY  Downlink-Studie: ein Sender, 1 Nutzer mit
%   Rate x gegen n Nutzer mit je x/n.
%
%   Einfach ausfuehren:  run_downlink_multiuser_study
%
%   Die Knoepfe stehen alle im Block CONFIG. Das eigentliche Modell und
%   seine Annahmen sind in analyze_downlink_multiuser.m dokumentiert -
%   vor allem, warum E_rx bei x/n ausgewertet wird und was txModel
%   bedeutet. Fuer jede Kombination aus Traeger und Sendemodell entstehen
%   eine Konsolentabelle und eine Abbildung; alles Numerische landet
%   zusaetzlich in einer .mat.

clear; clc;
here = fileparts(mfilename('fullpath'));
cd(here);

%% ===================== CONFIG =====================================
CFG.resultsDir  = gearboxphy.paths.resultsDir("beamforming_d50");  % auch: beamforming_d5000
CFG.fcGHzList   = [8 28];                     % Traeger, die in resultsDir liegen
CFG.nList       = [1 2 4 8 16 32];            % Anzahl Nutzer
CFG.baseGear    = "QAM";                      % Fall A: Gear
CFG.baseOrder   = 256;                        % Fall A: Ordnung
CFG.baseAntenna = "1x1";                      % "1x1" | "best"
CFG.userGear    = "ZXM";                      % Fall B: z.B. "ZXM" oder ["ZXM" "QAM"]
CFG.userAntenna = "best";                     % "1x1" | "best"
CFG.txModels    = ["shared" "perUser"];       % Senderkosten: einmal / n-fach
CFG.outMat      = "downlink_multiuser_study.mat";
%% ===================================================================

assert(isfolder(CFG.resultsDir), 'Ergebnisordner fehlt: %s', CFG.resultsDir);
figDir = fullfile(CFG.resultsDir, 'figures');
if ~isfolder(figDir), mkdir(figDir); end

res = struct('fcGHz',{},'txModel',{},'out',{});
for fc = CFG.fcGHzList
    for tm = CFG.txModels
        fprintf('\n#################### f_c = %g GHz, txModel = %s ####################\n', fc, tm);
        o = analyze_downlink_multiuser( ...
            resultsDir  = CFG.resultsDir, ...
            fcGHz       = fc, ...
            nList       = CFG.nList, ...
            baseGear    = CFG.baseGear, ...
            baseOrder   = CFG.baseOrder, ...
            baseAntenna = CFG.baseAntenna, ...
            userGear    = CFG.userGear, ...
            userAntenna = CFG.userAntenna, ...
            txModel     = tm, ...
            verbose     = true, ...
            plot        = true);
        res(end+1) = struct('fcGHz',fc,'txModel',tm,'out',o); %#ok<SAGROW>
    end
end

outMat = fullfile(CFG.resultsDir, CFG.outMat);
save(outMat, 'res', 'CFG');
fprintf('\nalles gespeichert: %s\n', outMat);

%% ---- Kurzfassung ---------------------------------------------------
fprintf('\n==================== ZUSAMMENFASSUNG ====================\n');
fprintf('%-8s %-9s %-4s %-12s %-26s %s\n','f_c','txModel','n','max Gewinn','x-Bereich [bit/s]','beste Konfig');
for i = 1:numel(res)
    o = res(i).out;
    for k = 1:numel(o.n)
        if o.anyWin(k)
            fprintf('%-8s %-9s %-4d %-12s %-26s %s\n', ...
                sprintf('%g GHz',res(i).fcGHz), res(i).txModel, o.n(k), ...
                sprintf('%.2fx',o.maxGain(k)), ...
                sprintf('%.3g .. %.3g',o.xLo(k),o.xHi(k)), o.tagAtMax(k));
        else
            fprintf('%-8s %-9s %-4d %-12s %-26s %s\n', ...
                sprintf('%g GHz',res(i).fcGHz), res(i).txModel, o.n(k), ...
                'nie guenstiger','-','-');
        end
    end
end
