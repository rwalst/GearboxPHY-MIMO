function [SE_vec, SNR_vec] = trimCurve(SE_vec, SNR_vec)
%TRIMCURVE Trims a raw (SE_vec,SNR_vec) curve down to its monotonic
%   segment (first nonzero SE_vec entry up to its maximum) - the same
%   trim snrLookup.m used to redo on every single call (finding #9 of the
%   code review: this ran on every one of potentially millions of
%   objective-function evaluations per sweep, even though the curve never
%   changes within a (gear,order,carrier) run). Call this once, in a
%   gear's prepare(), and store the trimmed arrays in ctx; snrLookup()
%   then assumes its inputs are already trimmed and does no slicing.
end_idx = find(SE_vec==max(SE_vec),1);
start_idx = find(SE_vec,1,'first');
SE_vec = SE_vec(start_idx:end_idx);
SNR_vec = SNR_vec(start_idx:end_idx);
end
