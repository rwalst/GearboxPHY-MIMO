function p = absoluteDir(p)
%ABSOLUTEDIR Resolve a possibly-relative directory to an absolute path.
%
%   p = absoluteDir(p)
%
%   WHY THIS EXISTS: a RELATIVE results directory is resolved against the
%   CURRENT WORKING DIRECTORY, and inside a parfor that is the WORKER's
%   working directory, not the client's. On a local pool the workers
%   usually inherit the client's cwd, so a relative path happens to work
%   and the problem stays invisible. On a cluster (MATLAB Parallel Server,
%   separate processes and often separate machines) the workers start
%   somewhere else entirely - typically JobStorageLocation or the user's
%   home - so every worker writes its checkpoint into its OWN
%   "<cwd>/results/.checkpoints/..." and the client then cannot find any
%   of them. Symptom: the sweep never resumes, and clearCheckpoints finds
%   nothing to clean up.
%
%   Resolving ONCE on the client, before the parfor, makes client and
%   workers agree on one path. Handles POSIX ("/..."), Windows drives
%   ("C:\...") and UNC shares ("\\server\share\..."), the last of which
%   this project actually uses.
%
%   NOTE this only fixes the path AGREEMENT. The directory must still lie
%   on a filesystem every worker can reach; runSweep.m checks that
%   separately and warns.
p = char(p);
if isempty(p)
    return
end

isAbs = startsWith(p, '/') || startsWith(p, '\\') || ...
        (numel(p) >= 2 && isletter(p(1)) && p(2) == ':');
if ~isAbs
    p = fullfile(pwd, p);
end
p = string(p);
end
