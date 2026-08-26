function S = load_mat_cached(filename)
%LOAD_MAT_CACHED Memoized .mat loader for the small set of SE/SNR lookup
%tables read by Sim_Init.m (SE_data/SE_*_QAM.mat, MUI_ZXM_*.mat,
%SE_*_IR.mat, ...).
%
%   Sim_Init.m is invoked once per rate point in a sweep over hundreds of
%   rates (R_vec), and for a fixed modulation order it re-loads the exact
%   same .mat file from disk every single time even though its contents
%   never change across the sweep. Memoizing here (per worker, since
%   Sim_Init runs under parfor) turns hundreds of redundant disk reads
%   into one read plus in-memory struct lookups.
%
%   Returns a struct of the file's variables (like S=load(filename)),
%   rather than dumping variables into the caller's workspace.

persistent cache
if isempty(cache)
    cache = containers.Map('KeyType','char','ValueType','any');
end
if isKey(cache, filename)
    S = cache(filename);
    return
end
S = load(filename);
cache(filename) = S;
end
