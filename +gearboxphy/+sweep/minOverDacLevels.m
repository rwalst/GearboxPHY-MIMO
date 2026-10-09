function [best, kIdx, varargout] = minOverDacLevels(E, varargin)
%MINOVERDACLEVELS The ONE place where the cheapest DAC level is picked.
%   Curves that contain the DAC quantisation exist once per DAC level
%   (1/2*log2(M) + k bit, docs/DAC_QUANTISATION_SPEC.md). A finer DAC needs
%   less transmit power and costs more DAC power; the Gearbox pays exactly
%   the resolution of the curve it uses and takes the cheapest level.
%
%   [best, kIdx] = minOverDacLevels(E)
%   [best, kIdx, A1, A2, ...] = minOverDacLevels(E, A1, A2, ...)
%     E      energy per bit, any shape, the LAST dimension runs over the
%            DAC levels; NaN = infeasible.
%     best   minimum over the levels (NaN where no level is feasible)
%     kIdx   index of the chosen level along the last dimension (NaN there)
%     A*     further arrays of the same size as E, reduced with the SAME
%            choice (e.g. the DAC share, the transmit energy).
%
%   Used by studies/analog_bf/run_dbf_dac_distance.m; the BF vs. MUX study
%   is meant to call it too, so that both treat the levels alike.
sz = size(E);
nK = sz(end);
nd = numel(sz);
flat = reshape(E, [], nK);
feasible = ~all(isnan(flat), 2);
[bestCol, kCol] = min(flat, [], 2, 'omitnan');
bestCol(~feasible) = NaN;
kCol = double(kCol);
kCol(~feasible) = NaN;
if nd == 2, outSz = [sz(1) 1]; else, outSz = sz(1:end-1); end
if isscalar(outSz), outSz = [outSz 1]; end
best = reshape(bestCol, outSz);
kIdx = reshape(kCol, outSz);
varargout = cell(1, numel(varargin));
rows = (1:size(flat, 1)).';
for i = 1:numel(varargin)
    assert(isequal(size(varargin{i}), sz), 'gearboxphy:minOverDacLevels:size', ...
        'Argument %d has a different size than E.', i + 1);
    a = reshape(varargin{i}, [], nK);
    col = nan(size(bestCol));
    col(feasible) = a(sub2ind(size(a), rows(feasible), kCol(feasible)));
    varargout{i} = reshape(col, outSz);
end
end
