function available = filterAvailableAntennaConfigs(gearName, order, candidates, dataDir)
%FILTERAVAILABLEANTENNACONFIGS Drops antenna-config candidates whose
%   SE_data file doesn't exist for this specific order, warning once per
%   dropped candidate rather than erroring.
%
%   MIMO SE_data is externally supplied per order (MIMO_EXTENSION.md
%   decision 3) - a scenario enabling e.g. a 2x2 config globally will
%   realistically only have matching curve files for SOME orders (e.g.
%   16-QAM and 64-QAM but not yet 4/256/1024-QAM). Treating a missing
%   MIMO curve as a hard error would make partial MIMO data unusable for
%   an entire sweep; treating it as a silent skip would hide a genuine
%   typo the same way the pre-rewrite codebase's silent per-point skips
%   did. This is the "missing vs corrupted" distinction from the earlier
%   code-review round (finding #2), applied here too: a MISSING file is
%   expected/skippable (with a visible warning naming exactly what's
%   missing); any OTHER problem (a corrupted or malformed file) is left
%   to surface as a real error when the file is actually loaded.
%
%   The SISO candidate (N_t=N_r=1) is never dropped - its SE_data file is
%   guaranteed to exist by construction (loadSECurve.m's SISO branch
%   reuses the original, already-present filename).
%
%   ZWEI UNABHAENGIGE PRUEFUNGEN, und das ist kein Zierrat (E7, beobachtet
%   am 2026-10-15 in einem echten Lauf von run_dbf_dac_distance): diese
%   Funktion laeuft ueber gear.antennaConfigs INNERHALB des parfor, also auf
%   einem Worker gegen den UNC-Share. Bei 25 Distanzen x 4 Ordnungen x 5
%   Kandidaten sind das 500 isfile-Aufrufe je Fall und rund 157 000 je
%   Vollauf. Auf einer SMB-Freigabe schlaegt davon gelegentlich einer fehl,
%   OBWOHL die Datei da ist -- gemeldet wurde genau das fuer
%   SE_data_bfideal_fixedB_dac0/SE_64_QAM_2x2.mat, die im Repo seit dem
%   2026-10-12 liegt.
%
%   Was ein solcher Aussetzer anrichtet, ist der Grund fuer den Aufwand: der
%   Kandidat wird verworfen, die Zelle (M,N) bleibt NaN, und die Datei sieht
%   vollstaendig aus. Die Huellkurve ueber (M,N) nimmt dann still eine
%   Konfiguration weniger.
%
%   Deshalb wird erst EINE Verzeichnisliste je Ordner geholt (gecacht, also
%   ein Share-Zugriff statt 20 je Aufruf) und ein Kandidat nur dann
%   verworfen, wenn AUCH ein direktes isfile ihn nicht findet. Ein
%   voruebergehender Fehlschlag in einer der beiden Pruefungen kostet damit
%   keine Zelle mehr. Fehlt die Kurve wirklich, sagen beide dasselbe.
available = {};
for i = 1:numel(candidates)
    candidate = candidates{i};
    [filename, isSISO] = gearboxphy.data.seCurveFilename(gearName, order, candidate, dataDir);
    if isSISO
        available{end+1} = candidate; %#ok<AGROW>
        continue
    end
    [~, base, ext] = fileparts(filename);
    inListing = any(strcmp([base ext], localListing(dataDir)));
    if inListing || isfile(filename)
        available{end+1} = candidate; %#ok<AGROW>
    else
        warning('gearboxphy:mimoCurveMissing', ...
            ['%s order=%g: no SE_data curve for antenna config %dx%d (expected %s) - ' ...
             'skipping this candidate for this order. Weder die Verzeichnisliste ' ...
             'noch isfile finden sie, es ist also kein Share-Aussetzer.'], ...
            gearName, order, candidate.N_t, candidate.N_r, filename);
    end
end
end

function names = localListing(dataDir)
%LOCALLISTING  Dateinamen eines Kurvenordners, je Ordner einmal geholt.
%
%   Der Cache ist je Prozess, also je Worker -- genau richtig: er nimmt die
%   Last vom Share, ohne dass ein Lauf den Stand eines anderen sieht. Ein
%   Export, der waehrend eines Sweeps Kurven nachlegt, waere ohnehin ein
%   Fehler (und localUpToDate in den Studien faengt ihn ab).
persistent cache
if isempty(cache)
    cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
end
key = char(dataDir);
if ~isKey(cache, key)
    f = dir(fullfile(key, 'SE_*.mat'));
    cache(key) = {f.name};
end
names = cache(key);
end
