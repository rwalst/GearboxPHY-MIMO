function tf = fingerprintMatches(file, fp)
%FINGERPRINTMATCHES  Traegt diese Ergebnisdatei schon genau diesen Schluessel?
%
%   tf = gearboxphy.data.fingerprintMatches(outFile, fp)
%
%   Der schaerfste "ist schon gerechnet"-Test, den es gibt: der Schluessel
%   deckt die ganze Eingabe der Rechnung ab (+data/gridFingerprint.m), also
%   auch das Raster, die Modelle und den INHALT der Kurven. Er ersetzt damit
%   zwei schwaechere Pruefungen auf einmal:
%
%     * einen CFG-Vergleich -- der sieht nur das Raster, nicht die Modelle;
%     * einen Zeitstempel-Vergleich gegen den Kurvenordner -- der haelt ein
%       blosses "touch" fuer eine Aenderung und eine inhaltliche Aenderung
%       bei gleicher Zeit fuer keine.
%
%   Dateien von vor der Umstellung haben das Feld nicht und gelten damit als
%   nicht passend. Das ist die richtige Antwort: sie koennen unter anderen
%   Modellen entstanden sein, und das laesst sich ihnen nicht ansehen.
arguments
    file (1,1) string
    fp (1,1) string
end
tf = false;
if strlength(fp) == 0 || ~isfile(file), return; end
try
    if ~ismember('resultFingerprint', who('-file', char(file))), return; end
    S = load(file, 'resultFingerprint');
    tf = string(S.resultFingerprint) == fp;
catch
    tf = false;   % unlesbar = nicht passend
end
end
