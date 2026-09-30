function tf = hasPointCheckpoint(resultsDir, key, r)
%HASPOINTCHECKPOINT True if rate-point r already has a checkpointed
%   result for this (gear, order, carrier) combo - lets a resumed
%   runSweep skip recomputation of points already done before an
%   interruption, without reintroducing the concurrent-write race a
%   shared results table would have (see checkpointFile.m).
tf = isfile(gearboxphy.data.checkpointFile(resultsDir, key, r));
end
