# MIMO im Gearbox-PHY — Stand und offene Läufe

**Ziel.** Das Gearbox soll nicht nur Gang, Bandbreite, Tastverhältnis und
Modulationsordnung wählen, sondern auch die **Antennenarchitektur**:
Multiplexing, digitales Beamforming oder analoges Beamforming — über drei
Kanäle (LOS, Rice, Rayleigh) und die zugehörigen Wandler- und
Phasenschiebermodelle.

Stand: 2026-10-13 (`QuantizedMimoMI e1a72e2`, `GearboxPHY-MIMO 1ad2e4c`).
Diese Datei ist die Übersicht. Begründungen, Messwerte und Herleitungen
stehen in den Commits und den Dokumenten aus Abschnitt 5.

---

## 1. Was gerechnet ist

**MI-Kurven (QuantizedMimoMI, `qam/results/`) — 1 145 Dateien in 30
Ordnern, bis auf zwei vollständig.**

| Modus | Kanal | ADC-Regel | Stand |
|---|---|---|---|
| MUX | Rayleigh K = 0 | `fixedB`, `scaledB` | 20/20, 20/20 |
| MUX | Rayleigh K = 0 | `alphabetB` | 15/15 (5 nicht rechenbar, B = 27…67) |
| MUX | Rice K = 3, 30 | `scaledB` | 19/20 je K — **fehlt 16×16/256-QAM** |
| MUX | Rang 1 (K = ∞) | `scaledB` | 20/20 |
| digitales BF | Rayleigh K = 0 | `fixedB`, `scaledB` | 36/36 |
| digitales BF | Rice K = 3, 30 | `fixedB` | 20/20 je K |
| ideales BF | AWGN + Gewinn | `fixedB`, `scaledB` | 36/36 |
| analoges BF | alle vier K | `fixedB` | 20/20 je K |

**DAC-Quantisierung am Sender — alle 24 Ordner vollständig.**
4 Stufen (+0…+3 bit über ½·log₂M) × 2 Aussteuerungen (`common` als
Standard, `perAntenna` als Vergleich) × 3 Empfängerfälle (LOS mit einem
ADC hinter dem Kombinierer, LOS mit einem ADC je Antenne, Rayleigh), beim
Rayleigh-Fall zusätzlich über K = 3 und 30. Zusammen 480 Rice-Dateien in
den `bf_rayleigh_dac*`-Familien.

**Gearbox-Seite — gebaut und geprüft, aber noch nicht gelaufen.**
Export, Distanz-Sweeps und Auswertungen für alle drei Architekturen stehen
bereit, einschließlich der Rice-Spalte des analogen Zweigs (AP3) und des
Arbeitspunkts je Punkt (AP7: `SE`, `SNR_rx_dB`, `SNR_tx_dB`, `P_t_W`,
`B_Hz`, `gamma`). Vorhandene Ergebnisdateien tragen den Arbeitspunkt
**nicht** — er entsteht erst in neuen Läufen.

---

## 2. Was noch fehlt

### 2.1 Zwei MI-Kurven

| Kurve | Kanal | Kosten |
|---|---|---|
| 16×16, 256-QAM, `scaledB` (B = 11) | Rice K = 3 | 22,4 h |
| dieselbe | Rice K = 30 | 22,4 h |

Poolgroesse vorher in `common/sweepWorkers.m` setzen — oben `WORKERS = 400;`
statt `[]`. 400 halbiert die Zeit, 300 bringt nichts (siehe unten).

```matlab
addpath('<...>\QuantizedMimoMI'); setupPath
runQamSweepRiceMuxK3
% in einer ZWEITEN MATLAB-Sitzung, gleichzeitig:
runQamSweepRiceMuxK30
```

Zwei MATLAB-Sitzungen gleichzeitig; der HPC laeuft Windows, es gibt kein
`salloc`. Die Poolgroesse steht in `common/sweepWorkers.m` (`WORKERS`),
ohne Eintrag sind es 200.

**Mehr Worker lohnen nur in Stufen:** die Zeit haengt an `ceil(nMC / w)`
mit `nMC = 400`, also bringen 300 Worker genau so viel wie 200 (zwei
Wellen), erst 400 halbieren sie auf **11,2 h**. Das gilt je Sitzung — zwei
Sitzungen mit je 400 brauchen 800 Kerne zusammen; stehen nur 400 zur
Verfuegung, ist 2 × 200 parallel genauso schnell wie 1 × 400 nacheinander.

**Sie blockieren das N-Raster, nicht die Kette.** Der Export nimmt eine
Arraygröße nur mit allen vier Modulationsordnungen; ohne diese zwei läuft
der Rice-MUX-Teil auf N ∈ {1, 2, 4, 8} statt bis 16. Wer früher anfangen
will, kann das kleinere Raster nehmen und Export und 3b später wiederholen
— `localUpToDate` erzwingt das von selbst, sobald die Kurven jünger sind
als das Ergebnis.

### 2.2 Die Gearbox-Läufe, in dieser Reihenfolge

| # | Schritt | Umfang |
|---|---|---|
| 1 | `export_mimo_comparison_curves` | erzeugt u. a. `SE_data_bf_fixedB_K3/_K30` — **Deckelungsreferenz für Schritt 2** |
| 2 | `export_dbf_dac_curves` | 41 Ordner (25 + 16 Rice), deckelt an der Ideal-DAC-Kurve (E4) |
| 3 | `run_dbf_dac_distance` | 25 Worker; rechnet die 18 vorhandenen Dateien neu (E9) und die Kanäle `ray3`/`ray30` |
| 4 | `run_analog_bf_distance` | jetzt mit 9 Rice-Varianten (AP3), ~20 min mehr |
| 5 | `run_mimo_comparison_distance` (3b) | die neuen und umbenannten Varianten |
| 6 | `run_mimo_comparison_sweep` (3a) | `mux_alphabetB` + 5 Rice-Varianten, 100 Kerne, 8 h je Lauf |
| 7 | `analyze_rice_comparison`, `analyze_bf_vs_mux_qam` | **K\* neu bestimmen** |

Schritt 1 **muss** vor 2 laufen, sonst warnt der Export mit
`export:noDacCapRef` und schreibt die Rice-DAC-Kurven ungedeckelt.

**K\* = 16,5 bei 56 m ist überholt** — die Zahl entstand unter BF-`scaledB`
und verschiebt sich durch E8 zu kleinerem K.

### 2.3 Nach jeder Änderung an Sweep oder Speichern

`tests/smoke_test.m` und `tests/mimo_smoke_test.m` ausführen, nicht nur die
Unit-Suite: nur diese zwei fahren `runSweep` und die Speicherebene. Ein
Fehler dort stand am 2026-10-13 in main, während die Suite 85/85 meldete.

---

## 3. Entscheidungen

**Getroffen.**

| # | Entscheidung |
|---|---|
| E1 | Rice auf dem vollen 20er-Gitter rechnen (71 h), statt bei N ≤ 4 zu bleiben |
| E2 | Rice **nur** für `scaledB` — kein zweites Rice-Raster für `fixedB` oder `alphabetB`. Die Regel kostet im Median 0,00 %, ein zweiter Satz brächte keine neue Aussage |
| E3 | DAC-Leistungsmodell als Schalter mit altem Default — war schon gebaut |
| E4 | DAC-Kurven am Ideal-DAC deckeln; Quantisierung darf nicht helfen |
| E5 | ZXM / IR / CPM kommen nicht in die MIMO-Matrix |
| E8 | ADC-Regel je Modus: MUX `scaledB`, digitales BF `fixedB` (ein Strom, kein log₂N) |
| E9 | Gemeinsame Aussteuerung ist der Standard, `perAntenna` der Vergleich |
| E10 | DAC-Quantisierung auch über Rice, volles Kreuzprodukt (320 Kurven, 4,6 h) |

**Offen.**

| # | Frage | Empfehlung |
|---|---|---|
| E6 | N > 16? | nein — `alphabetB` dort nicht rechenbar, Phasenquantisierung verliert ohnehin |
| E7 | `isfile`-Aussetzer auf dem UNC-Share? | Kandidaten einmal im Client prüfen und ins parfor broadcasten; die fünf betroffenen Läufe neu rechnen |
| E11 | Golden Master belastbar machen? | je Testmethode seeden **und** Toleranz auf die echte Streuung weiten (E_bit ~1e-2, γ ~1e-1) |

Zu **E11**: `qamMatchesOriginal` und `naQamMatchesOriginal` vergleichen zwei
Zufalls-Optimierer auf RelTol 1e-6 — beide Seiten ziehen ungeseedet aus dem
globalen Strom. Gemessene Streuung: 0,42 % in E_bit, 4,4 % in γ, wobei die
neue Seite das bessere Optimum findet. Grün über die Dateiform, rot über die
Ordnerform; der Mechanismus dahinter ist nicht aufgeklärt. Einen Seed zu
suchen, bei dem es grün wird, wäre Rosinenpickerei.

---

## 4. Grenzen, die in jede Aussage gehören

Keine davon ist ein Fehler; jede schiebt das Ergebnis in eine bekannte
Richtung. Für die ersten vier gibt es inzwischen Schalter, und
`hardwareModel = "new"` setzt sie gemeinsam auf die 5-%-Quantile der drei
Hardware-Übersichten; der Default `"custom"`/`"old"` ist bitgleich zu allen
bestehenden Ergebnissen.

- **ADC = Walden-Bestfall** (Median 26× optimistisch) und **DAC = 3 V**
  (rund 6× pessimistisch) — zusammen begünstigen sie digitale Architekturen.
  Schalter: `adcPowerModel = "quantile5"`, `dacPowerModel = "survey"`.
- **LO-Verteilung im digitalen Zweig nicht berechnet** — begünstigt digital;
  mit 12,5–17 mW je Mixer gewinnt analog ab 180–240 m. Schalter:
  `loDistributionModel = "per_mixer"`.
- **Frequenzflacher Kanal** — ein Tap, keine Verzögerungsachse. Die
  Bandbreite ist frei und liegt am oberen Ratenende zwei bis drei
  Größenordnungen über der Kohärenzbandbreite. *(Richtung unbekannt, kein
  Schalter.)*
- **i.i.d. Rayleigh ist vollrangig** — begünstigt MUX; BF verliert 0,6 bis
  6,8 dB gegen N_t·N_r.
- **MI ist bei N ≥ 4 und M ≥ 64 eine untere Schranke** (7–13 % Schlupf nahe
  der Sättigung) — wirkt gegen MUX.
- **Phasenquantisierung** `G = 1 + (N−1)·sinc²` ist gegenüber echter Rundung
  leicht pessimistisch (≤ 1,1 dB bei 1 bit) — wirkt gegen analog.

---

## 5. Wo die Begründungen stehen

| Thema | Ort |
|---|---|
| Ablauf der Läufe, Schritt für Schritt | `HPC_RUNBOOK_MIMO_VERGLEICH.md`, `HPC_RUNBOOK_ANALOG_BF.md`, `HPC_RUNBOOK_DAC.md` |
| Wandler- und Hardwaremodelle | `ADC_POWER_MODEL.md`, `DAC_POWER_MODEL.md`, `LNA_POWER_MODEL.md`, `HARDWARE_MODEL_SWITCH.md` |
| DAC-Quantisierung, Aussteuerung | `DAC_QUANTISATION_SPEC.md` |
| Rice-Erweiterung, analoges BF | `RICE_EXTENSION_PLAN.md`, `ANALOG_BEAMFORMING.md`, `PHASE_SHIFTER_POWER_MODEL.md` |
| Code-Abgleich mit dem HPC | `codeManifest('snapshot')` im Ordner `code_manifest/` |
| Warum eine Entscheidung so fiel | die Commit-Nachricht, die sie umsetzt |
