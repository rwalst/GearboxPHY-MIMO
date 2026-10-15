function publishToStore(fp, srcFile)
%PUBLISHTOSTORE  Put a finished result file into the store under its key.
%
%   gearboxphy.data.publishToStore(fp, srcFile)
%
%   Copies rather than moves or links: the study folder keeps its own file,
%   so every analysis keeps working unchanged, and a deleted store costs
%   nothing but the next run's time. Symbolic links would be the tidier
%   answer on Linux and are not portable to the Windows cluster share.
%
%   Never fails the run. A full disk or a read-only store is a reason to
%   lose the SAVING, not the result that was just computed - hence a warning
%   and a return, not an error.
arguments
    fp (1,1) string
    srcFile (1,1) string
end
if strlength(fp) == 0, return; end   % kein Schluessel, nichts zu speichern
if ~isfile(srcFile)
    warning('gearboxphy:data:publishMissingSource', ...
        'Nothing to publish: %s does not exist.', srcFile);
    return
end
d = gearboxphy.data.storeDir();
try
    if ~isfolder(d), mkdir(d); end
    dest = fullfile(d, fp + ".mat");
    if isfile(dest), return; end      % schon da: der erste Lauf hat gewonnen
    % Over a temporary name first, then rename: a run killed by the
    % walltime in the middle of the copy must not leave a TRUNCATED file
    % behind under a key that the next run would then trust.
    tmp = fullfile(d, fp + sprintf(".tmp%d", feature('getpid')));
    copyfile(srcFile, tmp);
    movefile(tmp, dest);
catch err
    warning('gearboxphy:data:publishFailed', ...
        'Could not publish %s to the store (%s) - the result itself is safe.', ...
        srcFile, err.message);
end
end
