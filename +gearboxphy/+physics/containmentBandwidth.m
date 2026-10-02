function share_bw = containmentBandwidth(rolloff, p_share)
%CONTAINMENTBANDWIDTH p_share%% two-sided containment bandwidth of an
%   RRC pulse (rolloff). Ported from get_p_containment_bw.m: the dead
%   rcosdesign() call (a never-used 1,000,001-tap filter) is already
%   removed here (it was removed in an earlier pass over the original
%   code too); memoized on (rolloff,p_share) since it's called with a
%   small number of distinct inputs across a sweep of hundreds of rate
%   points. Requires the Signal Processing Toolbox (obw()) - kept as a
%   dependency per this project's architecture decision.
persistent cache
if isempty(cache)
    cache = containers.Map('KeyType','char','ValueType','double');
end
key = sprintf('%.15g_%.15g', rolloff, p_share);
if isKey(cache, key)
    share_bw = cache(key);
    return
end

f = linspace(-0.75, 0.75, 1000);
PSD = gearboxphy.physics.rcSpectrum(f, 1, rolloff, 'unitEnergyRRC');
share_bw = obw(PSD, f, [-.75, .75], p_share);

cache(key) = share_bw; %#ok<NASGU>
end
