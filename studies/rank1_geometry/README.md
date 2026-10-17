# Rang 1: die drei Architekturen vergleichbar machen

Stand 2026-10-17. **Vorbereitet, nichts gerechnet.** Branches:
`GearboxPHY-MIMO rank1-geometry`, `QuantizedMimoMI rang1-geometrie`. Keiner
davon ist auf `main`.

## Die Frage

Die Spalte, die in der Studie „LOS“ heißt, ist der **Rang-1-Kanal**
`H = a_r · a_tᴴ`. Das ist Fernfeld mit λ/2-ULA, deterministisch, mit
Einträgen vom Betrag 1. In dieser Spalte rechnen die drei Architekturen
heute auf **verschiedenen Geometrien**:

| | rechnet heute |
|---|---|
| Multiplexing | nur broadside (`H = ones(N)`) |
| digitales BF | gemittelt über 32 Richtungspaare (`bflosd`, DAC-Studie). Im MUX/BF-Vergleich 3b steht stattdessen `bfideal`: analytischer Gewinn, kombiniert vor **einem** ADC |
| analoges BF | broadside; der Gewinn N² gilt bei jedem Winkel, also gleichgültig |

Zwei Befunde machen das erheblich, beide gemessen am 2026-10-17
(`Groupmeetings/rank1_los_study/broadside_mi.py`, `validateRank1Geometry`):

1. **Broadside ist für MUX (fast) der schlechteste Winkel.** Dort fallen die
   meisten Summen `x_1 + … + x_Nt` zusammen.

   | 4×4, 4-QAM, unquantisiert | 0 dB | 5 dB | 10 dB | 20 dB |
   |---|---|---|---|---|
   | broadside | 3,78 | 4,06 | 4,05 | 4,05 bit |
   | 32 Richtungen, Median | 4,02 | 5,35 | 6,41 | 7,85 bit |

   Im quantisierten Modell (2×2, 4-QAM, scaledB, 15 dB) sind es 3,00 bit
   broadside gegen 3,81 bit gemittelt (G5). Unter 0 dB ist der Winkel
   gleichgültig.
2. **Broadside hat das digitale BF keine DAC-Kosten.** Die Gewichte sind reell
   und gleich, jede Antenne sendet ein ungedrehtes QAM-Symbol, und die
   DAC-Stufe +0 ist exakt (G2: |ΔMI| ≤ 2·10⁻¹⁴ bit). Bei schiefer Richtung
   kostet dieselbe Stufe bis 0,16 bit.

„Alles broadside“ ist deshalb die **BF-freundlichste Ecke** der Rang-1-Spalte.
Beide Optionen sind vorbereitet, damit der Einfluss gemessen statt vermutet
wird.

## Die beiden Optionen

| | Multiplexing | digitales BF | analoges BF |
|---|---|---|---|
| **A: alle broadside** | `mux_scaledB_KInf` (liegt vor) | **`bfr1b`** (neu) | `abf_fixedB_KInf` |
| **B: alle über 32 Richtungen** | **`mux_scaledB_r1ang`** (neu, N ≤ 4) | `bflosd` (liegt vor) | `abf_fixedB_KInf` |

Die Richtungspaare kommen für MUX und digitales BF aus **derselben** Funktion
(`QuantizedMimoMI/qam/core/rank1Directions.m`). Sie sind also garantiert
gleich.

Die analoge Seite ist in beiden Optionen dieselbe Kurve (G6: Gewinn N² bei
jedem Winkel). Ihre Distanzläufe `abfdac_distance_abfKInf_*` **gibt es aber
noch nicht**. Die vorhandenen `abfdac_distance_abf_*` stammen von der alten
`bfideal`-Referenz. Sie entstehen im selben Lauf.

**B nur bis N = 4.** Das ist eine Sensitivität, kein Ersatz für die
Hauptspalte; 8×8 und 16×16 über 32 Richtungen wären ein Vielfaches des
Aufwands. Die Auswertung stellt deshalb drei Schnitte nebeneinander:

| Schnitt | Inhalt | Zweck |
|---|---|---|
| A | broadside, N = 1…16 | die Hauptspalte, ehrlich benannt |
| A4 | broadside, N ≤ 4 | Gegenstück zu B |
| B | 32 Richtungen, N ≤ 4 | wie weit trägt broadside? |

**A4 gegen B isoliert den Winkel**: gleiche Hardware, gleiches Raster, nur die
Geometrie wechselt.

## Bezeichnung: „Rang 1“ statt „LOS“

Faktisch korrekt für den Endpunkt K = ∞, und zwar bei jedem Winkel: ein äußeres
Produkt hat Rang 1. **Nicht** für die Rice-Achse: K = 3 und K = 30 sind
vollrangig mit einem dominanten Eigenwert.

Vollständig heißt es „Rang 1, broadside“ bzw. „Rang 1, 32 Richtungen“.
Ein nacktes „Rang 1“ lädt zur Übergeneralisierung ein, denn die Ergebnisse
hängen auch am Determinismus, am Betrag 1 und für MUX am Winkel.

**Kennungen auf der Platte bleiben, wie sie sind.** An ihnen hängen
Fingerabdrücke, Ergebnisspeicher und der HPC-Bestand. Umbenannt wird die
Bedeutung, nicht der Name:

| Kennung | Bedeutung |
|---|---|
| `K = Inf`, `_KInf`, `mux_scaledB_KInf` | MUX, Rang 1, broadside |
| `bfideal` | analytischer Rang-1-Gewinn N_t·N_r, kombiniert vor **einem** ADC |
| `losd`, `bflosd`, `bf_los_digital_*` | digitales BF, Rang 1, **32 Richtungen**, ein ADC je Antenne |
| `r1b`, `bfr1b`, `bf_rank1_bs_*` | digitales BF, Rang 1, **broadside**, ein ADC je Antenne (neu) |
| `r1ang`, `rule_mux_rank1_angles` | MUX, Rang 1, **32 Richtungen**, N ≤ 4 (neu) |
| `abf_fixedB_KInf`, `abfKInf` | analoges BF, Rang 1, winkelunabhängig |
| Kanal „los“ in Kommentaren und Texten | lies: Rang 1 |

Neue Texte und Abbildungen schreiben „rank 1“ / „Rang 1“ mit Geometrie. Die
Abbildungen der Hauptauswertung sagen schon „rank 1“.

## Ablauf

Nach jedem `git pull` in MATLAB `clear functions`. Vor jedem HPC-Lauf
committen und pushen.

**QuantizedMimoMI** (Branch `rang1-geometrie`), in `qam/validate/` bzw.
`qam/sweep/`:

| | Aufruf | Ressourcen (Kopf der Datei, **nicht gemessen**) |
|---|---|---|
| 0 | `validateRank1Geometry` | lokal, Minuten. G1–G7, am 2026-10-17 bestanden |
| 1 | `runQamSweepBfRank1Broadside` | 32 Worker, 32 GB, 2 h |
| 2 | `runQamSweepMuxRank1Angles` | 64 Worker, 64 GB, 24 h |

Danach die Ergebnisordner `qam/results/bf_rank1_bs_*` und
`qam/results/rule_mux_rank1_angles` committen.

**GearboxPHY-MIMO** (Branch `rank1-geometry`), nach `setupGearboxPath`:

| | Aufruf | |
|---|---|---|
| 3 | `export_rank1_geometry_curves` | schreibt **nur** `SE_data_bfr1b_fixedB[_dac0[_common]]` und `SE_data_mux_scaledB_r1ang` |
| 4 | `run_rank1_geometry_distance` | 25 Worker, 32 GB, 4 h (Schätzung: Minuten). Prüft vorher alle Ordner |
| 5 | `analyze_rank1_geometry` | lokal, Sekunden. Nach `results/rank1_geometry/` |

## Was an Bestehendem geändert ist

Alles abwärtskompatibel, Vorgaben bitgleich:

- `QuantizedMimoMI/qam/sweep/runQamSweepBfLosDigitalDac.m`
  - nutzt `rank1Directions`; bitgleich, G1.
  - neue Optionen `BROADSIDE`, `OUT_BASE`, `FILE_TAG`, `CHANNEL_LABEL` und
    `OUT_ROOT`; ohne sie unverändert.
- `studies/digital_bf_dac/run_dbf_dac_distance.m`: Kanal `r1b` in der
  Tabelle. Fehlen seine Ordner, wird er übersprungen wie jeder andere.
- `studies/mimo_comparison/run_mimo_comparison_distance.m`: optionales
  Argument `onlyVariants`. Ohne Argument bleibt die Liste unverändert.

## Was gleich ist und was nicht

**Gleich in A und B, für alle drei Architekturen:**

- 28 GHz, 25 Distanzen von 10 m bis 10 km, 1 Mbit/s und 1 Gbit/s, M = 4…256.
- ADC `quantile5`, DAC `survey`, LNA `fom_floor`.
- LO `per_mixer` mit 12,5 mW. Auf der DAC-Seite heißt der Fall
  `lo12p5mW`. `loShared` ist dort fehlerhaft und gleich `per_mixer`, deshalb
  nicht verwendet.
- ADC-Regel je Modus nach E8: MUX `scaledB`, BF `fixedB`.
- Eine gemeinsame (M, N)-Maske über alle fünf Eingänge.

**Bewusst NICHT angeglichen**, steht in jeder Aussage dabei:

- **Kanalwissen.** Beide BF-Varianten haben perfekte CSI am Sender, MUX hat
  keine.
- **MI-Güte.** MUX ist für N ≥ 4 und M ≥ 64 eine untere Schranke, BF ist
  quasi-exakt. Das wirkt gegen MUX.
- **Phasenquantisierung des analogen BF.** Sie steckt als
  `G = 1 + (N−1)·sinc²` im Linkbudget, winkelunabhängig und leicht
  pessimistisch.
- **Vollrangiger LOS (LOS-MIMO).** Er ist nicht enthalten; dazu
  `Groupmeetings/rank1_los_study/README.md`.

**Nicht automatisch geprüft:** dass MUX- und DAC-Seite mit derselben Hardware
gerechnet sind. Beide nehmen die Standards seit dem 2026-10-15. Die Auswertung
prüft Raster und E9-Format, aber nicht die Fingerabdrücke gegeneinander.

## Offene Entscheidungen

1. **Welche Option ist die Hauptspalte?** Empfehlung:
   - A als Hauptspalte, ehrlich benannt („Rang 1, broadside“).
   - B als Sensitivität daneben.

   Wenn A4 und B weit auseinanderliegen, ist das selbst die Aussage: Das
   Rang-1-Ergebnis hängt am Winkel.
2. Ob B auf N = 8/16 erweitert wird. Nur sinnvoll, wenn A4 gegen B einen
   großen Unterschied zeigt.
3. Ob die Kennungen auf der Platte doch umbenannt werden, z. B. bei einem
   ohnehin fälligen Neurechnen.
