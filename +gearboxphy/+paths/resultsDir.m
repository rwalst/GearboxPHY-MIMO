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
%
%   GEARBOXPHY_RESULTS_ROOT verlegt die WURZEL aller Ergebnisse. Auf dem
%   ZIH-Cluster muss das sein: dort liegt der Code im Home, und das Home ist
%   fuer Job-Ausgaben ausdruecklich nicht gedacht -- die Ergebnisse gehoeren
%   in einen Workspace (/data/horse/ws/...). Diese eine Stelle deckt alle 47
%   Aufrufstellen ab.
%
%   ACHTUNG, und das ist die Falle: resultsDir wird auch zum LESEN benutzt
%   (analyze_mimo_comparison, analyze_adc_rule_curves, +report/*). Die
%   Variable lenkt beides um. Wer sie setzt, muss die vorhandenen Ergebnisse
%   einmal mitkopieren, sonst findet die Auswertung nichts mehr -- siehe
%   docs/HPC_RUNBOOK_ZIH.md. Eine Lese/Schreib-Unterscheidung waere die
%   schlechtere Antwort: sie wuerde jeden ueberraschen, der sie nicht kennt.
arguments
    name (1,1) string = ""
end
if gearboxphy.paths.isAbsolutePath(name)
    p = char(name);  return
end
base = string(getenv('GEARBOXPHY_RESULTS_ROOT'));
if strlength(strtrim(base)) > 0
    base = char(strtrim(base));
else
    base = fullfile(gearboxphy.paths.root(), 'results');
end
if name == ""
    p = base;
else
    p = fullfile(base, char(name));
end
end
