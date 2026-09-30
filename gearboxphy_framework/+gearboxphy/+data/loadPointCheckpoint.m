function [E_per_bit, Optimal_B, Optimal_gamma, PowerBudget, Optimal_N_t, Optimal_N_r, ...
    E_per_bit_all, Optimal_B_all, Optimal_gamma_all, PowerBudget_all] = loadPointCheckpoint(resultsDir, key, r)
%LOADPOINTCHECKPOINT Reads back one rate-point's checkpointed result
%   (see savePointCheckpoint.m/hasPointCheckpoint.m).
%
%   The _all outputs come back empty ([]/{}) for a checkpoint written
%   before those fields existed - same "missing means stale/unavailable,
%   not an error" convention as hasAllResults.m's antennaConfigsUsed
%   check, just resolved here instead of forcing a recompute.
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
end
