# Runbook: analoges gegen digitales Beamforming

Stand 2026-10-08. Modell und Annahmen: `docs/ANALOG_BEAMFORMING.md`.

Lokal gelaufen sind bisher nur die Pruefungen (Schritt 0 und A0). Kein Sweep ist gelaufen;
Laufzeiten sind geschaetzt, nicht gemessen.

## Fall 1: LOS, laeuft mit den vorhandenen Kurven

Voraussetzung: `data/SE_data_bfideal_fixedB/` (liegt im Repo).

| Schritt | Wo | Aufruf | Ressourcen |
|---|---|---|---|
| 0 Pruefen | GearboxPHY-MIMO | `setupGearboxPath; validate_analog_bf` | unter 1 min, kein Pool |
| 1 Sweep | GearboxPHY-MIMO | `setupGearboxPath; run_analog_bf_distance` | nodes=1 ntasks=1 cpus-per-task=32 mem=64G time=12:00:00 |
| 2 Auswerten | Arbeitsplatz | `setupGearboxPath; analyze_analog_bf` | Sekunden |

Schritt 1 schreibt `results/abf_distance_<variante>_<adc>.mat` fuer sieben Varianten
(`dbf_ideal`, `dbf_ideal_lo4mW`, `dbf_ideal_lo12p5mW`, `dbf_ideal_lo17mW`, `abf_active`,
`abf_passive_comp`, `abf_passive_pen`) und zwei ADC-Modelle (`envelope`, `quantile5`), also
vierzehn Dateien. Die drei `dbf_ideal_lo*`-Varianten sind die digitale Referenz mit einem
LO-Puffer von 4, 12.5 bzw. 17 mW je zusaetzlichem Mischer. Gegenueber der urspruenglichen
Schaetzung (vier Varianten) steigt der Rechenaufwand etwa auf das 1.75-fache; die Zeitgrenze
von 6 h ist NICHT nachgemessen -- im Zweifel 12 h anfordern, fertige Dateien werden beim
Neustart uebersprungen. Fertige Dateien mit passender CFG werden
uebersprungen.

Schritt 2 schreibt `results/abf_figures/abf_energy_<adc>.png`, `abf_arrays_<adc>.png` und
`abf_summary.csv`.

## Fall 2: Rayleigh/Rice mit reinen Phasengewichten

| Schritt | Wo | Aufruf | Ressourcen |
|---|---|---|---|
| A0 Pruefen | QuantizedMimoMI/qam/validate | `validateBfAnalog` | Sekunden, kein Pool |
| A1 Kurven | QuantizedMimoMI/qam/sweep | `runQamSweepBfAnalog` | nodes=1 ntasks=1 cpus-per-task=4 mem=8G time=00:30:00 |
| A2 Export | GearboxPHY-MIMO | `setupGearboxPath; export_analog_bf_curves` | Sekunden |
| 0 Pruefen | GearboxPHY-MIMO | `setupGearboxPath; validate_analog_bf` | jetzt mit B8 |
| 1 Sweep | GearboxPHY-MIMO | `setupGearboxPath; run_analog_bf_distance` | wie oben; rechnet nur die drei neuen `abfray_*`-Varianten |
| 2 Auswerten | Arbeitsplatz | `setupGearboxPath; analyze_analog_bf` | Sekunden |

A1 schreibt 80 Kurven nach `QuantizedMimoMI/qam/results/bf_analog/` (N = 1..16, M = 4..256,
K = 0, 3, 30, Inf). A2 legt `data/SE_data_abf_fixedB` (K = 0) und `_K3`, `_K30`, `_KInf` an.
Der Sweep nutzt bisher nur K = 0.

Die digitale Rayleigh-Referenz fuer Fall 2 ist `results/cmp_distance_bf_fixedB.mat` aus
`run_mimo_comparison_distance`; die Auswertung vergleicht bisher nur gegen `dbf_ideal`.

## Mischformen: eine Seite analog, die andere digital

Lokal gelaufen sind nur die Pruefungen. Kein Sweep, keine Kurvenrechnung.

LOS, laeuft sofort (Kurven aus `SE_data_bfideal_fixedB`):

| Schritt | Wo | Aufruf | Ressourcen |
|---|---|---|---|
| 0 Pruefen | GearboxPHY-MIMO | `setupGearboxPath; validate_analog_bf` | unter 1 min; B11 prueft die Mischformen |
| 1 Sweep | GearboxPHY-MIMO | `setupGearboxPath; run_analog_bf_mixed_distance` | nodes=1 ntasks=1 cpus-per-task=32 mem=64G time=12:00:00 |

Schritt 1 schreibt `results/abfmix_distance_<variante>_<lo>.mat` fuer fuenf Varianten
(`mix_txA_rxD_active`, `mix_txA_rxD_passive`, `mix_txD_rxA_active`, `mix_txD_rxA_passive_comp`,
`mix_txD_rxA_passive_pen`) mal zwei LO-Faelle (`loShared`, `lo12p5mW`), also zehn Dateien.
Raster wie `run_analog_bf_distance`; Referenzen sind dessen Ergebnisse. Nur ADC-Modell
`envelope`.

Rayleigh, braucht vorher neue Kurven:

| Schritt | Wo | Aufruf | Ressourcen |
|---|---|---|---|
| A0 Pruefen | QuantizedMimoMI/qam/validate | `validateBfAnalog` | etwa eine Minute; A9, A10 pruefen die Mischfaelle |
| A1a Kurven, Empfaenger analog | QuantizedMimoMI/qam/sweep | `runQamSweepBfAnalog` | nodes=1 cpus-per-task=4 mem=8G time=00:30:00; rechnet nur die fehlenden `bf_analog_rx`-Kurven |
| A1b Kurven, Sender analog | QuantizedMimoMI/qam/sweep | `runQamSweepBfTxAnalog` | nodes=1 cpus-per-task=200 mem=64G time=12:00:00 (wie `runQamSweepBfRayleigh`, eine ADC-Regel statt zwei; NICHT gemessen) |
| A2 Export | GearboxPHY-MIMO | `setupGearboxPath; export_analog_bf_curves` | Sekunden; legt `SE_data_abfrx_fixedB` und `SE_data_abftx_fixedB` an, soweit die Quellen da sind |
| 1 Sweep | GearboxPHY-MIMO | `setupGearboxPath; run_analog_bf_mixed_distance` | rechnet nur die neuen `mixray_*`-Varianten |

A1a und A1b sind unabhaengig; der Sweep nimmt jede der beiden Kurvenfamilien mit, sobald ihr
Ordner existiert.

Eine Auswertung, die die Mischformen neben die reinen Faelle legt, gibt es noch nicht
(`analyze_analog_bf` kennt nur `abf_distance_*`).

## Was zu pruefen ist, wenn etwas nicht passt

- `validate_analog_bf` B3 scheitert: die 1x1-Kurven in `SE_data_bfideal_fixedB` passen nicht
  mehr zu den NxN-Kurven desselben Ordners. Ordner neu exportieren.
- `export_analog_bf_curves` bricht mit `export:cap` oder unbekanntem Modus ab:
  QuantizedMimoMI ist zu alt, `exportToGearboxSEData` muss den Modus `bfanalog` kennen.
- K = Inf als Kontrolle: `SE_data_abf_fixedB_KInf` muss bis auf Raster und Interpolation
  `SE_data_bfideal_fixedB` sein.
