function H = findFeasibilityHoles(E, CFG)
%FINDFEASIBILITYHOLES  Zellen, die nur durch einen Aussetzer NaN sein koennen.
%
%   H = gearboxphy.data.findFeasibilityHoles(E, CFG)
%
%   E ist das Energiefeld einer Distanzstudie, [nD x nR x nM x nN] (eine
%   fuenfte Dimension, etwa die DAC-Stufe, wird ueber alle Stufen gemindert).
%   H ist eine Tabelle der verdaechtigen Zellen mit Distanz, Rate, M und N.
%
%   WORAN MAN EIN LOCH ERKENNT: E_bit waechst monoton mit der Distanz -- ist
%   eine Konfiguration bei 10 km erreichbar, dann auch bei 10 m. Die Menge
%   der erreichbaren Distanzen je (Rate, M, N) muss also ein Praefix sein:
%   erst endlich, dann NaN. Eine ENDLICHE Zelle HINTER einer NaN-Zelle kann
%   keine Physik sein.
%
%   WOZU (E7): filterAvailableAntennaConfigs laeuft im parfor auf einem
%   Worker gegen den UNC-Share und verwirft einen Kandidaten, wenn isfile
%   ihn nicht findet. Schlaegt das voruebergehend fehl, bleibt genau eine
%   (Distanz, M, N)-Spalte NaN -- bei einer Distanz, nicht bei allen, denn
%   jede Distanz ist eine eigene parfor-Iteration. Die Ergebnisdatei sieht
%   danach vollstaendig aus. Dieser Test findet das.
%
%   KEIN BEWEIS, SONDERN EIN VERDACHT: ein Loch kann auch entstehen, wenn
%   der Optimierer an einem Punkt nicht konvergiert. Die Zellen sind
%   nachzurechnen, nicht wegzuwerfen.
arguments
    E double
    CFG (1,1) struct
end
if ndims(E) > 4
    E = min(E, [], 5:ndims(E));      % ueber DAC-Stufen o.ae. mindern
end
[nD, nR, nM, nN] = size(E);
d = CFG.distances(:); r = CFG.rates(:); Ms = CFG.Ms(:); Ns = CFG.Ns(:);

H = table('Size', [0 5], 'VariableTypes', {'double','double','double','double','double'}, ...
          'VariableNames', {'distance_m','rate_bps','M','N','erste_NaN_bei_m'});
for ri = 1:nR
    for mi = 1:nM
        for ni = 1:nN
            col = squeeze(E(:, ri, mi, ni));
            ok = isfinite(col);
            if ~any(ok), continue; end           % nirgends erreichbar: Physik
            letzte = find(ok, 1, 'last');
            loecher = find(~ok(1:letzte));       % NaN VOR der letzten endlichen
            for h = loecher(:)'
                H = [H; {d(min(h,nD)), r(ri), Ms(mi), Ns(ni), d(min(h,nD))}]; %#ok<AGROW>
            end
        end
    end
end
end
