function hit = fetchFromStore(fp, destFile)
%FETCHFROMSTORE  Take a result another run already computed, instead of
%   computing it again.
%
%   hit = gearboxphy.data.fetchFromStore(fp, destFile)
%
%   Returns true and places the file at destFile when the store has this
%   key; returns false and does nothing otherwise. The caller then skips the
%   whole combo - see runSweep.m.
%
%   WHAT MAKES THIS SAFE: the key comes from comboFingerprint, which hashes
%   the complete input of the optimisation (ctx, RVec, optParams, x0,
%   bounds). A hit therefore means the stored file is what this run would
%   have computed, up to the unseeded optimiser's own spread - the same
%   spread two consecutive identical runs show anyway (0.42 % in E_bit,
%   measured by the golden master).
%
%   A reused file also REMOVES that spread between variants: today the six
%   3a variants carry six slightly different numbers for the very same SISO
%   gear, which is noise in any plot that puts them side by side.
arguments
    fp (1,1) string
    destFile (1,1) string
end
hit = false;
% Leerer Schluessel: der Aufrufer konnte ihn nicht bilden (z.B. fehlt ein
% Kurvenordner). Der Speicher ist eine Beschleunigung, kein Tor -- dann
% wird eben gerechnet.
if strlength(fp) == 0, return; end
src = fullfile(gearboxphy.data.storeDir(), fp + ".mat");
if ~isfile(src), return; end
try
    destDir = fileparts(destFile);
    if ~isempty(destDir) && ~isfolder(destDir), mkdir(destDir); end
    copyfile(src, destFile);
    hit = true;
catch err
    % Could not copy: fall through to computing it. Never fatal.
    warning('gearboxphy:data:fetchFailed', ...
        'Store hit for %s but the copy failed (%s) - computing instead.', ...
        fp, err.message);
    hit = false;
end
end
