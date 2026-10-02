function clearCheckpoints(resultsDir, key)
%CLEARCHECKPOINTS Removes a combo's checkpoint folder once its
%   consolidated result table has been saved successfully - checkpoints
%   are a resumability aid for an in-progress sweep, not part of the
%   permanent result format.
dir_ = gearboxphy.data.checkpointDir(resultsDir, key);
if exist(dir_, 'dir')
    rmdir(dir_, 's');
end
end
