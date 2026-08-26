%Calculate containment BW of RRC pulses
function share_bw=get_p_containment_bw_ZXM(rolloff,p_share,M_tx)
%returns 2 sided p % containment bandwidth for ZXM, p_share in percent
%based on Peters OJcoms paper (49)
d=M_tx-1;
%first design RRC
sps = 1000;           % Samples per symbol (oversampling factor)
filtlen = 1000;      % Filter length in symbols
%rolloff = 0.25;    % Filter rolloff factor
% rng default;                     % Default random number generator
rrcFilter = rcosdesign(rolloff,filtlen,sps,'sqrt');

f=linspace(-0.75,0.75,1000);


PSD=rc_Spectrum(f,1,rolloff,'unitEnergyRRC');
%% calc psd of rll sequences using results from peter and Immink

%generate RLL sequence properties
[lambda, ~]=fct_maxEntropic_dk_properties(d, inf);

%das hier ist jetzt peter
%lambda = max(diag(eigDiag));
iter = 0;
myK = 200;

barT = 0;
for l = d+1 : myK
    barT = barT + l * lambda^(-l);
end

for f_=1:length(f)
    
    fNorm = f(f_);
    iter = iter + 1;
    curG = 0;
    
    for l = d + 1 : myK + 1
        curG = curG + lambda^(-l) * exp(1i * 2 * pi * fNorm * l);
    end
    
    help = sin(pi*fNorm)^2;
    
    if help < 1e-9
        X2_Ref(iter,1) = 0;
    else
        X2_Ref(iter,1) = 1/(barT*help) * (1-abs(curG)^2)/abs(1+curG)^2;
    end
    
end

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

end