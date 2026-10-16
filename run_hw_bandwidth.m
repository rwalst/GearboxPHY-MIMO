function run_hw_bandwidth()
%RUN_HW_BANDWIDTH  SISO-Vergleich alte gegen neue Bandbreitenannahme.
%
%   Aufruf: in GearboxPHY-MIMO/ einfach
%       setupGearboxPath; run_hw_bandwidth
%
%   RESSOURCEN: 100 Kerne, 64 GB. Eine MATLAB-Sitzung.
%   Vier Varianten, davon zwei schon gerechnet (s. u.), also real zwei.
%   Nach der Messung vom 2026-10-16 -- der komplette Neurechnungssatz ausser
%   SISO in unter 5 h -- sind das Minuten bis wenige Stunden.
%
%   DIE FRAGE. Der neue Modellsatz deckelt die Bandbreite auf EINEN Kanal
%   (bandwidthModel "channel": 20 / 100 / 400 MHz bei 2,4 / 8 / 28 GHz)
%   statt auf 0,1*f_c ("eta": 240 / 800 / 2800 MHz). Das ist der einzige
%   Unterschied des Satzes, der nicht nur Leistung kostet, sondern
%   ARBEITSPUNKTE WEGNIMMT: gemessen am 2026-10-16 ist 1 Gbit/s bei 2,4 und
%   8 GHz damit gar nicht mehr erreichbar, und bei 28 GHz 10 Gbit/s. Was
%   also kostet der Deckel, und laesst er sich von den Bauteilmodellen
%   trennen?
%
%   VIER VARIANTEN, ZWEI ISOLATIONEN:
%     old      alter Satz, alte Bandbreite      (Bezug, cfg.reference)
%     new      neuer Satz, neue Bandbreite
%     bw_only  ALTER Satz, neue Bandbreite   -> Effekt auf altem Untergrund
%     bw_old   NEUER Satz, alte Bandbreite   -> Effekt auf neuem Untergrund
%
%   SO IST DIE TABELLE ZU LESEN. analyze_hw_comparison gibt ratioToRef, also
%   E_bit der Variante geteilt durch E_bit von "old". Der Bandbreiteneffekt
%   ist deshalb
%       auf altem Untergrund   ratio(bw_only)
%       auf neuem Untergrund   ratio(new) / ratio(bw_old)
%   Stimmen die beiden ueberein, ist der Deckel von den Bauteilmodellen
%   trennbar und darf einzeln zitiert werden. Weichen sie ab, wirken sie
%   zusammen, und dann gilt nur die Aussage ueber den ganzen Satz.
%
%   old und new liegen aus dem Lauf vom 2026-10-16 schon vor. Beide werden
%   uebersprungen: hw_comparison_prepare_dir erkennt den passenden Stempel
%   und runSweep den passenden resultFingerprint. Sie stehen trotzdem in der
%   Liste, damit die Auswertung alle vier Spalten in EINER Abbildung hat.
%
%   RASTER (hw_comparison_config.m): SISO, d = 50 m, Traeger 2,4 / 8 /
%   28 GHz, 100 Raten von 1 kbit/s bis 100 Gbit/s, alle Gaenge.
%
%   AUSGABE: results/hardware_models_newhw/siso_<variante>_d50/, danach
%   analyze_hw_comparison fuer Abbildungen und summary.csv.
setenv('GEARBOXPHY_WORKERS', '100');
localRun();
fprintf('\nFertig. Jetzt auswerten:  analyze_hw_comparison\n');
end

% =====================================================================
function localRun()
%LOCALRUN  Huelle mit eigenem Workspace.
%   run_hw_comparison ist ein SKRIPT und liest VARIANTS, USE_PARALLEL und
%   HW_CFG aus dem Workspace, in dem es laeuft. Hier werden sie gesetzt, und
%   zwar in einer lokalen Funktion -- nicht im Basis-Workspace. Dort haben
%   drei mimo_comparison-Skripte dieselbe Variable mit ihren eigenen Namen
%   belegt, und genau daran brach der Lauf am 2026-10-15 mit
%   "Unknown variant mux_fixedB" ab.
VARIANTS     = ["old" "new" "bw_only" "bw_old"]; %#ok<NASGU>
USE_PARALLEL = true;                             %#ok<NASGU>
run_hw_comparison;
end
