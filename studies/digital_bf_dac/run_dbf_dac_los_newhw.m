function run_dbf_dac_los_newhw()
%RUN_DBF_DAC_LOS_NEWHW  LOS, digitales Beamforming, alle DAC-Aufloesungen:
%   alter gegen neuen Satz der Hardware-Leistungsmodelle.
%
%   Aufruf: in GearboxPHY-MIMO/ einfach
%       setupGearboxPath; run_dbf_dac_los_newhw
%   Vorher: export_dbf_dac_curves. Fuer den Kanal "losd" muessen die Ordner
%   SE_data_bflosd_fixedB_dac<k> UND ..._dac<k>_common fuer k = 0..3
%   vorliegen (die gemeinsame Aussteuerung ist der Standardfall).
%
%   RESSOURCEN: 25 Worker, 64 GB, 12 h. Ein Knoten.
%   NICHT GEMESSEN. Ein Kanal, zwei Modellsaetze, zwei LO-Faelle; je Datei
%   neun Kurvensaetze (idealer DAC, vier Stufen gemeinsam, vier je Antenne).
%   Fertige Dateien werden uebersprungen.
%
%   ZIH-Cluster statt Windows: sbatch hpc/zih/submit_study.sbatch run_dbf_dac_los_newhw
%   mit --cpus-per-task=26 (einer fuer den Client). Anleitung und
%   Schritt 0: docs/HPC_RUNBOOK_ZIH.md.
%
%   Das ist run_dbf_dac_distance, beschraenkt auf
%     Kanal        "losd" (Rang 1, ein ADC je Empfangsantenne)
%     Modellsaetze "analytic" -- die Modelle der Dissertation (LNA
%                  fom_bandwidth, ADC envelope, DAC analytic 3 V)
%                  "hw_new"   -- die survey-gestuetzten Modelle (LNA envelope,
%                  ADC quantile5, DAC survey)
%   LO-Faelle wie dort: gemeinsamer LO und 12.5 mW Puffer je weiterem Mischer.
%   Die analogen LOS-Varianten laufen fuer beide Saetze als Vergleich mit.
%
%   AUSGABE: results/dbfdac_distance_losd_<lo>_<satz>.mat und
%            results/abfdac_distance_abf_<ps>_<satz>.mat
run_dbf_dac_distance(struct('CHANNELS', "losd", 'DAC_MODELS', ["analytic" "hw_new"]));
end
