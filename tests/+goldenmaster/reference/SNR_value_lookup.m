function SNR = SNR_value_lookup(SE, SE_vec, SNR_vec)
%SNR_VALUE_LOOKUP Shared core of SNR_value_QAM/_ZXM/_Pulse.
%   Given target spectral-efficiency/mutual-information point(s) SE, look
%   up the SNR [dB] required from a tabulated (SE_vec,SNR_vec) curve,
%   using the monotonic segment from the first nonzero SE_vec entry up to
%   its maximum.
%
%   This logic used to be copy-pasted identically into SNR_value_QAM.m,
%   SNR_value_ZXM.m and SNR_value_Pulse.m (differing only in which params
%   field fed SE_vec, plus a cosmetic sanity-check threshold). It sits in
%   the innermost loop of the fminsearch-based energy optimization
%   (numtriesPerOpt restarts x maxiters iterations x hundreds of rate
%   points), so it is called an extremely large number of times - keeping
%   one vectorized implementation instead of three is both less code and
%   faster per call than the original per-element for-loop.

end_idx=find(SE_vec==max(SE_vec),1);
start_idx=find(SE_vec,1,'first');
%find(SE_vec,0,'last')
SE_vec=SE_vec(start_idx:end_idx); %wegen Quadratur ACHTUNG
SNR_vec=SNR_vec(start_idx:end_idx);

SNR=interp1(SE_vec, SNR_vec,SE,'linear',NaN);

%returns NaN if its outside of domain. Vectorized equivalent of the
%original per-element for-loop:
%   for s_=1:length(SE)
%       if isnan(SNR(s_))
%           if SE(s_)>max(SE_vec), SNR(s_)=inf;
%           elseif SE(s_)<min(SE_vec), SNR(s_)=0;
%           end
%       end
%   end
needs_fixup = isnan(SNR);
SNR(needs_fixup & (SE>max(SE_vec))) = inf;   %saturated value if above domain
SNR(needs_fixup & (SE<min(SE_vec))) = 0;     %AWGN capacity ~reached at low SNR

end
