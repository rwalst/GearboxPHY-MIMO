%Calculate containment BW of RRC pulses
function share_bw=get_p_containment_bw(rolloff,p_share)
%returns 2 sided p % containment bandwidth p_share in percenty

%first design RRC
sps = 1000;           % Samples per symbol (oversampling factor)
filtlen = 1000;      % Filter length in symbols
%rolloff = 0.25;    % Filter rolloff factor
% rng default;                     % Default random number generator
rrcFilter = rcosdesign(rolloff,filtlen,sps,'sqrt');

f=linspace(-0.75,0.75,1000);


PSD=rc_Spectrum(f,1,rolloff,'unitEnergyRRC');

% 95% containment
freqlims=[0,0.1*sps/2];   %just below nyquist for evaluation
%p_share=95; %in percent
% share_bw=obw(rrcFilter,sps,freqlims,p_share); %
share_bw=obw(PSD,f,[-.75,.75],p_share);

%share_bw/((1+rolloff))

end