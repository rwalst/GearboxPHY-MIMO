function run_newhw_w4()
%RUN_NEWHW_W4  Wrapper 4 von 4: Neurechnung mit den NEUEN Hardwaremodellen.
%
%   Aufruf: in GearboxPHY-MIMO/ einfach
%       setupGearboxPath; run_newhw_w4
%
%   RESSOURCEN: 200 Kerne, 64 GB. Eine MATLAB-Sitzung.
%
%   INHALT, in dieser Reihenfolge:
%     1. run_sweep                      SISO-Grundsweep (results/main)
%     2. run_beamforming_sweep          Beamforming-Vorlaeufer
%     3. run_beamforming_allgears
%     4. run_beamforming_distance_sweep
%     5. run_siso_vs_mimo_scaledB       SISO gegen MIMO, aufgeloest nach N
%     6. run_dac_model_siso             DAC-Leistungsmodelle, SISO
%     7. run_lna_comparison             LNA-Modelle            (s. STEMPEL)
%     8. run_hw_comparison              alter gegen neuer Satz (s. STEMPEL)
%
%   WARUM DIESER WRAPPER 200 KERNE BEKOMMT UND DIE ANDEREN 100: run_sweep
%   hat 400 Ratenpunkte (run_sweep.m:9), runSweep nimmt
%   min(numel(RVec), maxCores) und maxCores ist 200 -- das ist der einzige
%   Lauf im ganzen Satz, der ueber 100 Worker hinaus noch schneller wird.
%   Die uebrigen sieben Laeufe hier nutzen 100 (Ratenachse) bzw. weniger.
%   Aufteilung: 100 + 100 + 100 + 200 = 500.
%
%   WARUM DIE SKRIPTE IN LOKALE HUELLEN VERPACKT SIND -- zwei Gruende, beide
%   zwingend. Erstens gibt es auf ein Skript kein Funktionshandle. Zweitens
%   lesen run_beamforming_sweep, _allgears, _distance_sweep und
%   run_hw_comparison die Variablen VARIANTS, USE_PARALLEL, HW_CFG und QUICK
%   aus dem Workspace, in dem sie laufen. In einer lokalen Huelle ist der
%   leer, also greifen ihre eigenen Vorgaben. Direkt aus dem Basis-Workspace
%   gerufen wuerden sie einen Rest aus einem anderen Skript uebernehmen --
%   genau so entstand am 2026-10-15 "Unknown variant mux_fixedB".
%
%   STEMPEL: run_lna_comparison UND run_hw_comparison BRECHEN AB, solange die
%   alten Ergebnisordner liegen. Beide binden jeden Ordner per Stempeldatei
%   an seinen Fall und verweigern einen Ordner mit abweichendem Stempel
%   (hw:stampMismatch bzw. lna:stampMismatch) -- absichtlich, damit nie ein
%   Ordner zwei Modellsaetze vermischt. PR #4 hat beide Stempel um adc, dac,
%   lo und bandwidth erweitert, die vorhandenen 18 LNA- und 2
%   Hardware-Ordner tragen also den alten. Sie werden NICHT automatisch
%   gelaeoscht; der Wrapper nennt sie beim Start, und das Verschieben oder
%   Loeschen ist eine Entscheidung. Deshalb stehen diese zwei Laeufe am ENDE:
%   wer sie noch nicht aufgeraeumt hat, verliert dadurch keine Rechenzeit.
%
%   Gesamtaufteilung der 500 Kerne: docs/HPC_RUNBOOK_NEWHW.md.
setenv('GEARBOXPHY_WORKERS', '200');
localWarnStaleStamps();

jobs = { ...
    {'SISO-Grundsweep (results/main, 400 Ratenpunkte)', @localSweep}, ...
    {'Beamforming-Sweep',                              @localBfSweep}, ...
    {'Beamforming, alle Gaenge',                       @localBfAllGears}, ...
    {'Beamforming ueber die Distanz',                  @localBfDistance}, ...
    {'SISO gegen MIMO, aufgeloest nach N',             @localSisoVsMimo}, ...
    {'DAC-Leistungsmodelle, SISO',                     @() run_dac_model_siso()}, ...
    {'LNA-Modellvergleich',                            @localLna}, ...
    {'Hardwaremodelle alt gegen neu',                  @localHwComparison} ...
};
run_newhw_runner("Wrapper 4 von 4", 200, jobs);
end

% ===================== lokale Huellen fuer die Skripte ================
% Jede Huelle hat einen LEEREN Workspace -- das ist der Punkt, s. Kopf.
function localSweep(),         run_sweep;                      end
function localBfSweep(),       run_beamforming_sweep;          end
function localBfAllGears(),    run_beamforming_allgears;       end
function localBfDistance(),    run_beamforming_distance_sweep; end
function localSisoVsMimo(),    run_siso_vs_mimo_scaledB;       end
function localLna(),           run_lna_comparison;             end
function localHwComparison(),  run_hw_comparison;              end

% =====================================================================
function localWarnStaleStamps()
%LOCALWARNSTALESTAMPS  Vor dem ersten Lauf sagen, was spaeter abbricht.
%   Prueft NICHT den Stempelinhalt (dafuer muesste jeder Fall gebaut
%   werden), sondern nur, ob ueberhaupt gestempelte Altordner liegen. Das
%   genuegt: PR #4 hat beide Stempel erweitert, ein Ordner von vorher kann
%   also nicht passen.
%   DIE WURZEL KOMMT AUS DER CONFIG, nicht aus einem festen Namen. Sobald
%   Branch newhw-result-roots drin ist, zeigen lna_comparison_config und
%   hw_comparison_config auf results/lna_newhw/ bzw.
%   results/hardware_models_newhw/ -- dann sind dort keine Altordner, die
%   Warnung verstummt von selbst, und die 22 alten bleiben als Referenz
%   liegen. Ein fester Name haette hier weiter gewarnt, obwohl nichts mehr
%   blockiert.
%
%   ZWEISTUFIG STATT dir(... '*' ... 'stamp.mat'): ein Platzhalter MITTEN im
%   Pfad ist nichts, worauf man sich ueber Windows und Posix hinweg verlassen
%   sollte. Erst die Unterordner auflisten, dann je Ordner ein isfile -- das
%   verhaelt sich auf beiden Plattformen gleich, und fullfile setzt den
%   Trenner ohnehin richtig.
stale = strings(0);
cfgs = {lna_comparison_config(), 'lna_stamp.mat'; hw_comparison_config(), 'hw_stamp.mat'};
for i = 1:size(cfgs, 1)
    root = cfgs{i, 1}.root; stampName = cfgs{i, 2};
    if ~isfolder(root), continue; end
    d = dir(root);
    for k = 1:numel(d)
        if ~d(k).isdir || startsWith(d(k).name, '.'), continue; end
        if isfile(fullfile(root, d(k).name, stampName))
            stale(end+1) = string(fullfile(root, d(k).name)); %#ok<AGROW>
        end
    end
end
if isempty(stale), return; end
f = stale;
fprintf(2, '\n');
fprintf(2, '!! %d gestempelte Altordner gefunden. Die Laeufe 7 und 8 brechen daran ab\n', numel(f));
fprintf(2, '!! (hw:stampMismatch / lna:stampMismatch), weil PR #4 die Stempel um adc,\n');
fprintf(2, '!! dac, lo und bandwidth erweitert hat. Die uebrigen sechs Laeufe sind nicht\n');
fprintf(2, '!! betroffen und laufen durch. Zum Aufraeumen -- EIGENE ENTSCHEIDUNG, der\n');
fprintf(2, '!! Wrapper loescht nichts:\n');
for k = 1:min(numel(f), 4)
    fprintf(2, '!!     %s\n', f(k));
end
if numel(f) > 4
    fprintf(2, '!!     ... und %d weitere\n', numel(f) - 4);
end
fprintf(2, '!! Verschieben (empfohlen, der alte Satz bleibt als Vergleichsarm erhalten)\n');
fprintf(2, '!! oder loeschen; danach Wrapper 4 erneut starten. Besser noch: Branch\n');
fprintf(2, '!! newhw-result-roots mergen -- der neue Satz bekommt dann eigene Wurzeln\n');
fprintf(2, '!! und die Altordner bleiben unangetastet als Referenz liegen.\n\n');
end
