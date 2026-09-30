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

cd /workspace/GearboxPHY-MIMO/gearboxphy_framework
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
cd /workspace/GearboxPHY-MIMO/gearboxphy_framework
export_mimo_comparison_curves
```

Legt sechs Ordner an: `SE_data_mux_V0/_V1`, `SE_data_bf_V0/_V1` und
`SE_data_bfideal_V0/_V1`. `SE_data` selbst bleibt unangetastet.

Zwei Ausgaben prüfen:
1. **Vollständigkeitstabelle** — jede Zelle `NxN B=..`, kein `FEHLT`/`FALSCH`.
2. **Querprüfung 1×1**, getrennt nach Kanal — in den vier Rayleigh-Ordnern
   und in den zwei AWGN-Ordnern jeweils `gleich`. Eine `ABWEICHUNG` heißt,
   dass die Läufe aus Schritt 1 nicht dieselben Einstellungen hatten (Seed,
   nMC, SNR-Raster). Dass sich die 1×1-Kurven *zwischen* Rayleigh und AWGN
   unterscheiden, ist gewollt.

### Schritt 3 — Gearbox-Sweeps

```matlab
run_mimo_comparison_sweep          % 3a: R_eff-Sweep, 6 Varianten x 3 Distanzen
run_mimo_comparison_distance       % 3b: Distanzschnitt bei 1 Mbit/s und 1 Gbit/s
```

| | Ressourcen | Ausgabe |
|---|---|---|
| 3a | 100 Kerne (mehr bringt nichts: 100 Ratenpunkte), 64 GB, 12 h | `results_cmp_<variante>_d<d>/` |
| 3b | 32 Kerne (25 Distanzen), 64 GB, 6 h | `results_cmp_distance_<variante>.mat` |

Beide unterbrechbar bzw. je Variante gespeichert.

### Schritt 4 — Auswertung

```matlab
out = analyze_mimo_comparison();
```

Schreibt nach `results_cmp_figures/`:
- `cmp_ebit.png` — E_bit über R_eff: SISO (schwarz, Rayleigh), bestes MUX (blau),
  bestes BF (rot), bestes BF ideal (gelb); V0 durchgezogen, V1 gestrichelt
- `cmp_nopt.png` — energieoptimale Antennenzahl
- `cmp_adc_share.png` — ADC-Anteil im Optimum: was die Regel kostet
- `cmp_distance.png` — Distanzschnitt
- `summary.mat`

Dazu eine Tabelle in der Konsole. Der „beste Modus" dort wird nur unter
den Rayleigh-Modellen bestimmt; BF ideal steht als Obergrenze daneben.

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

`GearboxPHY-MIMO/gearboxphy_framework/`

| Datei | |
|---|---|
| `+gearboxphy/+data/loadSECurve.m` | liest `sourceB`/`snrReference`, Schutz |
| `+gearboxphy/+gears/qamGear.m` | ADC/DAC getrennt, ADC aus `sourceB` |
| `+gearboxphy/+gears/naQamGear.m` | dito |
| `validate_mimo_comparison.m` | neu — Schritt 0, Gearbox-Seite |
| `export_mimo_comparison_curves.m` | neu — Schritt 2 |
| `run_mimo_comparison_sweep.m` | neu — Schritt 3a |
| `run_mimo_comparison_distance.m` | neu — Schritt 3b |
| `analyze_mimo_comparison.m` | neu — Schritt 4 |
| `mimo_smoke_test.m` | läuft auf `SE_data_mux_V0`, Physik-Assertion entschärft |

Der laufende V0-Job ist von keiner dieser Änderungen betroffen, auch nicht,
wenn die Dateien während des Laufs synchronisiert werden: `allBounds` rechnet
mit dem Default exakt wie vorher, in derselben Zufallsstrom-Reihenfolge, und
alle anderen Änderungen liegen in Dateien, die der Job nicht aufruft.

## Grenzen, die in die Auswertung gehören

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
- **Nur QAM mit M ≤ 256 im Vergleich.** ZXM, Pulse, NA-QAM und QAM M = 1024
  haben nur Gasts AWGN-Kurven; sie laufen in den Ordnern mit, werden aber
  nicht ausgewertet.
