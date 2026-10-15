function tf = isAbsolutePath(p)
%ISABSOLUTEPATH  Ist p ein absoluter Pfad -- unabhaengig von der Plattform?
%
%   tf = gearboxphy.paths.isAbsolutePath("/data/horse/ws/gearbox")   % true
%   tf = gearboxphy.paths.isAbsolutePath("\\fileserver\share\x")     % true
%   tf = gearboxphy.paths.isAbsolutePath("C:\Users\x")                % true
%   tf = gearboxphy.paths.isAbsolutePath("SE_data_mux_fixedB")        % false
%
%   WARUM NICHT filesep: dataDir und resultsDir haben die Frage vorher je
%   ueber filesep beantwortet, also je Plattform einseitig. Unter Linux galt
%   "C:\..." nicht als absolut, unter Windows nicht "/data/horse/...". Das
%   konnte nicht auffallen, solange alles auf einer Plattform lief. Seit die
%   Studien sowohl auf dem Windows-Cluster als auch auf dem ZIH-Cluster
%   laufen, sind UNC- und Posix-Pfade gleichzeitig im Umlauf -- und genau
%   resultsDir bekommt ueber GEARBOXPHY_RESULTS_ROOT einen Pfad der jeweils
%   anderen Form, wenn man sich vertippt.
%
%   Uebernommen aus +data/absoluteDir.m, das die Wurzel eines
%   Checkpoint-Ordners genauso pruefen muss; absoluteDir ruft jetzt hierher,
%   damit es nur eine Definition gibt. Ein Unterschied: dort stand
%   startsWith(p,'\\'), also ZWEI Backslashes (einfache Anfuehrungszeichen
%   maskieren in MATLAB nicht) -- damit galt nur eine UNC-Freigabe als
%   absolut. Ein einzelnes "\" ist auf Windows wurzelrelativ und darf
%   genauso wenig an root() angehaengt werden, deshalb hier ein Backslash.
p = char(p);
if isempty(p)
    tf = false;  return
end
tf = startsWith(p, '/') || startsWith(p, '\') || ...
     (numel(p) >= 2 && isletter(p(1)) && p(2) == ':');
end
