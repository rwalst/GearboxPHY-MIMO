function tf = isBaselineGear(gear)
%ISBASELINEGEAR True if this gear is the designated savings/argmin
%   baseline (currently NA-QAM) - checked via an explicit gear.isBaseline
%   field (set once, in naQamGear.m) rather than a hardcoded "NA-QAM"
%   name string duplicated independently across plotOptimalGearReport.m
%   and plotSavingsReport.m (code review finding #6: renaming the gear or
%   adding a second baseline-style gear used to require updating a
%   literal string in two places with no cross-check that they agreed).
tf = isfield(gear, 'isBaseline') && gear.isBaseline;
end
