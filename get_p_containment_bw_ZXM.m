%Calculate containment BW of RRC pulses
function share_bw=get_p_containment_bw_ZXM(rolloff,p_share,M_tx)
%returns 2 sided p % containment bandwidth for ZXM, p_share in percent
%based on Peters OJcoms paper (49)
%
%PERFORMANCE NOTE: depends only on (rolloff,p_share,M_tx), not on
%rate/carrier, but callers (Sim_Init.m) invoke this once per rate point
%in a sweep over hundreds of rates. Memoized below so repeat calls with
%the same (rolloff,p_share,M_tx) are O(1). The inner frequency-response
%computation is also vectorized (was a 1000 x ~200 nested scalar loop).

persistent cache
if isempty(cache)
    cache = containers.Map('KeyType','char','ValueType','double');
end
key = sprintf('%.15g_%.15g_%.15g', rolloff, p_share, M_tx);
if isKey(cache, key)
    share_bw = cache(key);
    return
end

d=M_tx-1;
%NOTE: the original implementation also called
%rrcFilter = rcosdesign(rolloff,1000,1000,'sqrt') here. That result was
%never used below (only the closed-form PSD from rc_Spectrum feeds obw()),
%so it was dead computation - removed, does not change the returned value.
sps = 1000;           % Samples per symbol (oversampling factor)

f=linspace(-0.75,0.75,1000);


PSD=rc_Spectrum(f,1,rolloff,'unitEnergyRRC');
%% calc psd of rll sequences using results from peter and Immink

%generate RLL sequence properties
[lambda, ~]=fct_maxEntropic_dk_properties(d, inf);

%das hier ist jetzt peter
%lambda = max(diag(eigDiag));
myK = 200;

l_bar = (d+1:myK).';
barT = sum(l_bar .* lambda.^(-l_bar));

% Vectorized replacement for the original double loop over f and l:
%   for f_ = 1:length(f)
%       for l = d+1:myK+1
%           curG = curG + lambda^(-l) * exp(1i*2*pi*f(f_)*l);
%       end
%       ...
%   end
% curG(f) = sum_l lambda^-l * exp(i*2*pi*f*l), computed as one
% outer-product matrix-vector product instead of 1000*~200 scalar ops.
l = (d+1:myK+1).';                 % column: exponent range
weights = lambda.^(-l);            % column
phase = exp(1i*2*pi*f(:).'.*l);    % (numel(l) x numel(f)) matrix
curG = (weights.' * phase).';      % column, one entry per frequency

help_ = sin(pi*f(:)).^2;

X2_Ref = zeros(length(f),1);
valid = help_ >= 1e-9;
X2_Ref(valid) = 1./(barT.*help_(valid)) .* (1-abs(curG(valid)).^2)./abs(1+curG(valid)).^2;
% X2_Ref stays 0 where help_ < 1e-9, matching the original loop's branch.

%is this (^) the same as if I directly took the FFT?
% rll= fct_genMaxEntropicRllSeq(d,inf,1e5 );
% rll_seq=rll.rll;
% fs=1;
% N = length(rll_seq);
% xdft = fft(rll_seq);
% xdft = xdft(1:N/2+1);
% psdx = (1/(fs*N)) * abs(xdft).^2;
% psdx(2:end-1) = 2*psdx(2:end-1);
% freq = 0:fs/length(rll_seq):fs/2;
% yes, looks very similar

% 95% containment
freqlims=[0,0.1*sps/2];   %just below nyquist for evaluation
%p_share=95; %in percent
% share_bw=obw(rrcFilter,sps,freqlims,p_share); %
share_bw=obw(PSD.*X2_Ref.',f,[-.75,.75],p_share);

%share_bw/((1+rolloff))

cache(key) = share_bw; %#ok<NASGU>
end
