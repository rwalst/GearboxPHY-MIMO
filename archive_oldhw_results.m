function archive_oldhw_results(action)
%ARCHIVE_OLDHW_RESULTS  Ergebnisse des ALTEN Hardwaremodellsatzes beiseite
%   legen, damit die Neurechnung sie nicht ueberschreibt.
%
%   Aufruf: in GearboxPHY-MIMO/ einfach
%       setupGearboxPath; archive_oldhw_results           % nur ZEIGEN
%       setupGearboxPath; archive_oldhw_results("move")   % wirklich verschieben
%
%   ES WIRD NICHTS GELOESCHT. Das Skript verschiebt, und zwar nach
%   results/_oldhw/ mit denselben Namen darunter.
%   Ohne Argument laeuft es als Probe und sagt nur, was es tun wuerde --
%   bei rund hundert Ordnern und Dateien ist die Probe den einen
%   zusaetzlichen Aufruf wert.
%
%   WARUM UEBERHAUPT. Nach PR #4 rechnet jeder Treiber mit dem neuen
%   Modellsatz, und die Ergebnisse werden AN DERSELBEN STELLE neu
%   geschrieben: runSweep und die vier Distanzstudien ueberspringen eine
%   fertige Datei nur bei passendem resultFingerprint, rechnen sonst neu und
%   ueberschreiben. Der alte Satz ist danach weg -- es sei denn, er liegt
%   vorher woanders. Genau das macht dieses Skript.
%
%   DIE LNA- UND HARDWAREMODELL-STUDIE WERDEN NICHT ANGEFASST, und das ist
%   eine Entscheidung gegen die naheliegende. Beide binden jeden
%   Ergebnisordner per Stempeldatei an seinen Fall und verweigern einen
%   Ordner mit abweichendem Stempel (lna:stampMismatch, hw:stampMismatch);
%   PR #4 hat die Stempel erweitert, die 22 vorhandenen Ordner tragen also
%   den alten. Verschieben waere EIN Weg gewesen. Der bessere liegt auf
%   Branch newhw-result-roots: der neue Satz bekommt eigene Wurzeln
%   (results/lna_newhw/, results/hardware_models_newhw/), die alten Ordner
%   bleiben als Referenz liegen, und ein Ordner mischt nie zwei Saetze. Sie
%   hier mitzunehmen wuerde die alte Referenz zerstoeren, die der Vergleich
%   gerade braucht.
%
%   WAS BLEIBT, WO ES IST:
%     results/lna/      s. o. -- der neue Satz bekommt eigene Wurzeln
%     results/hardware_models/
%     data/SE_data*     die MI-Kurven. Sie sind informationstheoretisch und
%                       kennen keine Hardware -- vom Modellsatz voellig
%                       unberuehrt.
%     results/_store/   der inhaltsadressierte Ergebnisspeicher. Jeder
%                       Eintrag haengt am Fingerabdruck der Rechnung, ein
%                       neuer Lauf kann einen alten Eintrag also nicht
%                       treffen. Er ist ohnehin eine Kopie und gitignored.
%
%   DANACH COMMITTEN. Die Ergebnisse sind versioniert (CLAUDE.md), git sieht
%   das Verschieben als Umbenennung von rund hundert Pfaden. Der alte Satz
%   bleibt damit als Vergleichsarm in der Geschichte -- das ist der Zweck.
%
%   Siehe docs/HPC_RUNBOOK_NEWHW.md und den Kasten am Anfang von
%   docs/MIMO_TODO.md.
arguments
    action (1,1) string {mustBeMember(action, ["show","move"])} = "show"
end
root = gearboxphy.paths.resultsDir('');
% FESTER NAME, KEIN DATUMSSTEMPEL. Ein datierter Ordner waere ordentlicher,
% aber validate_mimo_comparison sucht seine Referenzdateien unter
% results/_oldhw/<pfad> (localRefFile, Archiv zuerst) -- der Pfad muss also
% vorhersagbar sein, sonst waere die bitgenaue Regression nach dem
% Archivieren wieder blind. Ein bereits vorhandenes, nicht leeres Archiv
% wird deshalb nicht erweitert, sondern abgelehnt.
dest = fullfile(root, '_oldhw');
if action == "move" && isfolder(dest) && ~isempty(setdiff({dir(dest).name}, {'.','..'}))
    error('archive_oldhw_results:exists', ...
        ['%s liegt schon und ist nicht leer. Erst umbenennen (z.B. _oldhw_2026-10-15),\n' ...
         'dann erneut aufrufen -- zwei Modellsaetze in einem Archiv waeren genau die\n' ...
         'Vermischung, die das Archiv verhindern soll.'], dest);
end

% ---- Was wohin. Letzte Pfadkomponente mit Platzhalter, nie eine mittlere:
% ein '*' INNERHALB des Pfades ist nichts, worauf man sich ueber Windows und
% Posix hinweg verlassen sollte.
groups = { ...
  '3b, BF gegen MUX ueber die Distanz',                  {'cmp_distance_*.mat'}; ...
  '3a, BF gegen MUX ueber die Rate',                     {'cmp_*_d*'}; ...
  'Analog-BF ueber die Distanz',                         {'abf_distance_*.mat'}; ...
  'DAC-Aufloesung ueber die Distanz',                    {'dbfdac_distance_*.mat', 'abfdac_distance_*.mat'}; ...
  'Mischformen',                                         {'abfmix_distance_*.mat'}; ...
  'SISO-Grundsweep und Beamforming-Vorlaeufer',          {'main*', 'beamforming_d*', 'beamforming_distance.mat'}; ...
  'Abbildungen und Tabellen der alten Auswertungen',     {'cmp_figures', 'abf_figures', 'dbfdac_figures', 'abfmix_figures'} ...
};

fprintf('\n');
if action == "show"
    fprintf('PROBE -- es wird nichts verschoben. Mit archive_oldhw_results("move") ausfuehren.\n');
else
    fprintf('VERSCHIEBEN nach %s\n', dest);
end
fprintf('Quelle: %s\n\n', root);

nTotal = 0; nMoved = 0; nFail = 0;
for g = 1:size(groups, 1)
    label = groups{g, 1}; pats = groups{g, 2};
    items = strings(0);
    for p = 1:numel(pats)
        items = [items, localMatches(root, pats{p})]; %#ok<AGROW>
    end
    if isempty(items)
        fprintf('  %-52s --\n', label);
        continue
    end
    fprintf('  %-52s %d\n', label, numel(items));
    for k = 1:numel(items)
        [~, nm, ex] = fileparts(items(k));
        name = nm + ex;
        nTotal = nTotal + 1;
        if action == "show"
            if k <= 3
                fprintf('        %s\n', name);
            elseif k == 4
                fprintf('        ... und %d weitere\n', numel(items) - 3);
            end
            continue
        end
        if ~isfolder(dest), mkdir(dest); end
        try
            movefile(char(items(k)), char(fullfile(dest, name)));
            nMoved = nMoved + 1;
        catch err
            nFail = nFail + 1;
            fprintf(2, '        FEHLER bei %s: %s\n', name, err.message);
        end
    end
end

fprintf('\n');
if action == "show"
    fprintf('Zusammen %d Ordner/Dateien. Ausfuehren mit:\n', nTotal);
    fprintf('    archive_oldhw_results("move")\n');
else
    fprintf('%d von %d verschoben nach %s\n', nMoved, nTotal, dest);
    if nFail > 0
        fprintf(2, '%d Fehlschlaege -- nichts davon wurde geloescht, einfach erneut aufrufen.\n', nFail);
    else
        fprintf('Jetzt committen: die Ergebnisse sind versioniert, git sieht Umbenennungen.\n');
        fprintf('Danach koennen die vier Wrapper starten (docs/HPC_RUNBOOK_NEWHW.md).\n');
    end
end
fprintf('\n');
end

% =====================================================================
function out = localMatches(root, pat)
%LOCALMATCHES  Treffer eines Musters IN root, als volle Pfade.
%   Das Muster steht immer in der letzten Pfadkomponente (s. o.). Das
%   Zielarchiv selbst wird nie eingesammelt -- sonst verschiebt ein zweiter
%   Aufruf das Archiv in sich hinein.
out = strings(0);
% EIN NAME OHNE PLATZHALTER, DER EIN ORDNER IST, MUSS DIREKT ZURUECK.
% dir('einOrdner') listet dessen INHALT, nicht ihn selbst -- 'cmp_figures'
% ergab damit 21 einzelne Dateien, und localMatches baute daraus
% results/<dateiname> statt results/cmp_figures/<dateiname>: Pfade, die es
% nicht gibt. movefile waere an jedem einzeln gescheitert. Gefunden in der
% Probe, bevor das Skript je verschoben hat -- genau dafuer ist sie da.
if ~contains(pat, '*') && isfolder(fullfile(root, pat))
    out = string(fullfile(root, pat));
    return
end
d = dir(fullfile(root, pat));
for k = 1:numel(d)
    if strcmp(d(k).name, '.') || strcmp(d(k).name, '..'), continue; end
    if startsWith(d(k).name, '_oldhw') || strcmp(d(k).name, '_store'), continue; end
    out(end+1) = string(fullfile(root, d(k).name)); %#ok<AGROW>
end
end
