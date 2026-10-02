function p = root()
%ROOT  Wurzel dieses Repos, abgeleitet aus dem Ort DIESER Datei.
%
%   p = gearboxphy.paths.root()
%
%   Die eine Stelle, an der das Repo seinen eigenen Ort bestimmt. Alles
%   andere (Kurven, Ergebnisse) haengt daran, siehe dataDir/resultsDir.
%
%   WARUM UEBERHAUPT: vorher stand als Vorgabe fuer den Kurvenordner
%   schlicht "SE_data" -- ein RELATIVER Pfad. Der funktionierte nur,
%   solange das aktuelle Verzeichnis die Framework-Wurzel war, und lieferte
%   sonst wortlos "Datei nicht gefunden". Seit die Studienskripte in
%   studies/<name>/ liegen, ist das aktuelle Verzeichnis beim Aufruf
%   regelmaessig ein anderes.
p = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
