function file = checkpointFile(resultsDir, key, r)
%CHECKPOINTFILE Path to one rate-point's checkpoint file within a
%   gear/order/carrier combo's in-progress sweep (see runSweep.m). One
%   file per r, written by a different parfor worker each - safe, no
%   concurrent-write race (same reasoning as the original codebase's
%   per-point .mat design), just scoped here as a resumability mechanism
%   for an in-progress sweep rather than the permanent result format
%   (which stays the consolidated per-(gear,order,carrier) table from
%   +data/saveAllResults.m - see code review finding #5).
% Directory comes from checkpointDir.m - the one place it is built, and
% the one place the no-dots rule is enforced.
file = fullfile(gearboxphy.data.checkpointDir(resultsDir, key), sprintf('r%04d.mat', r));
end
