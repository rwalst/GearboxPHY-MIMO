# Rice-Erweiterung: den Kanal zur Variablen machen

## Warum

Der Vergleich MUX↔BF ist methodisch sauber — beide im i.i.d.-Rayleigh-Kanal,
auf denselben Realisierungen, gleiche Hardware, gleiche ADC-Regel. Sein
**Ergebnis** hängt aber am Kanal, und zwar einseitig:

- i.i.d. Rayleigh ist mit Wahrscheinlichkeit 1 vollrangig. Alle N Eigenmodi
  tragen, Multiplexing bekommt den vollen Multiplexing-Gewinn N. Genau daher
  stammt MUX' Vorsprung bei hohen Raten — es ist ein *Raten*vorteil aus N
  parallelen Strömen, kein Energievorteil je Strom.
- Bei Rang 1 verschwindet dieser Vorteil vollständig: ein nutzbarer
  Eigenmodus, die übrigen N−1 Ströme fänden keinen Kanal vor.
- Umgekehrt zahlt BF bei Rayleigh drauf: E[λ_max] bleibt hinter N_t·N_r
  zurück — 0,6 dB (2×2), 2,2 dB (4×4), 4,3 dB (8×8), 6,8 dB (16×16).

**Bei 28 GHz ist das die schwächste Annahme der Studie.** mmWave-Kanäle sind
dünn besetzt, oft von wenigen Pfaden oder einer Sichtverbindung dominiert.
Die Aussage „MUX gewinnt bei hohen Raten" gilt derzeit für genau den Kanal,
der bei dieser Trägerfrequenz am seltensten vorliegt.

**Das Ziel ist nicht ein anderer Gewinner, sondern eine Zahl:** der K-Faktor,
ab dem BF auch bei hohen Raten vorn liegt. Das ist eine deutlich stärkere
Aussage als ein Gewinner auf einem einzelnen Kanalmodell.

## Kanalmodell

    H = sqrt(K/(K+1)) · H_LOS + sqrt(1/(K+1)) · H_NLOS

- `H_NLOS`: i.i.d. CN(0, σ_H²) — exakt die heutige Ziehung.
- `H_LOS`: deterministisch, Rang 1, Einträge vom Betrag 1.
- **Leistungsnormierung:** E|h_ij|² = K/(K+1)·σ_H² + 1/(K+1)·σ_H² = σ_H²,
  unabhängig von K. Die SNR-Definition bleibt damit unverändert, und
  Kurven verschiedener K sind direkt vergleichbar. Das ist die Eigenschaft,
  an der die ganze Erweiterung hängt — sie gehört in die Validierung.
- `K = 0` ⇒ heutiger Lauf, **bitgleich**. `K → ∞` ⇒ reines LOS.

### Wahl von H_LOS: Broadside

Vorschlag `H_LOS = ones(N_r, N_t)` (ULA, beidseitig Broadside). Gründe:

1. λ_max(H_LOS H_LOS^H) = N_t·N_r **exakt** — der Grenzfall K→∞ trifft damit
   genau die Gewinnannahme von `bfideal`. Der Sweep interpoliert also
   nachweislich zwischen den beiden bereits gerechneten Endpunkten
   (`mux`/`bf` bei K=0, `bfideal` bei K=∞) statt neben ihnen zu verlaufen.
2. Keine versteckte Winkelwahl, die eine Seite begünstigt.

Allgemeine Steuervektoren `a_r(θ_r) a_t(θ_t)^H` mit
`a(θ)_n = exp(jπ n sin θ)` ändern λ_max nicht (Betrag 1 je Eintrag, Rang 1),
nur die Phasenlage gegenüber dem Quantisierungsraster. Als Option vorsehen,
nicht als Default — und falls genutzt, mit festen Winkeln, nicht gezogenen,
damit der gepaarte Vergleich erhalten bleibt.

## Code: zwei Zeilen und ein Helfer

Die Kanalziehung steht in beiden Dateien als **identische Zeile**:

    qam/core/ergodicMiAuto.m:43          H = (randn(s,Nr,Nt) + 1j*randn(s,Nr,Nt)) * sqrt(sigmaH2/2);
    qam/core/ergodicMiBeamforming.m:70   (dieselbe Zeile)

Ersetzen durch einen Aufruf eines neuen Helfers — eine Quelle für beide, wie
`adcBitsRule.m` für die Bitregel:

    qam/core/riceChannel.m   (neu)
        function H = riceChannel(s, Nr, Nt, sigmaH2, K, losOpt)
        %   K = 0 (Default) liefert BITGLEICH die bisherige Ziehung:
        %   derselbe Stream s, dieselbe Aufrufreihenfolge von randn,
        %   dieselbe Skalierung. Das ist Bedingung, nicht Wunsch --
        %   sonst ist die Regression gegen die vorhandenen Kurven wertlos.

Beide Funktionen bekommen ein zusätzliches Argument `K` (Default 0). Der
Threefry-Strom bleibt unangetastet: `randn` wird in derselben Reihenfolge und
Menge gezogen, der LOS-Anteil ist deterministisch und wird nur addiert.
Damit bleiben **MUX und BF bei jedem K gepaart** — dieselben
NLOS-Realisierungen, derselbe LOS-Anteil.

Weiter betroffen:

| Datei | Änderung |
|---|---|
| `qam/sweep/runRuleSweep.m` | `K` durchreichen, **`K` in den Dateinamen** (wie `B`) |
| `qam/sweep/runQamSweepRiceMux.m` | neu — Treiber, K-Liste |
| `qam/sweep/runQamSweepRiceBf.m` | neu — Treiber, K-Liste |
| `qam/sweep/exportToGearboxSEData.m` | `K` als Variantenbestandteil, `sourceK` in die Kurvendatei |
| `qam/validate/validateRice.m` | neu — Schritt 0, siehe unten |

## Validierung (Schritt 0, muss vor dem Clusterlauf laufen)

| | Prüfung | Kriterium |
|---|---|---|
| R1 | `K=0` gegen die vorhandenen Kurven | **bitgleich**, nicht „nah" |
| R2 | Leistungsnormierung | E\|h_ij\|² = σ_H² für K ∈ {0, 1, 10, 100}, Abweichung im MC-Rahmen |
| R3 | Rangkollaps | λ₂/λ₁ → 0 für K → ∞; λ_max → N_t·N_r |
| R4 | BF-Grenzfall | BF-MI bei großem K ≥ `miSisoAwgnQuant` bei SNR+10log₁₀(N_tN_r), Abstand ≤ der gemessenen Quantisierungslücke (0,09 bit bei B=4) |
| R5 | MUX-Grenzfall | MUX-MI bei großem K fällt auf Einstrom-MI — der Multiplexing-Gewinn verschwindet |
| R6 | Paarung | MUX und BF sehen bei jedem K dieselben H |

R4 ist der inhaltlich wichtigste Test: er verbindet die neue Rechnung mit der
bereits vorhandenen `bfideal`-Kurve. Schlägt er fehl, stimmt die
Normierung nicht.

## Sweep-Zuschnitt

**K-Werte:** 0, 3, 10, 30 (linear) plus K=∞ als die vorhandene
`bfideal`-Kurve. In dB: −∞, 4,8, 10, 14,8 dB. Typische mmWave-K-Faktoren
liegen bei 5–15 dB, der Bereich ist also dort fein genug, wo die Antwort
erwartet wird.

**K=0 ist bereits gerechnet** — das sind exakt die vorhandenen
`mux_V1`/`bf_V1`-Kurven. Neu zu rechnen sind nur K ∈ {3, 10, 30}, also drei
Läufe statt vier. Jeder entspricht im Umfang dem vorhandenen MUX-V1-Lauf
(die BF-Seite ist mit rund 100 s je Kurve vernachlässigbar); ein Job je
K-Wert bleibt damit im bisherigen Zeitfenster.

**Nur V1** — und zwar V1, nicht V0.

Ein früherer Entwurf dieses Plans schlug V0 vor, mit der Begründung, V1
verdopple die Kosten. Das ist nachgemessen **falsch**:

| | MUX V0 | MUX V1 | je SNR-Punkt |
|---|---|---|---|
| N=4, M=16 | 54 434 s (41 Pkt.) | 28 443 s (21 Pkt.) | **1328 vs 1354 s** |
| N=4, M=256 | 94 639 s (41 Pkt.) | 20 157 s (21 Pkt.) | 2308 vs 960 s |

Der Laufzeitunterschied stammt fast vollständig aus dem SNR-Raster (21 statt
41 Punkte), nicht aus der Bitzahl. Je Punkt kostet V1 bei `mldExact` dasselbe
wie V0, weil die innere Summe über M^Nt läuft und **von B unabhängig** ist;
bei M=256 war V1 sogar billiger, weil `runRuleSweep` `heavyUpper=false` aus
dem Speicherbudget ableitet — auch das kein B-Effekt. Im Zuschnitt
N ≤ 4, M ≤ 256 kosten die zusätzlichen Bits praktisch keine Rechenzeit.

Damit entscheidet die Sache:

1. **V1 ist die Regel, die die Studie vertritt.** Dass die Auflösung mit dem
   Kombinationsgewinn wächst, ist der physikalisch motivierte Fall. K* soll
   aus dem Modell kommen, für das das Paper argumentiert.
2. **V0 würde systematisch zugunsten von BF verschieben.** Gemessen bei K=0
   bewegt sich das Verhältnis BF/MUX zwischen V0 und V1 um höchstens 2,65 %,
   aber immer in dieselbe Richtung: V1 begünstigt leicht MUX. Mit V0 zu
   rechnen hieße, die Antwort mild in die Richtung zu schieben, in die das
   erwartete Ergebnis ohnehin zeigt.

Offen: Die 2,65 % sind bei K=0 gemessen. Bei hohem K wird der Kanal Rang-1
und die MUX-Ströme werden korreliert; ob die zusätzlichen Bits dort stärker
wirken, ist nicht belegt — ein weiteres Argument, die vertretene Regel zu
rechnen statt einer Näherung. V0 bleibt nachrüstbar.

**N ≤ 4, M ∈ {4,16,64,256}** — wie heute, aus demselben Grund (die acht
fehlenden MUX-Kurven). Alle K-Werte auf **derselben** Menge, sonst gewinnt
ein K allein durch die größere Auswahl.

**Umfang:** 2 Modi × 3 neue K × 3 N × 4 M = 72 Kurven, V1 only. Das liegt in der
Größenordnung eines der bisherigen BF-Läufe (200 Kerne, 64 GB, 12 h); BF ist
dabei billig (ein Strom), MUX trägt die Kosten.

## Gearbox-Seite

K wird wie eine weitere Variante behandelt — das ist die Änderung mit dem
kleinsten Eingriff, weil die ganze Maschinerie (Export, Sweep, Auswertung)
schon über eine Variantenliste läuft:

    SE_data_mux_V0_K3/ , SE_data_bf_V0_K3/ , ...
    results_cmp_mux_V0_K3_d<d>/ , ...

In `export_mimo_comparison_curves.m`, `run_mimo_comparison_sweep.m` und
`analyze_mimo_comparison.m` wird die feste `VARIANTS`-Liste aus
(Modus × K) erzeugt statt hart hingeschrieben.

## Die Abbildung, auf die es hinausläuft

`cmp_rice.png`: **E_bit über K**, bei festen (d, R) — je ein Feld für die
Kombinationen, bei denen heute MUX gewinnt (z. B. d=500 m / R=1,1e10) und
bei denen BF gewinnt (d=5000 m / R=9,5e8). Eingetragen MUX und BF, dazu
`bfideal` als Marke bei K=∞.

**Die Kennzahl: der Schnittpunkt K\*.** Ein Satz der Form „ab K\* ≈ x dB ist
Beamforming auch bei hohen Raten energieeffizienter" ist das Ergebnis, das
die Studie liefern soll.

## Reihenfolge

1. `riceChannel.m` + Argument in beiden Kernfunktionen, `K=0` als Default.
2. `validateRice.m`, **R1 zuerst** — ohne bitgleiche Reproduktion geht nichts weiter.
3. Treiber + `K` im Dateinamen.
4. Clusterlauf.
5. Export/Sweep/Auswertung auf (Modus × K) umstellen.
6. `cmp_rice.png` und K\*.

Schritt 1–3 und 5 sind lokal machbar und ungetestet auszuliefern; nur 4
braucht den Cluster.

## Was die Erweiterung NICHT klärt

- **Korrelierte NLOS-Streuung.** Rice trennt nur LOS gegen vollrangiges
  NLOS. Ein realistischer mmWave-Kanal hat auch im NLOS-Teil wenige Pfade
  und damit begrenzten Rang. Ein Cluster-Modell (Saleh-Valenzuela) wäre der
  nächste Schritt, nicht dieser.
- **CSI.** BF setzt weiter perfekte Kanalkenntnis am Sender voraus. Bei
  hohem K wird die Annahme eher leichter (der Kanal ist stabiler), aber das
  Modell misst es nicht.
- **N > 4.** Hängt weiter an den acht fehlenden MUX-Kurven.
