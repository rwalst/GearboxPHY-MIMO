# MIMO im Gearbox-PHY — Stand und offene Läufe

**Ziel.** Das Gearbox soll nicht nur Gang, Bandbreite, Tastverhältnis und
Modulationsordnung wählen, sondern auch die **Antennenarchitektur**:
Multiplexing, digitales Beamforming oder analoges Beamforming — über drei
Kanäle (LOS, Rice, Rayleigh) und die zugehörigen Wandler- und
Phasenschiebermodelle.

Stand: 2026-10-13 (`QuantizedMimoMI e1a72e2`, `GearboxPHY-MIMO 1ad2e4c`).
Diese Datei ist die Übersicht. Begründungen, Messwerte und Herleitungen
stehen in den Commits und den Dokumenten aus Abschnitt 6.

---

## 1. Die Auswertungen — was am Ende dasteht

Diese Auswertungen sind der Zweck, die Läufe sind das Mittel. Die Zuordnung
ist **nicht** eins zu eins: 3a speist sechs Auswertungen, 3b vier, und drei
Läufe speisen bisher gar keine. Abschnitt 3.4 stellt beide Richtungen
gegenüber.

**Gemeinsames Maß.** Alle Auswertungen rechnen in **E_bit [J/bit]** und
bilden je Zelle das **Minimum über (M, N)** — die Hüllkurve, denn genau das
tut das Gearbox: jede Architektur darf ihre beste Konfiguration wählen. Wo
nach *einem* N gefragt wird (`analyze_siso_vs_mimo`), wird bewusst
`E_per_bit_all` gelesen statt der Hüllkurve, sonst verschweigen die Zahlen,
wie teuer SISO dort war, wo MIMO gewinnt.

| Auswertung | Die Frage | Maß / Darstellung | Quelle |
|---|---|---|---|
| `analyze_bf_vs_mux_qam` | **Wann ist BF günstiger als MUX, und wovon hängt das ab?** Die Hauptaussage der Studie | **q = E_bit(BF) / E_bit(MUX)**, q < 1 = BF günstiger; über Kanal × ADC-Regel × Distanz, dazu Schnittdistanzen als Tabelle | 3b (Hauptquelle, alle Varianten auf einem Raster) + 3a für die Ratenachse |
| `analyze_rice_comparison` | **Ab welchem Rice-Faktor gewinnt BF?** | **K\***, der Schnittpunkt von E_bit(BF) und E_bit(MUX) über K; interpoliert in log₁₀(K), ausgewiesen nur wenn er zwischen zwei *gerechneten* K liegt | 3b |
| `analyze_mimo_comparison` | Wie verlaufen E_bit, das optimale N und der ADC-Anteil über der Rate? | vier Abbildungen: `cmp_ebit`, `cmp_nopt`, `cmp_adc_share`, `cmp_distance` | 3a (+ 3b für den Distanzschnitt) |
| `analyze_adc_rule` (je Modus), `analyze_adc_rule_all` (alle drei) | **Lohnt das zusätzliche ADC-Bit je Antennenverdopplung?** | Differenz `scaledB` − `fixedB` **in Prozent** (die absoluten Kurven liegen übereinander), zweite Zeile: ADC-Anteil am Budget als Begründung | 3a |
| `analyze_adc_rule_curves` | Woher kommt dieser Effekt — und warum verschwindet er wieder? | zwei Achsen: SE über SNR (dort wirkt das Bit), E_bit über Rate (dort ist es weg) | 3a |
| `analyze_best_gear` | Welcher Gang und welche Antennenzahl gewinnen wo? | Teil A: gewähltes N über der Distanz je Kanal und Regel (aus 3b). Teil B: Gang-Familie über der Rate, QAM dreifach (SISO / MUX / BF) (aus 3a) | 3a + 3b |
| `analyze_siso_vs_mimo` | Ab welcher Rate zahlen sich mehrere Ketten aus? | Umschlagpunkt je N, **nicht** als Hüllkurve (s. o.) | `run_siso_vs_mimo_scaledB` |
| `analyze_analog_bf` | Ab welcher Distanz gewinnt analoges BF, und was kostet der Phasenschieber? | E_bit je Variante über Distanz, dazu `psShare` und `adcShare`; `abf_summary.csv` | `run_analog_bf_distance` |
| `analyze_dbf_dac` | **Was kostet die endliche DAC-Auflösung das digitale BF, und wie stark hängt die Antwort am Leistungsmodell?** | **q = E_bit(endlich) / E_bit(ideal)**, beide als Hüllkurve über (M, N); dazu gewählte Stufe `kBest`, DAC-Anteil, antennenweise gegen gemeinsame Aussteuerung (E9), digital gegen analog | `run_dbf_dac_distance` |

**Die DAC-Auswertung gab es bis zum 2026-10-15 nicht** — 36 gerechnete
Dateien ohne Abnehmer, von der Studie selbst als offener Punkt geführt.
`analyze_dbf_dac` schließt das: vier Abbildungen je Rate plus `summary.csv`
in `results/dbfdac_figures/`.

Sie **weist Dateien von vor E9 ab**, und das ist der eigentliche Punkt: dort
bedeutet `E` die antennenweise Aussteuerung, seit E9 die gemeinsame. Beide
Formen tragen `Eideal`, `Ebest` und `kBest` — eine Prüfung auf Feldnamen
allein merkt den Unterschied also nicht, und q wäre stillschweigend die
Antwort auf die andere Frage. `dacScaleStandard` ist deshalb Pflichtfeld.

**`analyze_siso_vs_mimo_gf`** ist keine eigene Auswertung, sondern baut die
drei GF-Folien (34, 36, 37) aus demselben Material neu.

**Wo die Ergebnisse landen:** `results/cmp_figures/` (MIMO-Vergleich),
`results/abf_figures/` (analoges BF). Alle Auswertungen sind reine
Nachbearbeitung — Sekunden, kein Pool, dürfen am Arbeitsplatz laufen.

---

## 2. Was gerechnet ist

**MI-Kurven (QuantizedMimoMI, `qam/results/`) — 1 147 Dateien in 31
Ordnern, vollständig (seit 2026-10-15).**

| Modus | Kanal | ADC-Regel | Stand |
|---|---|---|---|
| MUX | Rayleigh K = 0 | `fixedB`, `scaledB` | 20/20, 20/20 |
| MUX | Rayleigh K = 0 | `alphabetB` | 15/15 (5 nicht rechenbar, B = 27…67) |
| MUX | Rice K = 3, 30 | `scaledB` | **20/20 je K** (die letzten zwei am 2026-10-15) |
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

**Gearbox-Seite — gelaufen, aber auf einem überholten Stand.**
Unter `results/` liegen aus früheren Läufen **dieses Vergleichs**: 68 `.mat`
(3b 12 Varianten, `analog_bf` 20, `dbf_dac` 36) und 21 Ordner (3a 18,
`siso_vs_mimo_scaledB` 3). Was in Abschnitt 3.2 als offen steht, ist deshalb
überwiegend ein **Neurechnen** dieser Dateien, kein erster Lauf — die
vorhandenen entstanden vor E8 (Rice-BF heißt dort noch `bf_scaledB_K3/_K30`
statt `bf_fixedB_*`), vor E9 (gemeinsame Aussteuerung) und vor AP7, tragen
den Arbeitspunkt (`SE`, `SNR_rx_dB`, `SNR_tx_dB`, `P_t_W`, `B_Hz`, `gamma`)
also **nicht**. Neu gebaut und noch nie gelaufen sind nur die Rice-Spalte des
analogen Zweigs (AP3) und die DAC-Rice-Fälle.

**Läufe über die RATE bei fester Distanz.** Zwei Bauformen stehen im Repo
nebeneinander, und die Übersicht in 3.2 betrifft nur die zweite:
`runSweep`-Treiber parallelisieren über die **Ratenpunkte** bei *einer*
Distanz je Lauf und schreiben einen Ordner `results/<name>_d<distanz>/`; die
Distanz-Treiber (3b, `analog_bf`, `dbf_dac`) parallelisieren über 25
Distanzen bei *zwei* festen Raten und schreiben eine `.mat`.

| Treiber | Distanz(en) | Ratenpunkte | Stand |
|---|---|---|---|
| `run_mimo_comparison_sweep` (3a) | 50 / 500 / 5000 m | 100 | 18 Ordner (6 Varianten × 3 Distanzen) |
| `run_siso_vs_mimo_scaledB` | 50 / 500 / 5000 m | 100 | 3 Ordner |

Die Distanz ist in dieser Bauform kein Sweep, sondern ein Parameter: 50 m ist
die Einstellung der Dissertation, 500 m und 5 km kommen beim BF/MUX-Vergleich
dazu.

Weitere `runSweep`-Treiber im Repo gehören **nicht** zu diesem Vergleich und
haben eigene Dokumente: `run_sweep.m` (SISO-Grundsweep, `results/main*`),
`run_beamforming_sweep`/`_allgears` (der Vorläufer mit Gewinn im Linkbudget,
`BEAMFORMING_EXTENSION.md`), `run_lna_comparison`
(`HPC_RUNBOOK_LNA_VERGLEICH.md`), `run_hw_comparison`
(`HARDWARE_MODEL_SWITCH.md`) und `run_dac_model_siso` (`DAC_POWER_MODEL.md`).
Deren Stand gehört dorthin, nicht hierher.

---

## 3. Was noch fehlt

### 3.1 MI-Kurven: erledigt — offen ist nur der Export

**Erledigt am 2026-10-15** (`QuantizedMimoMI 5764b14`). Die letzten zwei
Kurven — 16×16, 256-QAM, `scaledB` bei K = 3 und K = 30 — sind gerechnet und
geprüft: monoton, endlich, `lower ≤ mid ≤ upper` eingehalten, unter beiden
Schranken (max. MI 123,3 bzw. 99,6 gegen die Alphabetgrenze N_t·log₂M = 128),
dasselbe 21-Punkte-SNR-Raster wie die Nachbarkurven. Laufzeit 27,7 h und
24,2 h — die Schätzung lag bei 22,4 h.

Physikalisch plausibel: MI(K=3) ≥ MI(K=30) ≥ MI(K=∞) durchgängig, also
verliert MUX monoton, je rangärmer der Kanal wird.

**Damit ist jede Familie der Quelle vollständig**, je 5×4 über
N ∈ {1,2,4,8,16} und M ∈ {4,16,64,256}: `bHalf`, `rule_mux` (K = 0/3/30/∞),
`bf_rayleigh` (K = 0/3/30), `bf_ideal`, `bf_analog` (K = 3/30).

**Zwei Aussagen sind damit überholt** und am 2026-10-15 im Code korrigiert:

- „MUX fixedB fehlt M = 256 bei 8×8 und 16×16" (`run_mimo_comparison_sweep.m`,
  `analyze_bf_vs_mux_qam.m`) — `bHalf` trägt alle fünf N für M = 256 (B = 7).
- „die Rice-Läufe rechnen nur N ≤ 4" (`run_mimo_comparison_distance.m`,
  `analyze_bf_vs_mux_qam.m`) — sie reichen bis N = 16.

**Der Export ist aber noch nicht nachgezogen.** Auf der Gearbox-Seite stehen
heute:

| Ordner unter `data/` | N heute | N nach dem Export |
|---|---|---|
| `SE_data_mux_scaledB_K3/_K30` | 1, 2, 4 | 1, 2, 4, 8, 16 |
| `SE_data_bf_scaledB_K3/_K30` | 1, 2, 4 | wird zu `SE_data_bf_fixedB_K3/_K30` (E8), 1…16 |
| `SE_data_abf_fixedB_K3/_K30/_KInf` | 1…16 | unverändert |

**Was das freischaltet:** `analyze_bf_vs_mux_qam` brauchte `capN = 4`, weil
die Kanalachse sonst zwei Rasterweiten mischte (K = 0 bis 16, Rice bis 4).
Nach dem Export stehen alle Kanäle auf demselben Raster — die Deckelung
entfällt, und der Kanaltrend wird auf dem vollen Gitter lesbar. Das ist die
inhaltliche Verbesserung, die die zwei Kurven bringen.

**Nebenbefund, kein Hindernis:** in `mi_Nt16_Nr16_M256_B11_KInf.mat` (alt,
`nMC = 1`) sind an den vier untersten SNR-Punkten `lower` und `upper`
vertauscht, um ≤ 0,8 % bei MI ≈ 3,2. Der Export nimmt `results.lower`, dort
wäre die exportierte SE an diesen vier Punkten also geringfügig optimistisch
statt konservativ. Ursache: bei `nMC = 1` fallen die beiden Schranken fast
zusammen, und das Schätzrauschen dreht die Reihenfolge. Die beiden **neuen**
Dateien zeigen keine solche Verletzung.

### 3.2 Die Gearbox-Läufe, in dieser Reihenfolge

| # | Schritt | Was gegen was | Umfang |
|---|---|---|---|
| 1 | `export_mimo_comparison_curves` | *vergleicht nichts* — legt die Vergleichsbasis: sechs Kurvenordner MUX / BF / ideales BF × `fixedB` / `scaledB`, dazu fünf Rice-Ordner | **✓ gelaufen 2026-10-15** (`079372c`): 12 Ordner, keine Warnung. `SE_data_mux_scaledB_K3/_K30` von 8 auf 16 Kurven (N bis 16), `SE_data_bf_fixedB_K3/_K30` neu (= Deckelungsreferenz für Schritt 2), `SE_data_bf_scaledB_K3/_K30` gelöscht (vor E8). Alle Kurven nach E12 gedeckelt |
| 2 | `export_dbf_dac_curves` | *vergleicht nichts* — je DAC-Stufe ein Ordner, damit Schritt 3 die Stufen gegeneinander stellen kann | **✓ gelaufen 2026-10-15** (`9ca8ce9`): 41 Ordner, keine Warnung, beide Deckelungen wirksam (E12 an der Alphabetgrenze, E4 gegen die Ideal-DAC-Kurve). Dabei einen Fehler behoben, der **alle 24 K=0-Ordner** bei jedem Lauf übersprang — siehe unten |
| 3 | `run_dbf_dac_distance` | **idealer DAC gegen 4 endliche Stufen** (plus Minimum über die Stufen), dazu gemeinsame gegen antennenweise Aussteuerung, 3 DAC-Leistungsmodelle, 2 LO-Fälle — über die Distanz. Die analogen Varianten laufen als Referenz mit, weil das DAC-Modell auch sie trifft | 25 Worker; rechnet die 18 vorhandenen Dateien neu (E9) und die Kanäle `ray3`/`ray30` |
| 4 | `run_analog_bf_distance` | **analoges gegen digitales BF bei gleicher Kurve**: 3 Phasenschieber-Varianten (aktiv / passiv kompensiert / passiv mit Strafe) gegen die digitale Kette mit 4 LO-Fällen (gemeinsam, 4 / 12,5 / 17 mW je Mischer), 2 ADC-Modelle | jetzt mit 9 Rice-Varianten (AP3), ~20 min mehr |
| 5 | `run_mimo_comparison_distance` (3b) | **BF gegen MUX über die Distanz**, 11 Varianten auf *demselben* Raster: ADC-Regel (`fixedB`/`scaledB`/`alphabetB`) × Kanal (Rayleigh K = 0, Rice 3 / 30, Rang 1), bei 2 Raten und 25 Distanzen | die neuen und umbenannten Varianten |
| 6 | `run_mimo_comparison_sweep` (3a) | **dasselbe BF/MUX-Paar über die volle Ratenachse** statt zwei Raten — 100 Ratenpunkte bei 50 / 500 / 5000 m, aber nur K = 0. Hier wird der Gangwechsel sichtbar, nicht in 3b | `mux_alphabetB` (kommt von selbst, sobald exportiert) — 100 Kerne, 8 h je Lauf. **Die 5 Rice-Varianten dagegen nicht:** `run_mimo_comparison_sweep.m:33` trägt eine feste Liste der sechs K = 0-Fälle, nur `mux_alphabetB` kommt bedingt dazu (Zeile 41). Wer 3a heute startet, bekommt keinen Rice-Lauf. Dafür müssen `mux_scaledB_K3/_K30/_KInf` und `bf_fixedB_K3/_K30` in `VARIANTS` — eine Codeänderung, kein Lauf |
| 7 | `analyze_rice_comparison`, `analyze_bf_vs_mux_qam` | **q = E_bit(BF) / E_bit(MUX)** als Hüllkurve über (M, N) — jeder Modus darf seine beste Konfiguration wählen, q < 1 heißt BF günstiger. Daraus **K\***, der Rice-Faktor, ab dem BF gewinnt | **K\* neu bestimmen** |

**Welche Achse welcher Lauf aufspannt** — das ist der Grund, warum es 3a *und*
3b gibt und keiner von beiden den anderen ersetzt:

| Lauf | Distanz | Rate | Kanal | ADC-Regel |
|---|---|---|---|---|
| 3b | 25 Punkte, 10 m…10 km | **2** (1 Mbit/s, 1 Gbit/s) | K = 0, 3, 30, ∞ | `fixedB`, `scaledB`, `alphabetB`¹ |
| 3a | **3** (50, 500, 5000 m) | 100 Punkte, 10³…10¹¹ bit/s | nur K = 0 | `fixedB`, `scaledB`, `alphabetB`¹ |

¹ `alphabetB` kommt in beiden Läufen nur dazu, wenn `SE_data_mux_alphabetB`
exportiert ist — beide prüfen den Ordner selbst. Die Regel ist MUX-only: bei
Beamforming kommt **ein** Strom an, das beobachtete Alphabet ist M unabhängig
von N_t, und `adcBitsRule` fällt dort mit `fixedB` zusammen. Ein
BF-`alphabetB`-Lauf wäre bitgleich zu `bf_fixedB`.

Schritt 1 **muss** vor 2 laufen, sonst warnt der Export mit
`export:noDacCapRef` und schreibt die Rice-DAC-Kurven ungedeckelt.

**Der K=0-Fehler in Schritt 2 (behoben 2026-10-15).** Der erste Lauf schrieb
nur 17 der 41 Ordner. Ursache war kein fehlendes Datum, sondern der Test „trägt
die Quelle dieses K überhaupt?": für K = 0 lautete er
`dir(strrep(pattern, '*.mat', '*[0-9].mat'))` und sollte „endet auf eine
Ziffer, also kein `_K`-Suffix" heißen. **MATLABs `dir` kennt keine
Zeichenklassen** — es suchte wörtlich nach `[0-9]`, fand nie etwas, und
damit wurden **alle 24 K=0-Ordner bei jedem Lauf übersprungen**. Die
vorhandenen stammten von vor dieser Prüfung.

Was das gekostet hat, über die fehlende E12-Deckelung hinaus:
`SE_data_bf_fixedB_dac{1,2,3}_common` und
`SE_data_bflosd_fixedB_dac{1,2,3}_common` waren **nie geschrieben worden**.
Die gemeinsame Aussteuerung ist seit E9 der Standardfall, und
`run_dbf_dac_distance` verweigert einen Kanal ohne diese Ordner
(`commonIncomplete`) — der Standardfall war also nur für Stufe 0 rechenbar.
Jetzt liegen alle vier Stufen für alle fünf Kanäle vor, je Antenne **und**
gemeinsam.

**Doppelte Rechnungen fallen jetzt weg (neu, 2026-10-14).** Sieben der elf
Ergebnisschlüssel je 3a-Ordner hängen nicht an der Variante — die SISO-Gänge
lesen die 24 Kurven, die in allen 36 `SE_data*`-Ordnern inhaltsgleich liegen.
Gemessen: E_bit stimmt über alle sechs Varianten auf 2e-9 überein, also
**105 von 486 Konfigurations-Sweeps = 21,6 % der Laufzeit von 3a** waren
Wiederholung. Ein Ergebnisspeicher unter `results/_store/`, adressiert über
den Fingerabdruck der Rechnung, nimmt sie jetzt heraus; die sprechenden
Ordner- und Dateinamen bleiben unverändert. Einzelheiten, Messbefehle und
was bewusst offen bleibt: `RESULT_NAMING.md`.

**Was alle Vergleiche tragen und wo sie brechen können.** Alle sechs
Grundvarianten laufen im Gearbox-Modus `multiplexing`: der Array-Effekt steckt
**in der Kurve** (MUX: N Ströme; Rayleigh-BF: E[λ_max]; ideales BF:
deterministischer Gewinn N_t·N_r als Verschiebung der SNR-Achse), das
Linkbudget bekommt nichts gutgeschrieben, und die Hardware skaliert je Kette
gleich. Der Unterschied zwischen den Verfahren liegt damit **allein in der
Kurve** — deshalb ist der Vergleich überhaupt zulässig. Zwei Stellen, an denen
er kippen würde, und beide sind abgesichert:

- **Ungleiche (M, N)-Auswahl.** Fehlt eine Kombination auf einer Seite, gewinnt
  die andere allein durch die größere Auswahl. `analyze_bf_vs_mux_qam`
  maskiert deshalb je Zelle **symmetrisch** über `E_per_bit_all` und
  `antennaConfigsUsed`, nicht über die schon gebildete Hüllkurve.
- **Ungedeckelte DAC-Kurven.** Ohne E4 liegt eine gröbere Stufe stellenweise
  über der feineren, und `minOverDacLevels` wählt sie dann genau deswegen.

**Wo diese sieben Schritte laufen (neu, 2026-10-14).** Auf dem Windows-Cluster
wie bisher — oder auf dem **ZIH-Cluster** der TU Dresden (Barnard/Romeo, Linux
+ SLURM): `sbatch hpc/zih/submit_study.sbatch <Treiber>`. Das Clusterprofil
und die Workerzahl kommen jetzt aus `+sweep/poolProfile.m` bzw.
`+sweep/workerBudget.m`, die Ergebniswurzel aus `GEARBOXPHY_RESULTS_ROOT`;
ohne gesetzte Variablen ist alles bitgleich zu vorher. **Auf dem ZIH-Cluster
ist noch nichts gelaufen** — Schritt 0 des Runbooks ist Pflicht.
Anleitung: `HPC_RUNBOOK_ZIH.md`.

Die **MI-Kurven aus 3.1 bleiben auf Windows**: ihre parallele Achse sind die
400 Kanalrealisierungen je SNR-Punkt, und 200 Worker (2 Wellen) sind dort
schneller als 104 Kerne eines Barnard-Knotens (4 Wellen) — 22,4 h gegen 45 h.
`QuantizedMimoMI` ist für den ZIH-Cluster deshalb bewusst nicht angepasst.

**K\* = 16,5 bei 56 m ist überholt** — die Zahl entstand unter BF-`scaledB`
und verschiebt sich durch E8 zu kleinerem K.

### 3.3 Nach jeder Änderung an Sweep oder Speichern

`tests/smoke_test.m` und `tests/mimo_smoke_test.m` ausführen, nicht nur die
Unit-Suite: nur diese zwei fahren `runSweep` und die Speicherebene. Ein
Fehler dort stand am 2026-10-13 in main, während die Suite 85/85 meldete.

### 3.4 Welcher Lauf für welchen Vergleich

Die Zuordnung in beide Richtungen: jeder Lauf hat einen Abnehmer, und jede
Auswertung aus Abschnitt 1 hat eine Quelle. Wo eine Spalte leer bleibt, ist
das ein offener Punkt und keine Auslassung.

| Lauf | Ausgabe | Beabsichtigter Vergleich | Wird gelesen von |
|---|---|---|---|
| `export_mimo_comparison_curves` | `data/SE_data_<variante>/` | — (legt die Vergleichsbasis) | 3a, 3b, Schritt 2 als Deckelungsreferenz |
| `export_dbf_dac_curves` | `data/SE_data_..._dac<k>[_common]/` | — (eine Stufe je Ordner) | `run_dbf_dac_distance` |
| **3a** `run_mimo_comparison_sweep` | `results/cmp_<variante>_d<d>/` | BF ↔ MUX **über die Rate**; ADC-Regel `fixedB` ↔ `scaledB` | `analyze_mimo_comparison`, `analyze_adc_rule`, `analyze_adc_rule_all`, `analyze_adc_rule_curves`, `analyze_best_gear` (Teil B), `analyze_bf_vs_mux_qam` (Ratenachse) |
| **3b** `run_mimo_comparison_distance` | `results/cmp_distance_<variante>.mat` | BF ↔ MUX **über Distanz und Kanal** (K = 0 / 3 / 30 / Rang 1) | `analyze_bf_vs_mux_qam` (**Hauptquelle**), `analyze_rice_comparison`, `analyze_best_gear` (Teil A), `analyze_mimo_comparison` (Distanzschnitt) |
| `run_siso_vs_mimo_scaledB` | `results/cmp_sisomimo_scaledB_d<d>/` | SISO ↔ MIMO, **aufgelöst nach N** statt als Hüllkurve | `analyze_siso_vs_mimo`, `analyze_siso_vs_mimo_gf` |
| `run_analog_bf_distance` | `results/abf_distance_<variante>_<adc>.mat` | **analoges ↔ digitales BF** bei gleicher Kurve; 3 Phasenschieber, 4 LO-Fälle, 2 ADC-Modelle | `analyze_analog_bf` |
| `run_analog_bf_mixed_distance` | `results/abfmix_distance_<variante>_<lo>.mat` | gemischte Architekturen (analoger Sender ↔ digitaler Empfänger und umgekehrt) × LO-Fälle | **niemand** — noch nie gelaufen (0 Dateien), und es gibt keine Auswertung dafür |
| `run_dbf_dac_distance` | `results/dbfdac_distance_*.mat`, `abfdac_distance_*.mat` | **idealer ↔ endlicher DAC** (4 Stufen), `common` ↔ `perAntenna`, 3 DAC-Leistungsmodelle | `analyze_dbf_dac` (seit 2026-10-15) |
| `run_dbf_dac_los_newhw` | dieselben Dateinamen, Satz `hw_new` | alte ↔ survey-gestützte Hardwaremodelle im LOS-Fall | `analyze_dbf_dac`, wo `hw_new` als weitere Spalte erscheint |

**Eine leere Zelle bleibt:** `run_analog_bf_mixed_distance` — nie gelaufen
(0 Dateien) und ohne Auswertung. Für `dbf_dac` ist die Lücke seit dem
2026-10-15 geschlossen, die Reihenfolge in 3.2 ist damit schlüssig: Schritt 3
rechnet, und etwas liest es.

**Kein Abnehmer heißt nicht wertlos:** `run_dbf_dac_distance` liefert `Ebest`
und `kBest` (beste DAC-Stufe je Punkt) schon in der Datei, die Zahlen sind
also da. Es fehlt die Stelle, die sie zu einer Aussage zusammenzieht.

---

## 4. Entscheidungen

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
| E12 | MI-Kurven beim Export an der Alphabetgrenze deckeln (wie E4), nicht nur warnen — `log₂M` bei BF, `N_t·log₂M` bei MUX |

**Offen.**

| # | Frage | Empfehlung |
|---|---|---|
| E6 | N > 16? | nein — `alphabetB` dort nicht rechenbar, Phasenquantisierung verliert ohnehin |
| E7 | `isfile`-Aussetzer auf dem UNC-Share? | **entschärft 2026-10-15**: `filterAvailableAntennaConfigs` verwirft einen Kandidaten nur noch, wenn **beide** Prüfungen ihn nicht finden (Verzeichnisliste *und* `isfile`), und die Liste wird je Ordner gecacht — ein Share-Zugriff statt 20 je Aufruf, rund 157 000 je Vollauf von Schritt 3. Dazu `+data/findFeasibilityHoles.m`, das die Folge nachweist statt sie zu vermuten. Befund über alle 68 Ergebnisdateien: eine betroffen, 2 Zellen |
| E11 | Golden Master belastbar machen? | je Testmethode seeden **und** Toleranz auf die echte Streuung weiten (E_bit ~1e-2, γ ~1e-1) |

Zu **E11**: `qamMatchesOriginal` und `naQamMatchesOriginal` vergleichen zwei
Zufalls-Optimierer auf RelTol 1e-6 — beide Seiten ziehen ungeseedet aus dem
globalen Strom. Gemessene Streuung: 0,42 % in E_bit, 4,4 % in γ, wobei die
neue Seite das bessere Optimum findet. Grün über die Dateiform, rot über die
Ordnerform; der Mechanismus dahinter ist nicht aufgeklärt. Einen Seed zu
suchen, bei dem es grün wird, wäre Rosinenpickerei.

---

## 5. Grenzen, die in jede Aussage gehören

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
- **Die Schätzung überschritt die Alphabetgrenze** am Sättigungsende: BF bis
  +0,78 %, MUX bis +0,05 %, systematisch steigend mit N (Median je N:
  0,04 / 0,05 / 0,18 / 0,29 % für N = 2/4/8/16). Das begünstigte BF entlang
  genau der Achse, die der Vergleich messen soll. **Seit E12 wird gedeckelt**
  (`QuantizedMimoMI 12213cc`); die Felder `seCapRef`, `seCapPoints` und
  `seCapMaxRel` je Kurve machen es nachlesbar. Kurven aus früheren Exporten
  tragen die Felder nicht und sind ungedeckelt.
- **Phasenquantisierung** `G = 1 + (N−1)·sinc²` ist gegenüber echter Rundung
  leicht pessimistisch (≤ 1,1 dB bei 1 bit) — wirkt gegen analog.

---

## 6. Wo die Begründungen stehen

| Thema | Ort |
|---|---|
| Ablauf der Läufe, Schritt für Schritt | `HPC_RUNBOOK_MIMO_VERGLEICH.md`, `HPC_RUNBOOK_ANALOG_BF.md`, `HPC_RUNBOOK_DAC.md` |
| Zweiter Cluster (ZIH, SLURM): Einrichtung, Schritt 0, Ressourcen je Studie | `HPC_RUNBOOK_ZIH.md`, `hpc/zih/README.md` |
| Doppelt gerechnete Teilkonfigurationen, Namenskonvention der Ergebnisdateien | `RESULT_NAMING.md` |
| Wandler- und Hardwaremodelle | `ADC_POWER_MODEL.md`, `DAC_POWER_MODEL.md`, `LNA_POWER_MODEL.md`, `HARDWARE_MODEL_SWITCH.md` |
| DAC-Quantisierung, Aussteuerung | `DAC_QUANTISATION_SPEC.md` |
| Rice-Erweiterung, analoges BF | `RICE_EXTENSION_PLAN.md`, `ANALOG_BEAMFORMING.md`, `PHASE_SHIFTER_POWER_MODEL.md` |
| Code-Abgleich mit dem HPC | `codeManifest('snapshot')` im Ordner `code_manifest/` |
| Warum eine Entscheidung so fiel | die Commit-Nachricht, die sie umsetzt |
