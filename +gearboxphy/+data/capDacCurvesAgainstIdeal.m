function stats = capDacCurvesAgainstIdeal(dacDir, refDir, dacName, refName)
%CAPDACCURVESAGAINSTIDEAL Clamp DAC-quantised SE curves to the ideal-DAC curve.
%
%   stats = capDacCurvesAgainstIdeal(dacDir, refDir, dacName, refName)
%
%   Every MIMO curve in dacDir is limited point by point to the curve of the
%   same name in refDir, which holds the SAME (M, N) computed with an IDEAL
%   DAC. Decision E4 in docs/MIMO_TODO.md.
%
%   WHY THIS EXISTS: a coarser DAC cannot raise the achievable SE, yet in the
%   raw curves it sometimes does. That is not an arithmetic error but a real
%   effect of the model - the rounding error decorrelates the streams and
%   looks to the MI estimator like a slice of multiplexing gain. It is not
%   harvestable by a receiver with a matched filter, so it must not enter the
%   Gearbox budget: there it would favour exactly the DAC level that rounds
%   the most, because minOverDacLevels picks the cheapest level per point.
%   Measured on bflosd/dac2: 247 of 1056 points sat above the ideal curve, up
%   to 0.0209 bit; on Rayleigh with M >= 64, N >= 4 up to 0.10 bit.
%
%   ONLY MIMO CURVES (SE_*_QAM_<N>x<N>.mat). The folder's SISO curve comes
%   from the 1x1 run, where Bdac is the ideal resolution anyway - with a
%   single stream no precoder rotates the symbol, so the DAC sees the plain
%   constellation. Clamping it would compare it against itself.
%
%   FILES ARE PAIRED BY NAME, not through seCurveFilename: this operates on
%   whatever a finished export wrote into the two folders, and does not
%   construct names from (gear, order, config). The names are identical by
%   construction because both folders come out of exportToGearboxSEData.
%
%   SNR AXES: the reference is interpolated linearly onto the DAC curve's
%   axis. Points outside the reference range are NOT clamped and are counted
%   as uncovered - an overshoot could sit there unseen, so it is quantified
%   rather than passed over.
%
%   Each touched file gains dacCapRef, dacCapPoints, dacCapMaxBit and
%   dacCapUncovered, so the clamp is readable off the result instead of only
%   being described here. A missing reference folder does NOT silently leave
%   the curves unclamped; it warns with export:noDacCapRef.
arguments
    dacDir  (1,1) string
    refDir  (1,1) string
    dacName (1,1) string
    refName (1,1) string
end
stats = struct('files', 0, 'points', 0, 'maxBit', 0, 'uncovered', 0, 'missingRef', 0);
f = dir(fullfile(dacDir, 'SE_*_QAM_*x*.mat'));
if isempty(f), return; end
if ~isfolder(refDir)
    warning('export:noDacCapRef', ...
        ['%s: reference folder %s is missing - curves stay UNCLAMPED. ' ...
         'Export the ideal-DAC folder first, then run this again.'], dacName, refName);
    return;
end
for i = 1:numel(f)
    refFile = fullfile(refDir, f(i).name);
    if ~isfile(refFile)
        stats.missingRef = stats.missingRef + 1;
        continue;
    end
    a = load(fullfile(dacDir, f(i).name), 'SE_vec', 'SNR_vec');
    b = load(refFile, 'SE_vec', 'SNR_vec');
    ref = interp1(b.SNR_vec, b.SE_vec, a.SNR_vec, 'linear', NaN);
    covered = ~isnan(ref);
    over = covered & (a.SE_vec > ref + 1e-12);

    dacCapRef       = char(refName);
    dacCapPoints    = sum(over);
    dacCapMaxBit    = max([0, a.SE_vec(over) - ref(over)]);
    dacCapUncovered = sum(~covered);
    if dacCapPoints > 0
        SE_vec = a.SE_vec;
        SE_vec(over) = ref(over);
        save(fullfile(dacDir, f(i).name), 'SE_vec', '-append');
        stats.files = stats.files + 1;
    end
    save(fullfile(dacDir, f(i).name), ...
        'dacCapRef', 'dacCapPoints', 'dacCapMaxBit', 'dacCapUncovered', '-append');
    stats.points    = stats.points + dacCapPoints;
    stats.maxBit    = max(stats.maxBit, dacCapMaxBit);
    stats.uncovered = stats.uncovered + dacCapUncovered;
end
fprintf('   clamped against %s: %d curves, %d points, max %.4f bit\n', ...
    refName, stats.files, stats.points, stats.maxBit);
if stats.uncovered > 0
    fprintf('   %d points outside the reference SNR axis, NOT clamped there\n', stats.uncovered);
end
if stats.missingRef > 0
    warning('export:dacCapRefIncomplete', ...
        '%s: reference missing for %d curves in %s - those stay unclamped.', ...
        dacName, stats.missingRef, refName);
end
end
