function run_newhw_w2()
%RUN_NEWHW_W2  Wrapper 2 von 4: Neurechnung mit den NEUEN Hardwaremodellen.
%
%   Aufruf: in GearboxPHY-MIMO/ einfach
%       setupGearboxPath; run_newhw_w2
%
%   RESSOURCEN: 100 Kerne, 64 GB. Eine MATLAB-Sitzung.
%
%   INHALT, in dieser Reihenfolge:
%     1. 3a fuer bf_fixedB und bfideal_fixedB, je 3 Distanzen  (6 Laeufe)
%     2. run_dbf_dac_distance                                  (66 Dateien)
%
%   DIE BEIDEN BF-SEITEN LIEGEN HIER, die beiden MUX-Seiten in Wrapper 1.
%   Die Teilung ist nicht beliebig: 3a schreibt je Variante und Distanz in
%   einen EIGENEN Ordner (cmp_<variante>_d<d>), zwei Sitzungen kommen sich
%   also nicht in die Quere, solange sie verschiedene Varianten bekommen.
%   Vier gleiche Haelften waeren schoener, aber es sind fuenf Varianten --
%   die fuenfte (mux_alphabetB) liegt in Wrapper 3.
%
%   WARUM DIE DAC-STUDIE HIER: sie ist mit 66 Dateien die groesste der vier
%   Distanzstudien und gehoert damit hinter den 3a-Teil, der die 100 Kerne
%   ohnehin fuellt. Sie selbst nutzt 25 (ein Worker je Distanz).
%
%   ACHTUNG, der alte Lauf ist zu verwerfen: run_dbf_dac_distance lief am
%   2026-10-15 schon einmal mit dem ALTEN Modellsatz (Stand etwa 31 von 66).
%   Diese Dateien werden nicht uebersprungen -- ihr resultFingerprint passt
%   seit PR #4 nicht mehr, sie werden neu gerechnet und ueberschrieben.
%
%   Gesamtaufteilung der 500 Kerne: docs/HPC_RUNBOOK_NEWHW.md.
setenv('GEARBOXPHY_WORKERS', '100');

jobs = { ...
    {'3a: bf_fixedB + bfideal_fixedB, 3 Distanzen', ...
     @() run_mimo_comparison_sweep(["bf_fixedB" "bfideal_fixedB"])}, ...
    {'DAC-Aufloesung ueber die Distanz (66 Dateien)', ...
     @() run_dbf_dac_distance()} ...
};
run_newhw_runner("Wrapper 2 von 4", 100, jobs);
end
