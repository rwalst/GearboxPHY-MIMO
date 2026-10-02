function p = resultsDir(name)
%RESULTSDIR  Absoluter Pfad eines Ergebnisordners unter results/.
%
%   p = gearboxphy.paths.resultsDir("cmp_mux_fixedB_d50")
%   p = gearboxphy.paths.resultsDir()         % results/ selbst
%
%   Die Ordner heissen unter results/ OHNE das alte Praefix "results_":
%   results_cmp_mux_fixedB_d50 -> results/cmp_mux_fixedB_d50. Das Praefix war nur
%   noetig, solange alle 27 Ordner neben den Skripten in derselben Ebene
%   lagen.
arguments
    name (1,1) string = ""
end
if startsWith(name, filesep)
    p = char(name);  return
end
if name == ""
    p = fullfile(gearboxphy.paths.root(), 'results');
else
    p = fullfile(gearboxphy.paths.root(), 'results', char(name));
end
end
