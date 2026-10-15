function out = interpolateNaN(in)
%INTERPOLATENAN Fills NaN gaps in each row of IN via linear interpolation
%   over the non-NaN samples. Ported verbatim from Wrapper.m's local
%   function of the same purpose (used there to smooth over infeasible
%   points before taking a per-rate argmin/plot).
out = NaN(size(in));
for i_ = 1:size(in,1)
    in_vec = in(i_,:);
    X = ~isnan(in_vec);
    if ~any(X)
        continue
    end
    if nnz(X) == 1
        % interp1 needs two samples. A row with a single feasible point
        % (frequent since B_max is one channel, 2026-10-15) keeps it as is.
        out(i_,:) = in_vec;
        continue
    end
    Y = cumsum(X-diff([1,X])/2);
    out(i_,:) = interp1(1:nnz(X), in_vec(X), Y);
end
end
