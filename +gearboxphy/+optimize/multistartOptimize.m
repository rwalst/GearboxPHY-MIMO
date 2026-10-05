function [best_params, best_value] = multistartOptimize(objective_fun, x0, optParams, bounds)
%MULTISTARTOPTIMIZE Repeated local optimization from several starting
%   points/intervals; returns the best (lowest-objective) result. Ported
%   verbatim from run_multistart_fminsearch.m, including the min(vals)
%   feasibility fix (the original bug: checking the *last* restart's
%   value instead of the best across all restarts, which silently
%   discarded valid optima as NaN whenever the final random restart
%   happened to be infeasible).
%
%   objective_fun : function handle of x alone (built by a gear's
%                   makeObjective(ctx, R) - invariants already baked in)
%   x0            : initial guess (row vector, e.g. [log10(B_0), gamma_0])
%   optParams     : struct with fields tolerance, maxiters, numtriesPerOpt
%   bounds        : optional [lb ub], only meaningful when x0 is scalar
%                   (currently: NA-QAM's gamma in [0,1]). When given, the
%                   scalar case is solved with fminbnd instead of
%                   fminsearch (never leaves the feasible interval, unlike
%                   unconstrained fminsearch + Inf-penalty). Omit for the
%                   multi-dimensional case (QAM/ZXM/Pulse's [log10 B,
%                   gamma]) - MATLAB has no core box-constrained
%                   equivalent of fminbnd for N>1.
%
%   Returns best_value = Inf when every restart was infeasible.

numtries = optParams.numtriesPerOpt;
dim = numel(x0);
vals = NaN(numtries,1);
optimal_parameters_vec = NaN(numtries,dim);

options = optimset('TolX',optParams.tolerance,'TolFun',optParams.tolerance, ...
    'MaxIter',optParams.maxiters,'MaxFunEvals',optParams.maxiters,'Display','off');

if dim == 1 && nargin >= 4 && ~isempty(bounds)
    %% Scalar, box-bounded case (NA-QAM's gamma): use fminbnd.
    lb = bounds(1); ub = bounds(2);

    % --- Vorab-Gitter, damit fminbnd ueberhaupt etwas zu minimieren hat ---
    % fminbnd ist ein Golden-Section-/Parabel-Verfahren: es probiert zuerst
    % bei rund 0,382 und 0,618 des Intervalls. Liefert die Zielfunktion
    % dort Inf (unzulaessig), hat es kein Gefaelle und endet auf Inf --
    % AUCH WENN anderswo im Intervall ein zulaessiger Bereich liegt.
    %
    % GEMESSEN an NA-QAM bei d = 5000 m: von 77 tatsaechlich zulaessigen
    % Ratenpunkten fand der Lauf nur 26. Die 51 verlorenen liegen bei
    % R = 1e3..1.1e7, wo das zulaessige gamma-Fenster [6e-5, 2.5e-3] bis
    % [7e-3, 0.27] breit ist -- durchweg unterhalb von 0,382, also
    % unterhalb des ersten Probepunkts. Bei d = 50 und 500 m geht kein
    % einziger Punkt verloren, weil das Fenster dort bis gamma = 1 reicht.
    % Die Luecke sah im Ergebnis wie Unzulaessigkeit aus und war keine.
    %
    % Das Gitter ist LOGARITHMISCH, weil das Fenster bei kleinen Raten um
    % Groessenordnungen nach unten wandert, seine BREITE als Verhaeltnis
    % aber etwa konstant bleibt (gemessen Faktor ~40). 256 Punkte ueber
    % sieben Dekaden treffen jedes Fenster, das breiter als Faktor 1,07 ist.
    scanLo = max(lb, 1e-9);
    if ub > scanLo
        scan = unique([lb, logspace(log10(scanLo), log10(ub), 256), ub]);
        scanVals = arrayfun(objective_fun, scan);
        okScan = isfinite(scanVals);
        if any(okScan)
            iLo = find(okScan, 1, 'first');
            iHi = find(okScan, 1, 'last');
            % eine Gittermasche Luft nach aussen, damit das Optimum am
            % Rand des zulaessigen Bereichs nicht abgeschnitten wird
            lb = scan(max(iLo-1, 1));
            ub = scan(min(iHi+1, numel(scan)));
        end
    end

    for i = 1:numtries
        if i == 1
            lo = lb; hi = ub;
        else
            lo = lb + rand()*0.3*(ub-lb);
            hi = ub - rand()*0.3*(ub-lb);
        end
        [xbest,fbest] = fminbnd(objective_fun, lo, hi, options);
        optimal_parameters_vec(i,:) = xbest;
        vals(i) = fbest;
    end
else
    %% General unconstrained case (or dim>1): fminsearch, as before.
    for i = 1:numtries
        x_i = x0;
        if i>1
            x_i = x_i./(1+rand(1,dim).*0.1);
        end
        [optimal_parameters,value] = fminsearch(objective_fun,x_i,options);
        optimal_parameters_vec(i,:) = optimal_parameters;
        vals(i) = value;
    end
end

best_value = min(vals);
index = find(vals==best_value,1,'first');
best_params = optimal_parameters_vec(index,:);

end
