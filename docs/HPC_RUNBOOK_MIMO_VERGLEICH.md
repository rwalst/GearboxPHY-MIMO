# HPC-Runbook: Beamforming vs. Multiplexing + ADC-Regel

Alles ist als `.m`-Datei vorbereitet, die sich ohne Argumente starten lässt
und ihre Pfade selbst setzt. Die Ressourcen stehen jeweils im Kopfkommentar
(Repo-Konvention, keine Shell-Skripte).

**Keine dieser Dateien ist bisher ausgeführt worden.** Deshalb ist Schritt 0
Pflicht: er prüft in wenigen Minuten alles, was ohne teure Rechnung prüfbar
ist, und bricht laut ab, wenn etwas nicht stimmt.

## Was verglichen wird

| | Multiplexing (MUX) | Beamforming (BF) | BF ideal |
|---|---|---|---|
| Ströme | N | 1 (Eigen-BF, MRT mit `v₁`) | 1 |
| Kanal | i.i.d. Rayleigh, ergodisch | i.i.d. Rayleigh, **dieselbe Ziehung** | AWGN, kein Fading |
| Arraygewinn | — (steckt in N Strömen) | `λ_max(HᴴH)`, zufällig | `N_t·N_r`, deterministisch |
| ADC | je Antenne | je Antenne (digital, Kombination **nach** dem ADC) | wie vor dem ADC kombiniert |
| Hardware | N Ketten je Seite | N Ketten je Seite | N Ketten je Seite |
| SNR-Bezug | Gesamtsendeleistung | Gesamtsendeleistung | Gesamtsendeleistung |

MUX und digitales BF benutzen dieselbe Hardware und unterscheiden sich nur in
der Signalverarbeitung. **BF ideal** ist das bisherige Modell (SISO-Kurve,
voller Gewinn `N_t·N_r`) und dient als Obergrenze: der Abstand zwischen BF
ideal und BF zeigt, was Fading und Quantisierung pro Antenne kosten.

Im Gearbox laufen alle drei im Modus `multiplexing` („eine Kurve je
Antennenkonfiguration"); der Unterschied liegt allein in der Kurve. Beim
idealen BF steckt der Gewinn als Verschiebung der SNR-Achse in der Kurve —
algebraisch identisch zum alten Modus `beamforming`, aber mit einer eigenen
Kurve je N, die V1 braucht, weil die Bitzahl dort von N abhängt.

**ADC-Regel** (`QuantizedMimoMI/qam/sweep/adcBitsRule.m`):

| | Bits je reeller Dimension |
|---|---|
| V0 | `½·log₂M + 3` (unabhängig von N) |
| V1 | `½·log₂M + log₂N + 3` (+1 Bit je Verdopplung) |

Der DAC bleibt in beiden Varianten bei `½·log₂M`.

## Reihenfolge

### Schritt 0 — Validierung (Minuten, kein Pool)

```matlab
cd /workspace/QuantizedMimoMI/qam/validate
validateBfRayleigh                 % MI-Seite, T1–T8

addpath('/workspace/GearboxPHY-MIMO'); setupGearboxPath;
validate_mimo_comparison           % Gearbox-Seite, G1–G4
```

Beide enden mit „alle … bestanden" oder mit einem Fehler. **Nicht weitermachen,
wenn etwas fehlschlägt.** Besonders aussagekräftig:
- **T1** — BF mit N_t = 1 ist bitgenau MUX (Verdrahtung, Zufallsstrom, Präkodierer).
- **T3a** — bestätigt numerisch, dass die MUX-Kurven *je Strom* normiert sind
  (Verhältnis ≈ 2 statt ≈ 1). Das ist der Grund für die SNR-Korrektur.
- **T8** — die exakte AWGN-Kurve des idealen BF stimmt mit der vollen
  Enumeration überein.
- **G1** — Gasts SISO-Ergebnisse bleiben bitgenau.

### Schritt 1 — MI-Kurven (vier unabhängige Jobs, parallel möglich)

| Job | Datei (in `QuantizedMimoMI/qam/sweep/`) | Ausgabe | Ressourcen |
|---|---|---|---|
| MUX V0 | `runQamSweepBHalf` — **läuft bereits** | `qam/results_bHalf/` | 200 Kerne, 64 GB, 24 h |
| MUX V1 | `runQamSweepMuxV1` | `qam/results_rule_mux/` | 200 Kerne, 64 GB, 24 h |
| BF V0+V1 | `runQamSweepBfRayleigh` | `qam/results_bf_rayleigh/` | 200 Kerne, 64 GB, 12 h |
| BF ideal V0+V1 | `runQamSweepBfIdeal` | `qam/results_bf_ideal/` | **kein Pool, Sekunden** — exakt, keine Mittelung |

Start z. B.:

```matlab
cd /workspace/QuantizedMimoMI/qam/sweep
runQamSweepMuxV1
```

Die drei großen Läufe sind unterbrechbar: fertige Konfigurationen werden
beim Neustart übersprungen.

**Speicher im laufenden V0-Job** (Abschätzung aus den Array-Formen, nicht
gemessen). Bei 200 Workern auf 64 GB könnten diese Konfigurationen knapp
werden oder abbrechen:

| Konfiguration | Tier | je Worker | × 200 |
|---|---|---|---|
| 2×2, M = 256 | 2 (Hcond-Arrays) | ~270 MB | ~54 GB |
| 8×8, M = 256 | 3 (obere Schranke) | ~262 MB | ~52 GB |
| 16×16, M = 64 | 3 | ~262 MB | ~52 GB |
| 16×16, M = 256 | 3 | ~524 MB | ~105 GB |

Bricht der Job an einer davon ab: mit weniger Workern neu starten, die
fertigen Konfigurationen bleiben erhalten. Die neuen Läufe (V1, BF) leiten
Blockgröße und das Abschalten der schweren oberen Schranken selbst aus
150 MB/Worker ab (`runRuleSweep.m`) und haben dieses Problem nicht.

### Schritt 2 — Export in die Gearbox-Datenordner (Minuten)

```matlab
addpath('/workspace/GearboxPHY-MIMO'); setupGearboxPath;
export_mimo_comparison_curves
```

Legt sechs Ordner unter `data/` an: `SE_data_mux_V0/_V1`, `SE_data_bf_V0/_V1`
und `SE_data_bfideal_V0/_V1`. `data/SE_data` selbst bleibt unangetastet.

Zwei Ausgaben prüfen:
1. **Vollständigkeitstabelle** — jede Zelle `NxN B=..`, kein `FEHLT`/`FALSCH`.
2. **Querprüfung 1×1**, getrennt nach Kanal — in den vier Rayleigh-Ordnern
   und in den zwei AWGN-Ordnern jeweils `gleich`. Eine `ABWEICHUNG` heißt,
   dass die Läufe aus Schritt 1 nicht dieselben Einstellungen hatten (Seed,
   nMC, SNR-Raster). Dass sich die 1×1-Kurven *zwischen* Rayleigh und AWGN
   unterscheiden, ist gewollt.

### Vorablauf mit `N ≤ 4` (optional, aber empfohlen)

Schritt 2 bis 4 sind geschrieben, aber **noch nie gelaufen**. Von den 20
`(N, M)`-Kombinationen liegen 14 in allen sechs Varianten vor; vollständig
über alle Ordnungen ist `N ∈ {1, 2, 4}`. `N_LIST` bzw. `CFG.Ns` stehen
deshalb vorerst auf `[1 2 4]`.

Das ist zweierlei: ein vorläufiges Ergebnis und der erste Durchlauf der
ganzen Kette, bevor der vollständige Lauf Clusterzeit verbraucht.

**Was er nicht zeigt:** Bei `N ≤ 4` beträgt der Arraygewinn höchstens
12 dB und die ADC-Regel kostet höchstens 2 Bit. Ob Beamforming bei 16×16
noch gewinnt und ob die Regel Multiplexing dort kippt, bleibt offen — das
sind die eigentlich interessanten Fragen.

Zurückschalten auf `[1 2 4 8 16]`, sobald diese acht Kurven da sind:

| Lauf | fehlt |
|---|---|
| MUX V0 | `16×16` bei M = 4, 16, 64, 256 · `8×8` bei M = 64, 256 |
| MUX V1 | `8×8` und `16×16` bei M = 256 |

**Alle Varianten müssen auf derselben Menge laufen.** Ideales Beamforming
ist schon vollständig (20/20); mit `N` bis 16 gewänne es allein durch die
größere Auswahl.

### Schritt 3 — Gearbox-Sweeps

```matlab
run_mimo_comparison_sweep          % 3a: R_eff-Sweep, 6 Varianten x 3 Distanzen
run_mimo_comparison_distance       % 3b: Distanzschnitt bei 1 Mbit/s und 1 Gbit/s
```

| | Ressourcen | Ausgabe |
|---|---|---|
| 3a | 100 Kerne (mehr bringt nichts: 100 Ratenpunkte), 64 GB, 12 h | `results/cmp_<variante>_d<d>/` |
| 3b | 32 Kerne (25 Distanzen), 64 GB, 6 h | `results/cmp_distance_<variante>.mat` |

Beide unterbrechbar bzw. je Variante gespeichert.

### Schritt 4 — Auswertung

```matlab
out = analyze_mimo_comparison();
```

Schreibt nach `results/cmp_figures/`:
- `cmp_ebit.png` — E_bit über R_eff: SISO (schwarz, Rayleigh), bestes MUX (blau),
  bestes BF (rot), bestes BF ideal (gelb); V0 durchgezogen, V1 gestrichelt
- `cmp_nopt.png` — energieoptimale Antennenzahl
- `cmp_adc_share.png` — ADC-Anteil im Optimum: was die Regel kostet
- `cmp_distance.png` — Distanzschnitt
- `summary.mat`

Dazu eine Tabelle in der Konsole. Der „beste Modus" dort wird nur unter
den Rayleigh-Modellen bestimmt; BF ideal steht als Obergrenze daneben.

**Schritt 4 läuft auch ohne 3a.** Fehlen die `results/cmp_*_d<d>/`-Ordner,
entsteht nur `cmp_distance.png` — mit einer Warnung, nicht mit einem
Abbruch. Das ist der Normalfall am Arbeitsplatz: 3b ist dort in rund
10 Minuten seriell fertig, 3a braucht den Cluster. Umgekehrt ist 3b
schon immer optional.

Die Antennenachse von `cmp_distance.png` kommt aus `CFG.Ns` **der
Ergebnisdatei**, nicht aus `opts.Ns`. Solange 3b auf `[1 2 4]`
beschränkt ist, zeigt die Abbildung also genau das — ohne dass man
`opts.Ns` mitpflegen muss.

## Was sich am Code geändert hat

### Zwei Korrekturen am Energiemodell (betreffen alle MUX-Ergebnisse)

1. **ADC-Leistung passt jetzt zur Kurve.** `qamGear`/`naQamGear` haben den ADC
   bisher immer mit `½·log₂M` Bit bezahlt, auch für Kurven, die mit feinerem
   ADC gerechnet waren. Jetzt wird die Auflösung aus dem Feld `sourceB` der
   Kurvendatei bezahlt. Der DAC ist davon getrennt und bleibt bei `½·log₂M`.
   Ohne `sourceB` (Gasts SISO-Kurven) ändert sich nichts.
2. **SNR-Normierung.** `QuantizedMimoMI` rechnet mit `Es = 1` je Strom, das
   Gearbox mit Gesamtleistung. Multiplexing bekam dadurch 10·log₁₀(N_t) dB
   geschenkt (3/6/9/12 dB bei 2×2 … 16×16). Der Export rechnet jetzt um und
   schreibt `snrReference = 'total'`; `loadSECurve` weist Mehrstrom-Kurven
   ohne dieses Feld ab.

**Folge:** Die bisherigen Multiplexing-Ergebnisse in `results/` (und damit
die MUX-Zahlen der Folien 36–38 vom Gruppentreffen) sind mit beiden Fehlern
gerechnet und zu optimistisch für MUX. `run_sweep.m` im Multiplexing-Modus
mit `SE_data` bricht jetzt absichtlich ab, und `mimo_smoke_test.m` läuft auf
`SE_data_mux_V0`.

### Dritte Korrektur: `trimCurve` liefert jetzt streng monotone Kurven

`snrLookup` interpoliert **invers** — `interp1(SE_vec, SNR_vec, SE)` —, die
SE-Werte sind also die Stützstellen, und `interp1` lehnt sie ab, sobald ein
Wert doppelt vorkommt („Sample points must be unique"). `trimCurve` schnitt
bisher nur beim ersten Maximum ab. Das genügt nicht:

- **Exakt gerechnete Kurven** (`miSisoAwgnQuant`, ideales BF) erreichen ihr
  Plateau in doppelter Genauigkeit *vor* dem Maximum: mehrere Werte sind
  bitgleich, ein späterer ist um ~1e-15 größer. Das Maximum liegt hinter
  dem Plateau, das Plateau überlebt den Schnitt — `interp1` stürzt ab.
  Genau daran scheiterte Schritt 3b bei `bfideal_V0`.
- **MC-Kurven** haben keine exakten Plateaus, aber **Dellen**. Ein Filter
  gegen den unmittelbaren Vorgänger (`diff > 0`) reicht dafür nicht: in der
  Folge 5, 4, 5 fällt die 4 weg, die zweite 5 gilt gegenüber der 4 als
  Anstieg und landet neben der ersten 5 — wieder ein Duplikat.

`trimCurve` vergleicht jetzt gegen das **Laufmaximum der bereits behaltenen**
Punkte. Das Ergebnis ist per Konstruktion streng monoton, für jede Eingabe;
Plateau und Delle fallen in einem Durchgang weg. Von einem Plateau bleibt
der *erste* Punkt, also die niedrigste SNR, bei der die SE erreicht wird.

Geprüft über alle 160 vorhandenen Kurven: 0 nicht monoton. An Gasts
QAM-Referenzkurven ändert sich **nichts** (bitgleich). Die einzige
betroffene Referenzkurve ist `SE_MTX_1_ZXM.mat`: sie hat bei 14 dB eine
Delle von −6.4e-5, deren Punkt nun wegfällt (39 → 38 Punkte). Die alte
Fassung stürzte daran nicht ab, weil alle Werte eindeutig waren;
`snrLookup` weicht dadurch um **unter 5e-5 dB** ab.

### Neue und geänderte Dateien (zum Übertragen aufs HPC)

`QuantizedMimoMI/`

| Datei | |
|---|---|
| `qam/core/ergodicMiBeamforming.m` | neu — digitales Eigen-BF, Rayleigh, ADC je Antenne |
| `qam/core/allBounds.m` | Schalter `heavyUpper` (Default unverändert) |
| `qam/sweep/adcBitsRule.m` | neu — die Bitregel, eine Quelle für alle Läufe |
| `qam/sweep/mldChunkRows.m` | neu — Tier-2-Blockgröße aus Speicherbudget |
| `qam/sweep/runRuleSweep.m` | neu — Sweep für MUX und BF, `B` im Dateinamen |
| `qam/sweep/runQamSweepMuxV1.m` | neu — Treiber MUX V1 |
| `qam/sweep/runQamSweepBfRayleigh.m` | neu — Treiber BF V0+V1 |
| `qam/core/miSisoAwgnQuant.m` | neu — exakte AWGN-SISO-Kurve (ideales BF) |
| `qam/sweep/runQamSweepBfIdeal.m` | neu — Treiber BF ideal V0+V1 |
| `qam/sweep/exportToGearboxSEData.m` | SNR-Umrechnung, Varianten, Basisordner, 1×1 als SISO |
| `qam/validate/validateBfRayleigh.m` | neu — Schritt 0, MI-Seite |

`GearboxPHY-MIMO/`

| Datei | |
|---|---|
| `+gearboxphy/+data/loadSECurve.m` | liest `sourceB`/`snrReference`, Schutz |
| `+gearboxphy/+gears/qamGear.m` | ADC/DAC getrennt, ADC aus `sourceB` |
| `+gearboxphy/+gears/naQamGear.m` | dito |
| `studies/mimo_comparison/validate_mimo_comparison.m` | neu — Schritt 0, Gearbox-Seite |
| `studies/mimo_comparison/export_mimo_comparison_curves.m` | neu — Schritt 2 |
| `studies/mimo_comparison/run_mimo_comparison_sweep.m` | neu — Schritt 3a |
| `studies/mimo_comparison/run_mimo_comparison_distance.m` | neu — Schritt 3b |
| `studies/mimo_comparison/analyze_mimo_comparison.m` | neu — Schritt 4, läuft auch ohne 3a |
| `+gearboxphy/+optimize/trimCurve.m` | streng monoton per Laufmaximum |
| `+gearboxphy/+paths/` | neu — Wurzel/`data`/`results`, eine Pfadquelle |
| `setupGearboxPath.m` | neu — legt `studies/` und `tests/` auf den Pfad |
| `tests/mimo_smoke_test.m` | läuft auf `SE_data_mux_V0`, Physik-Assertion entschärft |

**Das Repo ist umstrukturiert** (2026-10-02): `gearboxphy_framework/` ist
aufgeloest, der Framework-Ordner IST das Repo. Skripte liegen nach Studie in
`studies/<name>/`, Kurven in `data/`, Ergebnisse in `results/` (ohne das
frühere Praefix `results_`), Doku in `docs/`. Beim Abgleich mit dem HPC
deshalb den ganzen Baum uebertragen, nicht einzelne Dateien.

Der laufende V0-Job ist von keiner dieser Änderungen betroffen, auch nicht,
wenn die Dateien während des Laufs synchronisiert werden: `allBounds` rechnet
mit dem Default exakt wie vorher, in derselben Zufallsstrom-Reihenfolge, und
alle anderen Änderungen liegen in Dateien, die der Job nicht aufruft.

## Grenzen, die in die Auswertung gehören

- **Das Kanalmodell entscheidet das Ergebnis mit — und begünstigt MUX.**
  Der Vergleich MUX↔BF ist methodisch sauber: beide laufen im
  i.i.d.-Rayleigh-Kanal, auf **denselben Realisierungen** (gleicher
  Threefry-Strom, also gepaart), mit demselben Hardwaremodell und derselben
  ADC-Regel. Digitales Eigen-Beamforming braucht **kein** LOS; es nutzt den
  stärksten Eigenmodus der jeweiligen Realisierung, der Gewinn ist
  E[λ_max].

  Aber i.i.d. Rayleigh ist der **günstigste Fall für Multiplexing**: der
  Kanal ist mit Wahrscheinlichkeit 1 vollrangig, alle N Eigenmodi tragen.
  MUX' gesamter Vorsprung bei hohen Raten ist ein *Raten*vorteil aus N
  parallelen Strömen. Bei Rang 1 verschwindet er vollständig — dann gibt
  es nur einen nutzbaren Eigenmodus, und MUX fällt auf BF zurück.
  Umgekehrt zahlt BF bei Rayleigh drauf: E[λ_max] bleibt 2,2 dB (4×4)
  bzw. 6,8 dB (16×16) hinter N_t·N_r zurück.

  **Bei 28 GHz ist das die schwächste Annahme der Studie.** mmWave-Kanäle
  sind dünn besetzt, oft von wenigen Pfaden oder einer Sichtverbindung
  dominiert, mit entsprechend begrenztem Rang. Jede Aussage der Form
  „MUX gewinnt bei hohen Raten" gilt derzeit für genau den Kanal, der bei
  dieser Trägerfrequenz am seltensten vorliegt. Aufzulösen durch den
  Rice-Sweep, siehe `RICE_EXTENSION_PLAN.md`.
- **Ideales BF idealisiert den KANAL, nicht die Wandler.** Der Abstand
  rot↔gelb ist ein reiner Kanaleffekt (Rang-1 statt Rayleigh). Die
  frühere Lesart „Kombination vor dem ADC sei ein Vorteil" ist falsch:
  nachgerechnet über einen Rang-1-LOS-Kanal bei gleicher Bitzahl ist
  digitales Quantisieren je Antenne mit anschließendem Kombinieren
  **besser** als ein Wandler auf dem kombinierten Signal (+0,09 bit bei
  M=16, B=4, N_r=3; +0,018 bei B=5; bei N_r=1 identisch). Grund: die
  Aussteuerung je Antenne hängt am kleinen Elementsignal, und die N_r
  unabhängigen Quantisierungsfehler mitteln sich beim kohärenten
  Kombinieren heraus. Die ideale Kurve ist dadurch leicht **pessimistisch**
  — konservativ, also unschädlich. `N_r` volle Ketten im Budget sind für
  eine digitale Umsetzung korrekt.
- **ADC-Leistungsmodell bei hohen Bitzahlen.** `P_ADC ∝ 2^b` (Walden) gilt
  bis etwa 10 effektive Bit; darüber ist ein Faktor 4 je Bit üblich. V1 geht
  bis 11 Bit — das Modell ist dort optimistisch.
- **CSI.** BF setzt Kanalkenntnis am Sender voraus (für `v₁`), MUX nur am
  Empfänger.
- **Phasenkonvention von `v₁`.** Mit Quantisierung hängt die MI von der Phase
  des Präkodierers ab. Sie ist fest gewählt (erstes Element reell positiv),
  nicht auf MI optimiert.
- **SNR-Raster der Rayleigh-Läufe endet bei 25 dB.** 256-QAM sättigt dort
  möglicherweise noch nicht; die Kurven wären dann am oberen Ende abgeschnitten,
  und die Spitzenrate eines Modus hinge am Raster statt am Verfahren. Der
  Export druckt je Kurve `max SE` gegen die Obergrenze — dort nachsehen. Das
  ideale BF nutzt -20…45 dB (kostet nichts) und ist davon nicht betroffen.
- **Unterschiedliche SNR-Raster der Läufe.** Beamforming wurde mit 1 dB
  gerechnet, Multiplexing V1 mit 2 dB (weil V0 so teuer war). Der Gearbox
  interpoliert ohnehin, das ist also kein Struktur-, sondern ein
  Genauigkeitsunterschied: gemessen bis zu **0,23 dB** im nötigen SNR,
  im Median 0,01 dB. Schritt 2 dünnt deshalb **alle** Rayleigh-Kurven auf
  `-15:2:25` aus, damit der Unterschied nicht einseitig eine Seite des
  Vergleichs trifft. `-15:2:25` ist Teilmenge von `-15:1:25`, es wird also
  exakt ausgewählt und nichts interpoliert. Ideales Beamforming behält
  sein feineres Raster: exakt gerechnet, weiterer Bereich, und nur eine
  Obergrenze.
- **Nur QAM mit M ≤ 256 im Vergleich.** ZXM, Pulse, NA-QAM und QAM M = 1024
  haben nur Gasts AWGN-Kurven; sie laufen in den Ordnern mit, werden aber
  nicht ausgewertet.
