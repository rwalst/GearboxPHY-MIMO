function claimCheckpoints(resultsDir, key, fp)
%CLAIMCHECKPOINTS Bind the point checkpoints of one combo to the
%   fingerprint of the run that computes them (+data/comboFingerprint.m).
%
%   gearboxphy.data.claimCheckpoints(resultsDir, key, comboFp)
%
%   Checkpoints are keyed by rate index only. Without this, a run with
%   DIFFERENT inputs (other hardware models, other curves) that resumes in
%   the same results directory would take over the points an interrupted
%   earlier run left behind - silently mixing two models in one result.
%   So: an existing checkpoint folder whose stamp is missing or differs is
%   deleted; then the folder is stamped with fp. Called by runSweep before
%   the first point of a combo.
arguments
    resultsDir (1,1) string
    key (1,1) string
    fp (1,1) string
end
cpDir = gearboxphy.data.checkpointDir(resultsDir, key);
stamp = fullfile(cpDir, 'combo_fingerprint.mat');
if isfolder(cpDir)
    keep = false;
    if isfile(stamp)
        S = load(stamp, 'fp');
        keep = string(S.fp) == fp;
    end
    if ~keep
        warning('gearboxphy:data:staleCheckpoints', ...
            'Checkpoints of %s were written with other inputs - discarded.', key);
        gearboxphy.data.clearCheckpoints(resultsDir, key);
    end
end
if ~isfolder(cpDir), mkdir(cpDir); end
fp = char(fp); %#ok<NASGU>
save(stamp, 'fp');
end
