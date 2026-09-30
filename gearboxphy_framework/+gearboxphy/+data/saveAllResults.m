function saveAllResults(resultsDir, key, RVec, distance, antennaConfigs, E_per_bit, Optimal_B, Optimal_gamma, PowerBudget, Optimal_N_t, Optimal_N_r, ...
    E_per_bit_all, Optimal_B_all, Optimal_gamma_all, PowerBudget_all)
%SAVEALLRESULTS Single bulk write of an entire gear/order/carrier rate
%   sweep to one .mat file. Called exactly once, after a parfor loop over
%   R has finished computing all points into plain arrays/cell array (no
%   I/O happens inside that parfor body) - this is what avoids the
%   concurrent-write race a per-R parfor would have if each worker tried
%   to append to a shared results table directly.
%
%   Optimal_N_t/Optimal_N_r record which antenna configuration won the
%   nested-enumeration selection at each rate point (MIMO_EXTENSION.md
%   decision 4) - every SISO-only gear's result is uniformly 1/1, so
%   report functions never need to special-case whether a gear "has"
%   these fields.
%
%   antennaConfigs is the resolved candidate list this combo was ACTUALLY
%   computed against (gear.antennaConfigs(order,cs)) - stored as
%   antennaConfigsUsed so hasAllResults.m can detect a stale file after
%   qamMimoConfigs changes, AND as the column labels for the _all fields
%   below (column i <-> antennaConfigs{i}).
%
%   E_per_bit_all/Optimal_B_all/Optimal_gamma_all/PowerBudget_all are
%   numel(RVec) x numel(antennaConfigs): every candidate's OWN result at
%   every rate point, not just the winner's (Optimal_N_t/N_r already
%   record which column won at each row) - see
%   optimizeOnePointBestConfig.m. Optional/empty by default so a caller
%   that only ever wants the winner (or an old checkpoint predating this
%   field) doesn't have to supply them.
arguments
    resultsDir (1,1) string
    key (1,1) string
    RVec (1,:) double
    distance (1,1) double
    antennaConfigs (1,:) cell
    E_per_bit (:,1) double
    Optimal_B (:,1) double
    Optimal_gamma (:,1) double
    PowerBudget (:,1) cell
    Optimal_N_t (:,1) double = ones(numel(E_per_bit),1)
    Optimal_N_r (:,1) double = ones(numel(E_per_bit),1)
    E_per_bit_all (:,:) double = []
    Optimal_B_all (:,:) double = []
    Optimal_gamma_all (:,:) double = []
    PowerBudget_all (:,:) cell = {}
end
if ~exist(resultsDir, 'dir')
    mkdir(resultsDir)
end
antennaConfigsUsed = antennaConfigs;
file = fullfile(resultsDir, key + ".mat");
save(file, 'RVec', 'distance', 'antennaConfigsUsed', 'E_per_bit', 'Optimal_B', 'Optimal_gamma', 'PowerBudget', ...
    'Optimal_N_t', 'Optimal_N_r', 'E_per_bit_all', 'Optimal_B_all', 'Optimal_gamma_all', 'PowerBudget_all');
end
