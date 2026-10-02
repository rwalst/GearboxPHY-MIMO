function fig = plotPowerBudgetReport(resultsDir, scenario, gearName, order, f_c)
%PLOTPOWERBUDGETREPORT Stacked-area power breakdown for one gear/order/
%   carrier, ported from Wrapper.m's power-budget section (originally
%   hardcoded to M=1024 QAM @ 28GHz - generalized here to take those as
%   parameters, defaulting to the same original slice).
%
%   Only supports gears whose budget struct has the standard 8 fields
%   (PA/DAC/LO_Tx/Mix_Tx/LNA/LO_Rx/Mix_Rx/ADC) - QAM/NA-QAM/ZXM/
%   Pulse-Arbitrary. Pulse-Energy uses EnergyDetector instead of LO_Rx/
%   Mix_Rx and is explicitly rejected with a clear error naming the
%   incompatible gear and its missing fields, rather than crashing on a
%   "no such field" error partway through plotting (code review finding
%   #1).
arguments
    resultsDir (1,1) string
    scenario (1,1) struct
    gearName (1,1) string = "QAM"
    order (1,1) double = 1024
    f_c (1,1) double = 28e9
end
key = gearboxphy.data.resultKey(gearName, order, f_c);
S = gearboxphy.data.loadAllResults(resultsDir, key);

fields = ["DAC","PA","LO_Tx","Mix_Tx","LNA","LO_Rx","Mix_Rx","ADC"];
firstFeasible = find(cellfun(@isstruct, S.PowerBudget), 1, 'first');
if isempty(firstFeasible)
    error('gearboxphy:report:noFeasiblePoints', ...
        'No feasible points found for %s (order=%g, f_c=%g) - nothing to plot.', gearName, order, f_c);
end
missing = fields(~isfield(S.PowerBudget{firstFeasible}, fields));
if ~isempty(missing)
    error('gearboxphy:report:unsupportedBudgetSchema', ...
        ['plotPowerBudgetReport only supports gears with the standard 8-field budget schema ' ...
         '(%s). "%s" is missing: %s. (Pulse-Energy, for example, uses EnergyDetector instead of ' ...
         'LO_Rx/Mix_Rx and is not supported by this generic reporter.)'], ...
        strjoin(fields, ','), gearName, strjoin(missing, ','));
end

n = numel(S.PowerBudget);
Area = NaN(numel(fields), n);
for r = 1:n
    b = S.PowerBudget{r};
    if ~isstruct(b)
        continue   % infeasible point - leave as NaN, matching original preallocation fix
    end
    total = b.PA + b.DAC + b.LO_Tx + b.Mix_Tx + b.LNA + b.LO_Rx + b.Mix_Rx + b.ADC;
    for fi = 1:numel(fields)
        Area(fi,r) = b.(fields(fi)) / total;
    end
end

fig = figure();
area(S.RVec(1:size(Area,2)), Area.')
legend(cellstr(fields))
title(sprintf('Power for %s (order=%g)', gearName, order))
set(gca, 'XScale', 'log')
xlabel('R_{eff} [bit/s]'); ylabel('Relative Power')
xlim([min(S.RVec), max(S.RVec)])
end
