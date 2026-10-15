function [w, cap, source] = workerBudget(wWanted)
%WORKERBUDGET  Cap a wanted pool size at what the machine actually grants.
%
%   w = gearboxphy.sweep.workerBudget(wWanted)
%   [w, cap, source] = gearboxphy.sweep.workerBudget(wWanted)
%
%   WHY THIS IS NECESSARY, not prudent: runSweep asks for
%   min(numel(RVec), maxCores) workers, and with the usual RVec of 400 rate
%   points and maxCores = 200 that is 200. On the Windows cluster that is
%   right. A Barnard node has 104 cores and a Romeo node 128, so the very
%   same call cannot be satisfied there and parpool errors out - after the
%   job has already started, which is the expensive moment to find out.
%
%   Capping is also the right answer rather than erroring: a sweep with
%   fewer workers is slower but CORRECT. The rate points are independent and
%   each result is written per point, so the number of workers never changes
%   a number in the output - only the wall clock.
%
%   The cap, first source that answers:
%     1. SLURM_CPUS_PER_TASK - the only trustworthy number inside a SLURM
%        job. feature('numcores') reports the whole NODE there, not the
%        cores the cgroup lets us use, so asking it would overbook by a
%        factor of ten on a shared node.
%     2. NumWorkers of the resolved profile - the Windows cluster's real
%        limit.
%     3. feature('numcores') - a workstation, no scheduler in sight.
%
%   See also poolProfile (WHICH cluster), makeScenarioConfig (maxCores).
arguments
    wWanted (1,1) double {mustBeNonNan}
end

cap    = NaN;
source = "";

n = str2double(getenv('SLURM_CPUS_PER_TASK'));
if isfinite(n) && n >= 1
    cap    = floor(n);
    source = "SLURM_CPUS_PER_TASK";
else
    try
        c = parcluster(gearboxphy.sweep.poolProfile());
        if isfinite(c.NumWorkers) && c.NumWorkers >= 1
            cap    = double(c.NumWorkers);
            source = "cluster profile NumWorkers";
        end
    catch
        % No toolbox or no such profile - fall through to the core count.
    end
    if ~isfinite(cap)
        cap    = double(feature('numcores'));
        source = "feature('numcores')";
    end
end

w = min(wWanted, cap);

if w < wWanted
    warning('gearboxphy:sweep:workerCap', ...
        ['%d workers requested, %d available (%s) - running with %d.\n' ...
         'Results are unaffected, the sweep just takes about %.1fx longer.'], ...
        wWanted, cap, source, w, wWanted/max(w,1));
end
end
