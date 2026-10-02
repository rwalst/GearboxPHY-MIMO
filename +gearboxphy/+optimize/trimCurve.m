function [SE_vec, SNR_vec] = trimCurve(SE_vec, SNR_vec)
%TRIMCURVE Trims a raw (SE_vec,SNR_vec) curve down to a STRICTLY
%   increasing segment (first nonzero SE_vec entry up to its maximum) -
%   the same trim snrLookup.m used to redo on every single call (finding
%   #9 of the code review: this ran on every one of potentially millions
%   of objective-function evaluations per sweep, even though the curve
%   never changes within a (gear,order,carrier) run). Call this once, in a
%   gear's prepare(), and store the trimmed arrays in ctx; snrLookup()
%   then assumes its inputs are already trimmed and does no slicing.
%
%   STRICTLY increasing, not just ending at the maximum. snrLookup
%   interpolates INVERSELY - interp1(SE_vec, SNR_vec, SE) - so SE_vec is
%   the sample-point axis and interp1 rejects it outright if any value
%   repeats ("Sample points must be unique").
%
%   Cutting at the first maximum is not enough for that. An exactly
%   computed curve approaches its cap asymptotically and reaches a plateau
%   in double precision BEFORE the maximum: several consecutive entries
%   are bit-identical, and a later one is larger by about 1e-15. The
%   maximum therefore sits past the plateau, the plateau survives the cut,
%   and interp1 fails.
%
%   This never surfaced before because every curve was a Monte-Carlo
%   estimate, where two consecutive values are never exactly equal. It
%   appeared the moment the exactly computed AWGN curves for idealized
%   beamforming (miSisoAwgnQuant.m) were used - the crash is a consequence
%   of their exactness, not of an error in them.
%
%   Of a plateau the FIRST entry is kept, i.e. the lowest SNR at which
%   that SE is reached. Keeping a later one would claim the system needs
%   more transmit power for the same rate than it does.
%
%   The filter compares against the RUNNING MAXIMUM of the already kept
%   points, not against the immediate predecessor. A predecessor
%   comparison (diff > 0) is not enough: in a dip 5, 4, 5 the 4 is
%   dropped, but the second 5 counts as a rise ABOVE THE 4 and is kept -
%   landing next to the first 5, which is the duplicate interp1 refuses.
%   MC-estimated curves have exactly those dips, so this case is the
%   common one, not the exotic one.
end_idx = find(SE_vec==max(SE_vec),1);
start_idx = find(SE_vec,1,'first');
SE_vec = SE_vec(start_idx:end_idx);
SNR_vec = SNR_vec(start_idx:end_idx);

% Jeden Punkt behalten, der STRIKT ueber allen vorherigen behaltenen
% liegt. Das Ergebnis ist streng monoton steigend, per Konstruktion und
% fuer jede Eingabe -- Plateau (exakte Kurven) und Delle (MC-Kurven)
% fallen damit in einem Durchgang weg.
v = SE_vec(:).';
runMax = cummax(v);
keep = [true, v(2:end) > runMax(1:end-1)];
if ~all(keep)
    SE_vec = SE_vec(keep);
    SNR_vec = SNR_vec(keep);
end
end
