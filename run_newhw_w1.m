function run_newhw_w1()
%RUN_NEWHW_W1  Wrapper 1 von 4: Neurechnung mit den NEUEN Hardwaremodellen.
%
%   Aufruf: in GearboxPHY-MIMO/ einfach
%       setupGearboxPath; run_newhw_w1
%
%   RESSOURCEN: 100 Kerne, 64 GB. Eine MATLAB-Sitzung.
%
%   INHALT, in dieser Reihenfolge:
%     1. 3a fuer mux_fixedB und mux_scaledB, je 3 Distanzen   (6 Laeufe)
%     2. run_analog_bf_distance                   (19 Varianten, 19 Dateien)
%
%   WARUM 100 KERNE UND NICHT MEHR: 3a parallelisiert ueber die 100
%   Ratenpunkte (runSweep nimmt min(numel(RVec), maxCores)), mehr Worker
%   bleiben leer. Die Distanzstudie danach nutzt ohnehin nur 25 -- einen
%   Worker je Distanz. In der zweiten Haelfte liegen also 75 Kerne brach;
%   das ist die parallele Achse des Laufs und keine Einstellung.
%
%   19 DATEIEN, NICHT 38: ADC_MODELS steht seit dem 2026-10-15 auf
%   "quantile5" allein (Nutzerentscheidung). Der alte ADC "envelope" war der
%   zweite Arm einer Einfassung und ist draussen; die 38 vorhandenen Dateien
%   stammen vom alten Satz, 19 davon werden ueberschrieben, 19 bleiben als
%   Waisen liegen (Name ..._envelope.mat).
%
%   WARUM 3a ZUERST: es ist der lange Teil und fuellt die 100 Kerne. Die
%   Distanzstudie mit ihren 25 Workern waere vorn Verschwendung. Wer
%   dagegen zuerst ein Ergebnis SEHEN will, dreht die Reihenfolge -- die
%   beiden Laeufe sind voneinander unabhaengig.
%
%   Gesamtaufteilung der 500 Kerne und die Begruendung je Lauf:
%   docs/HPC_RUNBOOK_NEWHW.md.
setenv('GEARBOXPHY_WORKERS', '100');

jobs = { ...
    {'3a: mux_fixedB + mux_scaledB, 3 Distanzen', ...
     @() run_mimo_comparison_sweep(["mux_fixedB" "mux_scaledB"])}, ...
    {'Analog-BF ueber die Distanz (19 Dateien)', ...
     @() run_analog_bf_distance()} ...
};
run_newhw_runner("Wrapper 1 von 4", 100, jobs);
end
