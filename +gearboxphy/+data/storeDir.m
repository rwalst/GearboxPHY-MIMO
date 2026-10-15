function d = storeDir()
%STOREDIR  Where results are kept ONCE, keyed by fingerprint.
%
%   d = gearboxphy.data.storeDir()      % <results>/_store
%
%   Sits under the results root, so GEARBOXPHY_RESULTS_ROOT moves it along
%   with everything else (ZIH workspace, see docs/HPC_RUNBOOK_ZIH.md).
%
%   THE NAME STARTS WITH AN UNDERSCORE so it cannot be mistaken for a study
%   folder: every analysis globs either `cmp_*`, `abf_*` or an explicit
%   name, and none of those match `_store`. No dots anywhere - a dot in a
%   directory name is what broke checkpointing on the UNC share once
%   already (see +data/checkpointDir.m).
d = gearboxphy.paths.resultsDir('_store');
end
