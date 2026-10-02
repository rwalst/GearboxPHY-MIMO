function lna_comparison_prepare_dir(c)
%LNA_COMPARISON_PREPARE_DIR  Create c.dir and pin it to c.stamp, or verify
%   that an existing directory belongs to exactly this case.
%
%   Errors (never overwrites) if
%     - the directory holds a stamp for a DIFFERENT case, or
%     - it already holds result files but no stamp (origin unknown).
%   Otherwise a resumed run simply continues: runSweep skips finished
%   combos and reuses point checkpoints.
stampFile = fullfile(c.dir, 'lna_stamp.mat');
if isfile(stampFile)
    S = load(stampFile, 'stamp');
    if ~isequal(S.stamp, c.stamp)
        error('lna:stampMismatch', ...
            ['%s belongs to a different case than %s (LNA model, B_max, ' ...
             'distance, rates or antenna configs differ). Move or delete it.'], c.dir, c.name);
    end
    return
end
if isfolder(c.dir) && ~isempty(dir(fullfile(c.dir, '*.mat')))
    error('lna:unstampedResults', ...
        '%s already contains results without lna_stamp.mat - origin unknown. Move or delete it.', c.dir);
end
if ~isfolder(c.dir), mkdir(c.dir); end
stamp = c.stamp; %#ok<NASGU>
save(stampFile, 'stamp');
end
