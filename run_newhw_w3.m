function run_newhw_w3()
%RUN_NEWHW_W3  Wrapper 3 von 4: Neurechnung mit den NEUEN Hardwaremodellen.
%
%   Aufruf: in GearboxPHY-MIMO/ einfach
%       setupGearboxPath; run_newhw_w3
%
%   RESSOURCEN: 100 Kerne, 64 GB. Eine MATLAB-Sitzung.
%
%   INHALT, in dieser Reihenfolge:
%     1. 3b run_mimo_comparison_distance            (10 Varianten)
%     2. run_analog_bf_mixed_distance               (10 Dateien)
%     3. 3a fuer mux_alphabetB, 3 Distanzen         (3 Laeufe)
%
%   HIER STEHT DIE REIHENFOLGE ANDERS ALS IN WRAPPER 1 UND 2, mit Absicht:
%   3b ist die Hauptquelle der Studie -- daraus kommen d*, K* und die
%   Gangwahl ueber die Distanz (analyze_bf_vs_mux_qam, analyze_rice_comparison,
%   analyze_best_gear Teil A). Es ist mit 25 Workern und 10 Varianten der
%   kuerzeste Weg zu den Zahlen, die du als erste wieder brauchst. Der
%   3a-Anteil dieses Wrappers ist nur eine Variante und steht deshalb hinten,
%   obwohl er die 100 Kerne besser fuellt.
%
%   3b LIEFERT MIT per_mixer JETZT DEN STANDARD: LO_MODEL ist seit PR #4
%   "per_mixer", die Ausgabe heisst cmp_distance_<variante>.mat OHNE Suffix.
%   Die 12 vorhandenen Dateien dieses Namens stammen vom alten Modellsatz,
%   ihr resultFingerprint passt nicht und sie werden ueberschrieben.
%
%   DIE MISCHFORMEN RECHNEN NUR DIE LOS-FAELLE: SE_data_abftx_fixedB und
%   SE_data_abfrx_fixedB fehlen, also laufen 5 Varianten x 2 LO-Faelle = 10
%   Dateien statt der vollen Matrix. Das ist kein Fehler des Wrappers,
%   sondern der Kurvenstand -- siehe docs/MIMO_TODO.md Abschnitt 3.4.
%
%   Gesamtaufteilung der 500 Kerne: docs/HPC_RUNBOOK_NEWHW.md.
setenv('GEARBOXPHY_WORKERS', '100');

jobs = { ...
    {'3b: BF gegen MUX ueber die Distanz (10 Varianten)', ...
     @() run_mimo_comparison_distance()}, ...
    {'Gemischte Architekturen ueber die Distanz (10 Dateien)', ...
     @() run_analog_bf_mixed_distance()}, ...
    {'3a: mux_alphabetB, 3 Distanzen', ...
     @() run_mimo_comparison_sweep("mux_alphabetB")} ...
};
run_newhw_runner("Wrapper 3 von 4", 100, jobs);
end
