function bw = obw(varargin)
%OBW TEST-ONLY STUB. The real obw() (Signal Processing Toolbox) is not
%   available in this sandbox (confirmed: `ver` lists no toolboxes beyond
%   base MATLAB). Production use of this framework genuinely requires the
%   real Signal Processing Toolbox - this stub exists solely so the
%   golden-master suite can exercise containmentBandwidth/
%   containmentBandwidthZXM's surrounding logic (the memoization, the
%   PSD construction, the ZXM eigenvalue math) identically on both the
%   old and new code paths, which is all a parity test needs: the same
%   stub is on the path for both sides, so any numeric drift caught by
%   the comparison is real, not an artifact of this stub's specific
%   value. Never add this shim's folder to a real run's MATLAB path.
bw = 1.35;
end
