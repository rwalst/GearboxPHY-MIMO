function setupGearboxPath()
%SETUPGEARBOXPATH  Fuegt alle Code-Ordner dieses Repos dem MATLAB-Pfad hinzu.
%
%   Aufruf immer in zwei Schritten (das erste addpath macht setupGearboxPath.m
%   selbst auffindbar, danach fuegt die Funktion den Rest hinzu):
%
%       addpath('/workspace/GearboxPHY-MIMO'); setupGearboxPath;
%       run_mimo_comparison_sweep
%
%   WARUM NOETIG: die Studienskripte liegen seit dem Aufraeumen in
%   studies/<name>/ statt im Wurzelverzeichnis. MATLAB nimmt nur das
%   AKTUELLE Verzeichnis automatisch auf -- ohne diesen Aufruf findet es
%   also weder die Treiber noch, beim Hineinwechseln in einen Studienordner,
%   das Paket +gearboxphy.
%
%   NICHT "setupPath" genannt, obwohl das Nachbarrepo QuantizedMimoMI
%   seine Funktion so nennt: studies/mimo_comparison/ legt BEIDE Repos auf
%   den Pfad und ruft dort setupPath des Nachbarn auf. Zwei Dateien
%   gleichen Namens haetten sich je nach Pfadreihenfolge verschattet --
%   und zwar lautlos.
%
%   NICHT per genpath: results/, data/ und docs/ enthalten keinen Code,
%   tests/+goldenmaster/reference/ haelt Gasts Originalskripte mit Namen
%   wie Sim_Init.m, die aktuelle Funktionen verschatten koennten. Beides
%   bleibt bewusst draussen; der Golden-Master-Test fuegt reference/ fuer
%   seine Dauer selbst hinzu und entfernt es danach wieder.
root = fileparts(mfilename('fullpath'));

folders = {root, fullfile(root, 'tests')};
s = dir(fullfile(root, 'studies'));
for i = 1:numel(s)
    if s(i).isdir && ~startsWith(s(i).name, '.')
        folders{end+1} = fullfile(root, 'studies', s(i).name); %#ok<AGROW>
    end
end

for i = 1:numel(folders)
    addpath(folders{i});
end
end
