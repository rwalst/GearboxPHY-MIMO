function [profile, source] = poolProfile()
%POOLPROFILE  Which parpool cluster profile to use - the one place that decides.
%
%   [profile, source] = gearboxphy.sweep.poolProfile()
%
%   The framework has to run on TWO clusters now: the Windows cluster, whose
%   profile is called 'HPCServer', and the ZIH cluster in Dresden (Linux +
%   SLURM), where no such profile exists. The literal "HPCServer" used to sit
%   in five places; moving it here is what makes the second cluster possible
%   without touching five files again for a third one.
%
%   First source wins:
%     1. GEARBOXPHY_CLUSTER_PROFILE - the escape hatch. Lets a run pick a
%        profile without editing code, which is the only thing that helps when
%        a cluster turns out to be named something nobody anticipated.
%     2. SLURM_JOB_ID set -> 'Processes' (or its old name 'local'). Inside a
%        SLURM allocation the cores are ALREADY granted, so the pool must stay
%        on this node. Handing the work to a second scheduler from inside a job
%        is what makes a job sit in its own queue and time out.
%     3. 'HPCServer', if the profile exists -> the Windows cluster, unchanged.
%     4. The default profile, whatever it is called locally.
%
%   The second output names the source. Callers print it next to the pool size,
%   so a log says WHICH cluster was assumed - the one thing worth knowing when
%   a run behaves differently than the same code did yesterday.
%
%   See also workerBudget (how MANY workers), checkWorkersSeeDir.

env = string(getenv('GEARBOXPHY_CLUSTER_PROFILE'));
if strlength(strtrim(env)) > 0
    profile = strtrim(env);
    source  = "GEARBOXPHY_CLUSTER_PROFILE";
    return
end

avail = localAvailable();

if strlength(string(getenv('SLURM_JOB_ID'))) > 0
    % 'Processes' is the R2022b+ name, 'local' the older one. Check both:
    % the cluster's MATLAB version is not ours to choose.
    for cand = ["Processes", "local"]
        if any(avail == cand)
            profile = cand;
            source  = "SLURM_JOB_ID (node-local pool)";
            return
        end
    end
end

if any(avail == "HPCServer")
    profile = "HPCServer";
    source  = "clusterProfiles";
    return
end

try
    profile = string(parallel.defaultClusterProfile());
    source  = "default profile";
catch
    % No Parallel Computing Toolbox. parpool would fail on any name; return
    % the usual one so the CALLER's error is about the missing toolbox
    % rather than about an empty profile name.
    profile = "Processes";
    source  = "fallback (no Parallel Computing Toolbox)";
end
end

function avail = localAvailable()
%LOCALAVAILABLE  Installed profile names, or empty if there is no toolbox.
try
    avail = string(parallel.clusterProfiles());
catch
    avail = string.empty(1,0);
end
end
