function p = dataDir(name)
%DATADIR  Absoluter Pfad eines Kurvenordners unter data/.
%
%   p = gearboxphy.paths.dataDir()            % data/SE_data (Vorgabe)
%   p = gearboxphy.paths.dataDir("SE_data_mux_fixedB")
%
%   Nimmt auch einen bereits absoluten Pfad entgegen und gibt ihn
%   unveraendert zurueck -- damit koennen Aufrufer (Tests, Exporte) weiter
%   in temporaere Verzeichnisse zeigen, ohne Sonderfall.
arguments
    name (1,1) string = "SE_data"
end
if startsWith(name, filesep) || contains(name, ':' + string(filesep))
    p = char(name);  return
end
p = fullfile(gearboxphy.paths.root(), 'data', char(name));
end
