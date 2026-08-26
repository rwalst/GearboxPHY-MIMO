%Calculate containment BW of RRC pulses
function share_bw=get_p_containment_bw(rolloff,p_share)
%returns 2 sided p % containment bandwidth p_share in percent
%
%PERFORMANCE NOTE: this designs a 1e6-tap RRC filter and runs obw() on it,
%which is expensive (tens-hundreds of ms). The result depends only on
%(rolloff,p_share), not on rate/order/carrier, so callers that sweep over
%those (e.g. Sim_Init.m across R_vec) end up calling this thousands of
%times with identical inputs. We memoize on (rolloff,p_share) so repeat
%calls are O(1) map lookups instead of redoing the filter design.

persistent cache
if isempty(cache)
    cache = containers.Map('KeyType','char','ValueType','double');
end
key = sprintf('%.15g_%.15g', rolloff, p_share);
if isKey(cache, key)
    share_bw = cache(key);
    return
end

%NOTE: the original implementation also called
%rrcFilter = rcosdesign(rolloff,1000,1000,'sqrt') here, designing a
%1,000,001-tap FIR filter. That result (rrcFilter) was never used below
%(only the closed-form PSD from rc_Spectrum feeds obw()), so it was pure
%dead computation and by far the most expensive part of this function.
%Removed - does not change the returned value.
sps = 1000;           % Samples per symbol (oversampling factor)

f=linspace(-0.75,0.75,1000);


PSD=rc_Spectrum(f,1,rolloff,'unitEnergyRRC');

% 95% containment
freqlims=[0,0.1*sps/2];   %just below nyquist for evaluation
%p_share=95; %in percent
% share_bw=obw(rrcFilter,sps,freqlims,p_share); %
share_bw=obw(PSD,f,[-.75,.75],p_share);

%share_bw/((1+rolloff))

cache(key) = share_bw; %#ok<NASGU>
end
