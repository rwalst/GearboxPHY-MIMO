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
| 3 Sweep | GearboxPHY-MIMO | `setupGearboxPath; run_dbf_dac_distance` | 25 Worker, 64 GB, 24 h anfordern — **erwartet ~36 min** (hochgerechnet, s. u.) |

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

## Teil 4: LOS mit den survey-gestuetzten Hardware-Modellen (2026-10-13)

Vergleich aller DAC-Aufloesungen unter LOS fuer zwei Saetze von Leistungsmodellen: die der
Dissertation und die survey-gestuetzten fuer LNA, ADC und DAC zusammen.

| Schritt | Wo | Aufruf | Ressourcen |
|---|---|---|---|
| 10 Export | GearboxPHY-MIMO | `setupGearboxPath; export_dbf_dac_curves` | Sekunden; noetig, damit `SE_data_bflosd_fixedB_dac<k>_common` fuer k = 0..3 vorliegen |
| 11 Sweep | GearboxPHY-MIMO | `setupGearboxPath; run_dbf_dac_los_newhw` | nodes=1 cpus-per-task=25 mem=64G time=12:00:00 (NICHT gemessen) |

Ergebnis: `results/dbfdac_distance_losd_<lo>_{analytic,hw_new}.mat` und die analogen
LOS-Varianten `results/abfdac_distance_abf_<ps>_{analytic,hw_new}.mat`. Der Modellsatz `hw_new`
entspricht `hardwareModel = "new"` des Sammelschalters (Zweig `worktree-hardware-model-switch`),
hier ueber die drei Einzelschalter gesetzt. PA, LO und Mischer sind in beiden Saetzen gleich.

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

---

## Schritt 3 für den HPC vorbereitet (2026-10-15)

Alles, was ohne den Sweep prüfbar ist, ist geprüft. Der Treiber startet auf
beiden Clustern ohne Argument.

### Aufruf

| Cluster | Aufruf |
|---|---|
| Windows | in `GearboxPHY-MIMO/`: `setupGearboxPath; run_dbf_dac_distance` |
| ZIH | `sbatch hpc/zih/submit_study.sbatch run_dbf_dac_distance` (`--cpus-per-task=26`, einer für den Client) |

Die Workerzahl steht als `P.N_WORKERS = 25` im CONFIG-Block des Treibers —
je Lauf dort anpassen, nicht am Aufruf. Auf dem ZIH deckelt
`+sweep/workerBudget.m` zusätzlich an `SLURM_CPUS_PER_TASK`.

### Voraussetzungen, geprüft

Alle fünf Kanäle vollständig, je vier DAC-Stufen in **beiden**
Aussteuerungen:

| Kanal | `digBase` | Stufen | `anaData` |
|---|---|---|---|
| `losd` | `SE_data_bflosd_fixedB` | per 0–3, common 0–3 | `SE_data_bfideal_fixedB` |
| `los` | `SE_data_bfideal_fixedB` | per 0–3, common 0–3 | `SE_data_bfideal_fixedB` |
| `ray` | `SE_data_bf_fixedB` | per 0–3, common 0–3 | `SE_data_abf_fixedB` |
| `ray3` | `SE_data_bf_fixedB_K3` | per 0–3, common 0–3 | `SE_data_abf_fixedB_K3` |
| `ray30` | `SE_data_bf_fixedB_K30` | per 0–3, common 0–3 | `SE_data_abf_fixedB_K30` |

Die `common`-Stufen 1–3 gab es bis zum 2026-10-15 nicht (K=0-Fehler im
Export, siehe `MIMO_TODO.md` 3.2). **Vorher hätte dieser Lauf den
Standardfall nur für Stufe 0 gerechnet** und dabei wie ein vollständiger
Sweep ausgesehen.

### Vorablauf, der die ganze Kette durchfährt

Mini-Raster, seriell, Ergebniswurzel in einem Wegwerfordner — also ohne
Spuren im Repo. Lief am 2026-10-15 in **56,9 s**, ohne eine Warnung:

```matlab
setupGearboxPath
setenv('GEARBOXPHY_RESULTS_ROOT', tempname); mkdir(getenv('GEARBOXPHY_RESULTS_ROOT'))
run_dbf_dac_distance(struct('RESULT_PREFIX', "pre_", 'distances', [50 5000], ...
    'Ms', [4 16], 'Ns', [1 2], 'CHANNELS', "losd", 'DAC_MODELS', "analytic", ...
    'N_WORKERS', 0, 'SKIP_EXISTING', false))
```

Was er belegt: Kanalerkennung, Stufenerkennung, Szenario, Fingerabdruck und
Ergebnisspeicher, die Felder `Eadc`/`Eps` der Vereinigung, `minOverDacLevels`
und das Speichern. Gegengeprüft am Ergebnis: `kBest` nutzt alle vier Stufen
(1–4), alle Zellen endlich, **kein** `commonIncomplete`.

### Was der Vollauf erzeugt

315 Fälle (5 Kanäle × 3 DAC-Modelle × [2 LO-Fälle × 9 Kurvensätze + 3
Phasenschieber]) à 1000 Optimierungen = **315 000**. Daraus **66 Dateien**:

| | Dateien | davon neu |
|---|---|---|
| digital `dbfdac_distance_<kanal>_<lo>_<modell>.mat` | 30 | 12 (`ray3`, `ray30`) |
| analog `abfdac_distance_<variante>_<modell>.mat` | 36 | 18 (`abfray3`, `abfray30`) |

Die 36 vorhandenen werden **neu gerechnet**, und zwar zwangsläufig: die
digitalen tragen `dacLevels = [0]` statt `[0 1 2 3]`, die analogen keinen
`resultFingerprint`. Beide Prüfungen schlagen damit fehl, und das ist
richtig — sie stammen aus der Zeit vor E9, E12 und AP7.

**Der Ergebnisspeicher nimmt 9 der 315 Fälle (2,9 %) heraus:** die Kanäle
`losd` und `los` haben dieselben `anaData`/`anaMode`/`anaPrefix`, ihre
analogen Dateien sind also dieselbe Rechnung unter demselben Namen.

### Laufzeit

~15 Kernstunden, auf 25 Workern **etwa 36 min**. Hochgerechnet aus dem
Vorablauf (0,169 s je Optimierung) und damit eine **obere** Schranke: dort
verteilt sich der Szenario-Aufbau je Distanz auf 4 Zellen statt auf 20.
Nicht auf dem Cluster gemessen.

Die 24 h bleiben als Anforderung: zu wenig Walltime killt den Job, zu viel
kostet nur Priorität. Dauert es zehnmal länger, stimmt etwas nicht — dann
zuerst die Datei- und Checkpoint-Ebene ansehen, nicht die Optimierung.

### Danach prüfen

1. 66 Dateien unter `results/`, keine Warnung im Protokoll — besonders kein
   `commonIncomplete` und kein `dacCapRef`-Hinweis.
2. In einer digitalen Datei: `dacLevels` = `[0 1 2 3]`,
   `dacScaleStandard` = `"common"`, `kBest` nutzt mehr als eine Stufe.
3. `resultFingerprint` in jeder Datei (sonst trägt sie nichts zum
   Ergebnisspeicher bei, siehe `RESULT_NAMING.md`).
4. **Die Auswertung fehlt weiterhin** (`MIMO_TODO.md` 1, letzte Zeile):
   nach diesem Lauf liegen 66 Dateien da, die niemand liest. Das ist der
   nächste sinnvolle Schritt, nicht Schritt 4.
