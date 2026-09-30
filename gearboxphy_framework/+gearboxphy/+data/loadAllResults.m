function S = loadAllResults(resultsDir, key)
%LOADALLRESULTS Loads the consolidated result table for one
%   (gear, order, carrier) combo - one .mat/readtable-style load gets the
%   whole rate sweep, instead of reloading hundreds of tiny per-point
%   files as the original Wrapper.m did.
file = fullfile(resultsDir, key + ".mat");
S = load(file);
end
