function run_rank1_geometry_distance()
%RUN_RANK1_GEOMETRY_DISTANCE  Distanzlaeufe fuer den Drei-Architekturen-
%   Vergleich im Rang-1-Kanal, Optionen A (broadside) und B (32 Richtungen).
%   Siehe README.md in diesem Ordner.
%
%   Aufruf: in GearboxPHY-MIMO/ einfach
%       setupGearboxPath; run_rank1_geometry_distance
%   Vorher: export_rank1_geometry_curves.
%
%   RESSOURCEN: 25 Worker, 32 GB, 4 h anfordern. Ein Knoten.
%   NICHT GEMESSEN. Neu zu rechnen sind sechs Faelle: drei der digitalen
%   Seite (r1b: idealer DAC, Stufe +0 gemeinsam und je Antenne), drei
%   analoge Varianten (abfKInf, active/passive_comp/passive_pen) und eine
%   MUX-Variante mit N <= 4. Am Massstab von run_dbf_dac_distance (315
%   Faelle in rund 36 min auf 25 Workern) sind das Minuten; die 4 h sind
%   Reserve. Alles Fertige wird per Fingerabdruck uebersprungen.
%
%   WAS GERECHNET WIRD -- nur das, was fuer den Vergleich fehlt, auf dem
%   Raster und mit den Hardwaremodellen der Hauptstudie (28 GHz, 25
%   Distanzen 10 m..10 km, 1 Mbit/s und 1 Gbit/s, M = 4..256, N = 1..16,
%   ADC quantile5, DAC survey, LNA fom_floor, LO per_mixer 12.5 mW):
%     1) run_dbf_dac_distance, Kanaele "losd" und "r1b", nur DAC-Modell
%        survey und LO lo12p5mW. losd liegt digital schon vor (wird
%        uebersprungen) -- gebraucht wird der Lauf fuer die ANALOGEN
%        Varianten abfKInf, die es noch nicht gibt (die vorhandenen
%        abfdac_distance_abf_* stammen von der alten bfideal-Referenz).
%        r1b ist Option A, digitales BF broadside.
%     2) run_mimo_comparison_distance mit "mux_scaledB_KInf" (Option A,
%        liegt vor, wird uebersprungen, wenn aktuell) und
%        "mux_scaledB_r1ang" (Option B, neu).
%   Danach: analyze_rank1_geometry.
%
%   LO "lo12p5mW", NICHT "loShared": in run_dbf_dac_distance faellt
%   "loShared" derzeit auf den Standard per_mixer zurueck (bekannter Fehler,
%   loShared == lo12p5mW). Gerechnet wird deshalb der Fall, der dem
%   Standard der MUX-Seite entspricht, und er heisst auch so.

%% ---- Vorabpruefung: alle Kurvenordner, bevor ein Worker startet ----
need = ["SE_data_mux_scaledB_KInf", "SE_data_mux_scaledB_r1ang", ...
        "SE_data_bflosd_fixedB", "SE_data_bflosd_fixedB_dac0_common", "SE_data_bflosd_fixedB_dac0", ...
        "SE_data_bfr1b_fixedB", "SE_data_bfr1b_fixedB_dac0_common", "SE_data_bfr1b_fixedB_dac0", ...
        "SE_data_abf_fixedB_KInf"];
fehlt = need(~arrayfun(@(n) isfolder(gearboxphy.paths.dataDir(n)), need));
fprintf('\n---- run_rank1_geometry_distance, Vorabpruefung ----\n');
for n = need
    if any(fehlt == n), s = 'FEHLT'; else, s = 'ok'; end
    fprintf('  %-36s %s\n', n, s);
end
if ~isempty(fehlt)
    error('run_rank1_geometry_distance:noData', ...
        ['Es fehlen %s. Erst in QuantizedMimoMI runQamSweepBfRank1Broadside und ' ...
         'runQamSweepMuxRank1Angles rechnen, dann hier export_rank1_geometry_curves.'], ...
        strjoin(fehlt, ', '));
end

%% ---- 1) digitale Seite r1b und analoge Seite abfKInf ----------------
run_dbf_dac_distance(struct( ...
    'CHANNELS',   ["losd" "r1b"], ...
    'DAC_MODELS', "survey", ...
    'LO_NAMES',   "lo12p5mW", ...
    'LO_POWER',   12.5e-3));

%% ---- 2) MUX-Seite ----------------------------------------------------
run_mimo_comparison_distance(["mux_scaledB_KInf" "mux_scaledB_r1ang"]);

fprintf('\nrun_rank1_geometry_distance fertig. Weiter mit analyze_rank1_geometry.\n');
end
