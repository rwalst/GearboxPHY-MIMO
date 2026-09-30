function S = loadMatCached(filename)
%LOADMATCACHED Memoized .mat loader, ported from load_mat_cached.m.
%   Returns a struct of the file's variables. Cache is per-worker under
%   parfor, same as the original.
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
