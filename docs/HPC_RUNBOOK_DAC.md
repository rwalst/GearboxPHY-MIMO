# Runbook: digitales Beamforming mit DAC-Quantisierung

Stand 2026-10-12. Studie: `studies/digital_bf_dac/`. Modell: `DAC_QUANTISATION_SPEC.md`,
DAC-Leistung: `DAC_POWER_MODEL.md`.

**Erledigt:** alle MI-Kurven (Schritte 1, 4 und 7) liegen vor und sind geprueft.
**Offen:** Export und Distanz-Sweep -- Schritte 2/3 genuegen, ein Aufruf nimmt alle drei
Kanaele (`losd`, `los`, `ray`) mit. Vor dem Export ist die Frage "deckeln oder nicht" zu
entscheiden (`studies/digital_bf_dac/README.md`).

Die Teile unten stehen in der Reihenfolge, in der sie entstanden sind.

Lokal gelaufen sind nur die Pruefungen (`validateBfDac`, Unit-Tests, Golden Master, ein
Probelauf des Studientreibers auf einem Mini-Raster). Kein Kurven- und kein Distanz-Sweep.

## Teil 1: LOS

| Schritt | Wo | Aufruf | Ressourcen |
|---|---|---|---|
| 0 Pruefen | QuantizedMimoMI/qam/validate | `validateBfDac` | unter einer Minute, kein Pool |
| 1 Kurven | QuantizedMimoMI/qam/sweep | `runQamSweepBfIdealDac` | nodes=1 cpus-per-task=4 mem=8G time=01:00:00, kein Pool (NICHT gemessen) |
| 2 Export | GearboxPHY-MIMO | `setupGearboxPath; export_dbf_dac_curves` | Sekunden |
| 3 Sweep | GearboxPHY-MIMO | `setupGearboxPath; run_dbf_dac_distance` | nodes=1 cpus-per-task=25 mem=64G time=24:00:00 (NICHT gemessen) |

Schritt 1 schreibt `qam/results/bf_ideal_dac<k>` und `..._dac<k>_common` (k = 0..3) und druckt
am Ende je Kurve den SNR-Mehrbedarf gegen den idealen DAC. Daran ablesen:

- Ist der Mehrbedarf ab einer Stufe unter etwa 0.1 dB, braucht der Rayleigh-Lauf die hoeheren
  Stufen nicht: `DAC_OFFSETS` in `runQamSweepBfRayleighDac.m` kuerzen.
- Erwartet (nur aus dem Quantisierer): +0 Bit 0.3 bis 0.9 dB, +1 Bit um 0.1 dB, ab +2 Bit nichts.

Schritt 3 rechnet nach Teil 1 nur den Kanal `los`: je LO-Fall und DAC-Leistungsmodell eine
Datei `results/dbfdac_distance_los_<lo>_<dacModell>.mat` (digitale Seite: idealer DAC, alle
Stufen, Minimum ueber die Stufen, Vergleichsfall `common`) und je analoger Variante
`results/abfdac_distance_abf_<ps>_<dacModell>.mat`.

## Teil 2: Rayleigh

| Schritt | Wo | Aufruf | Ressourcen |
|---|---|---|---|
| 4 Kurven | QuantizedMimoMI/qam/sweep | `runQamSweepBfRayleighDac` | nodes=1 cpus-per-task=200 mem=64G time=48:00:00 (NICHT gemessen; Checkpoints je SNR-Punkt, fertige Kurven werden uebersprungen) |
| 5 Export | GearboxPHY-MIMO | `setupGearboxPath; export_dbf_dac_curves` | Sekunden; ergaenzt `SE_data_bf_fixedB_dac<k>` |
| 6 Sweep | GearboxPHY-MIMO | `setupGearboxPath; run_dbf_dac_distance` | rechnet nur den neuen Kanal `ray`; `los` liegt vor |

Schritt 4 rechnet vier Stufen mit Aussteuerung je Antenne und Stufe +0 mit gemeinsamer
Aussteuerung. Die analogen Rayleigh-Varianten in Schritt 6 brauchen `SE_data_abf_fixedB`
(liegt vor).

## Teil 3: LOS mit einem ADC je Empfangsantenne (Nachtrag 2026-10-12)

Die LOS-Kurven aus Teil 1 kombinieren vor EINEM ADC (analoger Empfaenger). Fuer die digitale
Seite gibt es jetzt dieselbe Referenz mit einem ADC je Antenne, wie im Rayleigh-Fall.

| Schritt | Wo | Aufruf | Ressourcen |
|---|---|---|---|
| 7 Kurven | QuantizedMimoMI/qam/sweep | `runQamSweepBfLosDigitalDac` | nodes=1 cpus-per-task=200 mem=64G time=24:00:00 (NICHT gemessen; grob die Haelfte eines Rayleigh-Satzes je Kurvensatz, sechs Saetze; fertige Kurven werden uebersprungen) |
| 8 Export | GearboxPHY-MIMO | `setupGearboxPath; export_dbf_dac_curves` | Sekunden; ergaenzt `SE_data_bflosd_fixedB` und `..._dac<k>` |
| 9 Sweep | GearboxPHY-MIMO | `setupGearboxPath; run_dbf_dac_distance` | rechnet den neuen Kanal `losd` |

Teil 3 haengt nicht von Teil 1 und 2 ab. Fuer den Vergleich analog gegen digital im LOS ist
`losd` die digitale Referenz; `los` bleibt als "Sender digital, Empfaenger analog".

## Was die Ergebnisdateien enthalten

`dbfdac_distance_*`: `Eideal` (idealer DAC, der bisherige Stand), `E` (letzte Dimension =
DAC-Stufe, siehe `dacLevels`), `Ebest` und `kBest` (Minimum ueber die Stufen), `Ecommon`
(Vergleichsfall), dazu jeweils der DAC- und der PA-Anteil. Alles in J/bit ueber
[Distanz x Rate x M x N]; das beste (M, N) waehlt die Auswertung.

Eine Auswertung dazu gibt es noch nicht.

## Wenn etwas nicht passt

- `validateBfDac` D4 oder D7 scheitert: der DAC-Pfad veraendert einen Fall, der unveraendert
  bleiben muss (eine Sendeantenne bzw. LOS in Hauptstrahlrichtung). Nicht weiterrechnen.
- `run_dbf_dac_distance` ueberspringt einen Kanal: die Ordner `..._dac<k>` fehlen, Export
  wiederholen.
- Eine Ergebnisdatei wird neu gerechnet, obwohl sie vorliegt: Raster oder Stufenliste haben
  sich geaendert (zum Beispiel kam der Vergleichsfall dazu). Das ist gewollt.
