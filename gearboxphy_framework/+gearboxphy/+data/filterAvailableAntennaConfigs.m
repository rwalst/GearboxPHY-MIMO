function available = filterAvailableAntennaConfigs(gearName, order, candidates, dataDir)
%FILTERAVAILABLEANTENNACONFIGS Drops antenna-config candidates whose
%   SE_data file doesn't exist for this specific order, warning once per
%   dropped candidate rather than erroring.
%
%   MIMO SE_data is externally supplied per order (MIMO_EXTENSION.md
%   decision 3) - a scenario enabling e.g. a 2x2 config globally will
%   realistically only have matching curve files for SOME orders (e.g.
%   16-QAM and 64-QAM but not yet 4/256/1024-QAM). Treating a missing
%   MIMO curve as a hard error would make partial MIMO data unusable for
%   an entire sweep; treating it as a silent skip would hide a genuine
%   typo the same way the pre-rewrite codebase's silent per-point skips
%   did. This is the "missing vs corrupted" distinction from the earlier
%   code-review round (finding #2), applied here too: a MISSING file is
%   expected/skippable (with a visible warning naming exactly what's
%   missing); any OTHER problem (a corrupted or malformed file) is left
%   to surface as a real error when the file is actually loaded.
%
%   The SISO candidate (N_t=N_r=1) is never dropped - its SE_data file is
%   guaranteed to exist by construction (loadSECurve.m's SISO branch
%   reuses the original, already-present filename).
available = {};
for i = 1:numel(candidates)
    candidate = candidates{i};
    [filename, isSISO] = gearboxphy.data.seCurveFilename(gearName, order, candidate, dataDir);
    if isSISO || isfile(filename)
        available{end+1} = candidate; %#ok<AGROW>
    else
        warning('gearboxphy:mimoCurveMissing', ...
            '%s order=%g: no SE_data curve for antenna config %dx%d (expected %s) - skipping this candidate for this order.', ...
            gearName, order, candidate.N_t, candidate.N_r, filename);
    end
end
end
