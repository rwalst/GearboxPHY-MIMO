function [c, source] = clusterFor()
%CLUSTERFOR  The cluster object to open a pool on, configured for this machine.
%
%   [c, source] = gearboxphy.sweep.clusterFor()
%   parpool(c, gearboxphy.sweep.workerBudget(nWanted))
%
%   Two things in one place, because both have to happen at every one of the
%   five pool sites:
%     - the profile comes from poolProfile (Windows cluster vs. SLURM job),
%     - NumThreads = 1, so each worker gets ONE computational thread.
%
%   WHY NumThreads MATTERS: by default a worker may start several BLAS
%   threads. A 100-worker pool then wants several hundred threads on a node
%   that granted 104 cores, and under a cgroup they do not get more cores for
%   it - they just take turns. The job runs SLOWER than the same job with
%   fewer workers, which is the kind of slowdown nobody looks for because
%   nothing failed.
%
%   WHY IT IS GUARDED: NumThreads is not writable on every cluster type. The
%   Windows path has worked for years without it, so a cluster that refuses
%   the property must keep working exactly as before - hence a notice, not an
%   error. On a Processes pool (ZIH) it always takes.
[profile, source] = gearboxphy.sweep.poolProfile();
c = parcluster(profile);
try
    c.NumThreads = 1;
catch err
    fprintf(['Note: profile "%s" does not accept NumThreads (%s) - ' ...
             'leaving it at the cluster default.\n'], profile, err.identifier);
end
end
