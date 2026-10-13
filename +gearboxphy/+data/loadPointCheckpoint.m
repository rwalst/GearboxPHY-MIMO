function [E_per_bit, Optimal_B, Optimal_gamma, PowerBudget, Optimal_N_t, Optimal_N_r, ...
    E_per_bit_all, Optimal_B_all, Optimal_gamma_all, PowerBudget_all, ...
    OperatingPoint, OperatingPoint_all] = loadPointCheckpoint(resultsDir, key, r)
%LOADPOINTCHECKPOINT Reads back one rate-point's checkpointed result
%   (see savePointCheckpoint.m/hasPointCheckpoint.m).
%
%   The _all outputs come back empty ([]/{}) for a checkpoint written
%   before those fields existed - same "missing means stale/unavailable,
%   not an error" convention as hasAllResults.m's antennaConfigsUsed
%   check, just resolved here instead of forcing a recompute.
%
%   AN OLD CHECKPOINT WITHOUT OperatingPoint WARNS. The same "missing is
%   not an error" convention would apply, but here it has a consequence
%   worth hearing: the resumed sweep writes a result file whose SE and
%   SNR are NaN at exactly the points it did not recompute. The warning
%   says so instead of leaving it to be discovered in the analysis. Delete
%   the checkpoint directory to recompute those points.
file = gearboxphy.data.checkpointFile(resultsDir, key, r);
S = load(file);
E_per_bit = S.E_per_bit;
Optimal_B = S.Optimal_B;
Optimal_gamma = S.Optimal_gamma;
PowerBudget = S.PowerBudget;
Optimal_N_t = S.Optimal_N_t;
Optimal_N_r = S.Optimal_N_r;
if isfield(S, 'E_per_bit_all')
    E_per_bit_all = S.E_per_bit_all;
    Optimal_B_all = S.Optimal_B_all;
    Optimal_gamma_all = S.Optimal_gamma_all;
    PowerBudget_all = S.PowerBudget_all;
else
    E_per_bit_all = []; Optimal_B_all = []; Optimal_gamma_all = []; PowerBudget_all = {};
end
if isfield(S, 'OperatingPoint')
    OperatingPoint = S.OperatingPoint;
    OperatingPoint_all = S.OperatingPoint_all;
else
    OperatingPoint = gearboxphy.gears.operatingPointFrom([]);
    OperatingPoint_all = {};
    warning('gearboxphy:data:checkpointWithoutOperatingPoint', ...
        ['%s hat keinen Arbeitspunkt (Checkpoint von vor dieser Erweiterung). ' ...
         'SE und SNR bleiben fuer diesen Punkt NaN. Checkpoint-Ordner loeschen, ' ...
         'um ihn neu zu rechnen.'], file);
end
end
