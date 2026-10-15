function n = rebuildStore(opts)
%REBUILDSTORE  Den Ergebnisspeicher aus den vorhandenen Ergebnisdateien neu
%   aufbauen.
%
%   n = gearboxphy.data.rebuildStore()
%   n = gearboxphy.data.rebuildStore(dryRun=true)
%
%   WOZU: results/_store/ ist nicht versioniert (es ist eine Kopie, siehe
%   .gitignore). Nach einem frischen Clone -- etwa im Home des ZIH-Clusters
%   -- ist er also leer, und der erste Lauf rechnet alles neu, obwohl die
%   Ergebnisse daneben liegen. Das hier stellt ihn in Sekunden wieder her.
%
%   MOEGLICH IST DAS NUR, weil jede Ergebnisdatei ihren eigenen Schluessel
%   im Feld resultFingerprint traegt. Aus den Zahlen allein liesse er sich
%   nicht zurueckrechnen: er haengt am ctx, mit dem sie entstanden sind.
%
%   AELTERE DATEIEN HABEN DAS FELD NICHT (alles, was vor dieser Aenderung
%   gerechnet wurde). Die werden gezaehlt und uebersprungen -- sie sind
%   nicht kaputt, nur nicht wiederverwendbar, bis sie einmal neu gerechnet
%   werden. Das trifft derzeit alle 68 Dateien unter results/.
arguments
    opts.dryRun (1,1) logical = false
end

resDir = gearboxphy.paths.resultsDir();
files = dir(fullfile(resDir, '**', '*.mat'));
store = gearboxphy.data.storeDir();

n = 0; ohne = 0;
for i = 1:numel(files)
    f = fullfile(files(i).folder, files(i).name);
    if startsWith(f, store), continue; end          % der Speicher selbst
    vars = who('-file', f);
    if ~ismember('resultFingerprint', vars)
        ohne = ohne + 1;  continue
    end
    S = load(f, 'resultFingerprint');
    fp = string(S.resultFingerprint);
    if strlength(fp) == 0, continue; end
    if opts.dryRun
        fprintf('  wuerde aufnehmen: %s  <- %s\n', fp, files(i).name);
    else
        gearboxphy.data.publishToStore(fp, string(f));
    end
    n = n + 1;
end

fprintf('Ergebnisspeicher: %d Dateien mit Schluessel%s, %d ohne (vor der Umstellung gerechnet).\n', ...
    n, repmat(" (Probelauf)", 1, opts.dryRun), ohne);
end
