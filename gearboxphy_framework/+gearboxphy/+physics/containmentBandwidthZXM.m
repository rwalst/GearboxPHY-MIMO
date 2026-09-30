function share_bw = containmentBandwidthZXM(rolloff, p_share, M_tx)
%CONTAINMENTBANDWIDTHZXM p_share%% two-sided containment bandwidth for
%   ZXM (Neuhaus et al. OJCOMS, eq. 49). Ported from
%   get_p_containment_bw_ZXM.m, including the vectorized inner PSD
%   computation (originally a 1000x~200 nested scalar loop). Requires the
%   Signal Processing Toolbox (obw()) - kept as a dependency per this
%   project's architecture decision.
persistent cache
if isempty(cache)
    cache = containers.Map('KeyType','char','ValueType','double');
end
key = sprintf('%.15g_%.15g_%.15g', rolloff, p_share, M_tx);
if isKey(cache, key)
    share_bw = cache(key);
    return
end

d = M_tx - 1;
f = linspace(-0.75, 0.75, 1000);
PSD = gearboxphy.physics.rcSpectrum(f, 1, rolloff, 'unitEnergyRRC');

[lambda, ~] = gearboxphy.physics.maxEntropicDkProperties(d, inf);
myK = 200;

l_bar = (d+1:myK).';
barT = sum(l_bar .* lambda.^(-l_bar));

l = (d+1:myK+1).';
weights = lambda.^(-l);
phase = exp(1i*2*pi*f(:).'.*l);
curG = (weights.' * phase).';

help_ = sin(pi*f(:)).^2;
X2_Ref = zeros(length(f),1);
valid = help_ >= 1e-9;
X2_Ref(valid) = 1./(barT.*help_(valid)) .* (1-abs(curG(valid)).^2)./abs(1+curG(valid)).^2;

share_bw = obw(PSD.*X2_Ref.', f, [-.75, .75], p_share);

cache(key) = share_bw; %#ok<NASGU>
end
