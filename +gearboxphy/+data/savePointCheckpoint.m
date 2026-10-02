function savePointCheckpoint(resultsDir, key, r, E_per_bit, Optimal_B, Optimal_gamma, PowerBudget, Optimal_N_t, Optimal_N_r, ...
    E_per_bit_all, Optimal_B_all, Optimal_gamma_all, PowerBudget_all)
%SAVEPOINTCHECKPOINT Writes one rate-point's result to its own checkpoint
%   file. Called from inside runSweep's parfor body - each r writes a
%   distinct file, so this is safe under parallel execution.
%   Optimal_N_t/Optimal_N_r record which antenna configuration won the
%   nested-enumeration selection for this point (MIMO_EXTENSION.md
%   decision 4) - 1/1 for every SISO-only gear.
%
%   The _all fields (1 x n, one entry per antenna-config candidate) are
%   optional so this stays loadable/callable against old checkpoints/
%   callers that only ever knew the winner - see loadPointCheckpoint.m.
if nargin < 10, E_per_bit_all = []; Optimal_B_all = []; Optimal_gamma_all = []; PowerBudget_all = {}; end
file = gearboxphy.data.checkpointFile(resultsDir, key, r);
dir_ = fileparts(file);
% Called from inside runSweep's parfor across many workers, all racing to
% create this SAME per-combo checkpoint directory the first time: an
% exist()-then-mkdir() check has a TOCTOU gap under parallel execution
% (several workers can see "doesn't exist" before any of them creates
% it), so every worker but the first still hits mkdir's "Directory
% already exists" warning despite the guard. Requesting mkdir's outputs
% suppresses that warning by design (mkdir is idempotent - it returns
% success when the directory already exists).
%
% But the STATUS IS CHECKED rather than discarded: "[~,~] = mkdir(...)"
% silences a genuine failure just as effectively as the harmless warning,
% which is precisely how an unwritable or rejected checkpoint directory
% on a cluster share could fail invisibly. Fail loudly instead.
[okDir, msg, msgid] = mkdir(dir_);
if ~okDir
    error('gearboxphy:data:checkpointDirFailed', ...
        ['Could not create the checkpoint directory\n    %s\n%s (%s)\n' ...
         'On a cluster this usually means the results directory is not ' ...
         'writable from the worker.'], dir_, msg, msgid);
end
save(file, 'E_per_bit', 'Optimal_B', 'Optimal_gamma', 'PowerBudget', 'Optimal_N_t', 'Optimal_N_r', ...
    'E_per_bit_all', 'Optimal_B_all', 'Optimal_gamma_all', 'PowerBudget_all');
end
