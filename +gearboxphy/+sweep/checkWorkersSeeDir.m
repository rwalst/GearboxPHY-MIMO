function ok = checkWorkersSeeDir(resultsDir)
%CHECKWORKERSSEEDIR Verify every parpool worker can actually reach the
%   results directory, and say so loudly if not.
%
%   ok = checkWorkersSeeDir(resultsDir)
%
%   Making the path absolute (+data/absoluteDir.m) fixes client/worker
%   DISAGREEMENT about where "results" is. It cannot fix the other half of
%   the same failure: on a multi-node cluster the path may be perfectly
%   well-defined and still be invisible to a worker, because it lives on a
%   disk only the submitting machine has mounted. Both failures look
%   identical from the client - checkpoints are written, then apparently
%   vanish, and the sweep never resumes.
%
%   This probes it directly instead of leaving it to be discovered after a
%   multi-hour run: each worker reports whether it can see the directory
%   and whether it can actually write there (a read-only mount is just as
%   fatal, and `isfolder` alone would not catch it).
if isempty(gcp('nocreate'))
    ok = true; return
end
resultsDir = char(resultsDir);

probeDir = fullfile(resultsDir, '.probe');
[~,~] = mkdir(probeDir);

n = gcp('nocreate').NumWorkers;
seen  = false(1,n);
wrote = false(1,n);
parfor w = 1:n
    seen(w) = isfolder(probeDir);
    try
        f = fullfile(probeDir, sprintf('w%05d.tmp', w));
        fid = fopen(f, 'w');
        if fid > 0
            fprintf(fid, 'ok');
            fclose(fid);
            wrote(w) = isfile(f);
            delete(f);
        end
    catch
        wrote(w) = false;
    end
end

[~,~] = rmdir(probeDir, 's');
ok = all(seen) && all(wrote);

if ~ok
    warning('gearboxphy:sweep:workersCannotReachResults', ...
        ['%d of %d workers cannot see and %d cannot write to\n    %s\n' ...
         'Checkpointing and resume will NOT work: each worker writes into a\n' ...
         'location the client never reads. Put the results directory on a\n' ...
         'filesystem shared by all workers (or run on a single node).'], ...
        sum(~seen), n, sum(~wrote), resultsDir);
else
    fprintf('Checkpoint directory reachable and writable by all %d workers.\n', n);
end
end
