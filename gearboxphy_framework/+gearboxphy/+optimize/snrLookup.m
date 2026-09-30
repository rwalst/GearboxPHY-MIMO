function SNR = snrLookup(SE, SE_vec, SNR_vec)
%SNRLOOKUP Required SNR [dB] for a target SE/mutual-info value, via
%   interpolation over an ALREADY-TRIMMED (SE_vec,SNR_vec) curve - see
%   +optimize/trimCurve.m, called once in each gear's prepare(). This
%   function no longer re-derives the trim on every call the way the
%   original SNR_value_lookup.m (and this file's first version) did,
%   since that ran on every one of potentially millions of objective
%   evaluations per sweep for a curve that never changes within a run
%   (code review finding #9).
SNR = interp1(SE_vec, SNR_vec, SE, 'linear', NaN);

% Vectorized equivalent of the original per-element for-loop fixup:
needs_fixup = isnan(SNR);
SNR(needs_fixup & (SE>max(SE_vec))) = inf;   %saturated value if above domain
SNR(needs_fixup & (SE<min(SE_vec))) = 0;     %AWGN capacity ~reached at low SNR
end
