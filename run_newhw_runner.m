function run_newhw_runner(who, cores, jobs)
%RUN_NEWHW_RUNNER  Gemeinsamer Ablauf der vier Wrapper run_newhw_w1..w4.
%
%   run_newhw_runner("Wrapper 1 von 4", 100, jobs)
%     jobs  Zellarray, je Eintrag {Beschriftung, Funktionshandle}
%
%   Liegt EINMAL hier und nicht viermal in den Wrappern: die Wrapper sollen
%   nur noch sagen, WAS sie starten und mit wie vielen Kernen.
%
%   ZWEI DINGE, DIE DER RUNNER LEISTEN MUSS:
%
%   1. EIN FEHLGESCHLAGENER LAUF DARF DIE UEBRIGEN NICHT MITNEHMEN. Die
%      Laeufe sind voneinander unabhaengig, und ein Abbruch am ersten waere
%      sonst ein Abbruch an allen -- bei Laufzeiten in Stunden ist das der
%      Unterschied zwischen einer Nacht und einer Woche. Deshalb je Lauf ein
%      try/catch und am Ende eine Tabelle, damit man nach Stunden nicht im
%      Protokoll suchen muss.
%
%   2. SKRIPTE BRAUCHEN EINE LOKALE HUELLE, und das ist kein Zierrat. Auf ein
%      Skript gibt es in MATLAB kein Funktionshandle; die Wrapper verpacken
%      ihre Skript-Treiber deshalb in lokale Funktionen. Das hat einen
%      zweiten Nutzen: run_beamforming_sweep, _allgears, _distance_sweep und
%      run_hw_comparison lesen VARIANTS, USE_PARALLEL, HW_CFG und QUICK aus
%      dem Workspace, in dem sie laufen. In einer lokalen Huelle ist dieser
%      Workspace leer, also greifen ihre eigenen Vorgaben. Vom Basis-
%      Workspace aus gerufen wuerden sie einen Rest aus einem anderen Skript
%      uebernehmen -- genau so entstand am 2026-10-15 der Fehler
%      "Unknown variant mux_fixedB" in run_hw_comparison.
arguments
    who (1,1) string
    cores (1,1) double {mustBePositive}
    jobs (1,:) cell
end
fprintf('\n');
fprintf('========================================================\n');
fprintf('  %s -- neue Hardwaremodelle\n', who);
fprintf('  GEARBOXPHY_WORKERS = %s (Anteil dieser Sitzung)\n', getenv('GEARBOXPHY_WORKERS'));
fprintf('  Kerne laut Aufteilung: %d von 500\n', cores);
fprintf('  Start: %s\n', string(datetime('now')));
fprintf('========================================================\n');

tAll = tic;
res = struct('name', {}, 'ok', {}, 'min', {}, 'err', {});
for k = 1:numel(jobs)
    name = string(jobs{k}{1}); fcn = jobs{k}{2};
    fprintf('\n-------- [%d/%d] %s --------\n', k, numel(jobs), name);
    t0 = tic; ok = true; msg = "";
    try
        fcn();
    catch err
        ok = false;
        msg = string(err.identifier) + ": " + string(err.message);
        fprintf(2, '\n!! %s ABGEBROCHEN: %s\n', name, msg);
    end
    res(end+1) = struct('name', name, 'ok', ok, 'min', toc(t0)/60, 'err', msg); %#ok<AGROW>
    if ok, stat = "fertig"; else, stat = "FEHLER"; end
    fprintf('-------- [%d/%d] %s: %s nach %.1f min --------\n', ...
        k, numel(jobs), name, stat, toc(t0)/60);
end

fprintf('\n==================== Zusammenfassung ====================\n');
fprintf('  %s\n', who);
for k = 1:numel(res)
    if res(k).ok, stat = "ok    "; else, stat = "FEHLER"; end
    fprintf('  %s %8.1f min  %s\n', stat, res(k).min, res(k).name);
    if ~res(k).ok, fprintf('                    %s\n', res(k).err); end
end
nBad = sum(~[res.ok]);
fprintf('  ----\n  %d von %d fertig, Gesamtdauer %.2f h\n', ...
    numel(res) - nBad, numel(res), toc(tAll)/3600);
if nBad > 0
    fprintf(2, ['  %d Lauf/Laeufe fehlgeschlagen. Wrapper einfach erneut starten: ' ...
                'Fertiges wird uebersprungen (nur bei passendem resultFingerprint).\n'], nBad);
end
fprintf('=========================================================\n');
end
