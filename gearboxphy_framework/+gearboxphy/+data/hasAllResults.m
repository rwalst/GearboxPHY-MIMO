function tf = hasAllResults(resultsDir, key, RVec, distance, antennaConfigs)
%HASALLRESULTS True if a complete, up-to-date result table already exists
%   for this key (matched on the exact RVec/distance/antennaConfigs it
%   was computed for). Used by runSweep to skip an entire gear/order/
%   carrier combo rather than checking per-point existence - see
%   ARCHITECTURE_PLAN.md section 5.2/5.3 for why results are consolidated
%   into one file per (gear, order, carrier) instead of one file per
%   point, and why the compute-then-single-save design (see
%   optimizeOnePoint.m/runSweep.m) avoids the concurrent-write race that
%   a per-R parfor would otherwise have against a shared table file.
%
%   antennaConfigs (the resolved candidate list for THIS combo, i.e.
%   gear.antennaConfigs(order,cs) - {struct('N_t',1,'N_r',1)} for every
%   non-QAM gear, the scenario's qamMimoConfigs filtered to what SE_data
%   actually has for QAM) is checked too: resultKey.m deliberately does
%   NOT encode it (keeps the on-disk filename, and every +report/*.m
%   caller of it, stable regardless of which antenna configs were
%   swept), so without this check a result computed under one
%   qamMimoConfigs would be silently kept - and the whole combo skipped -
%   after the scenario's qamMimoConfigs changed but RVec/distance didn't
%   (exactly what happens the moment MIMO is enabled on a results/ folder
%   that already has SISO-only .mat files in it, e.g. from a run before
%   MIMO_EXTENSION.md's candidates were passed in). A file saved before
%   this field existed has no antennaConfigsUsed at all - treated as
%   stale (forces a recompute) rather than erroring, so nothing needs
%   deleting by hand to pick up the fix.
file = fullfile(resultsDir, key + ".mat");
if ~isfile(file)
    tf = false;
    return
end
% matfile() rather than load(file,'antennaConfigsUsed',...) so a file
% saved before this field existed doesn't print a spurious "Variable not
% found" warning on every stale-format file a sweep encounters.
mf = matfile(file);
hasField = any(strcmp('antennaConfigsUsed', who(mf)));
S = load(file, 'RVec', 'distance');
tf = isequal(S.RVec, RVec) && isequal(S.distance, distance) ...
    && hasField && isequal(mf.antennaConfigsUsed, antennaConfigs);
end
