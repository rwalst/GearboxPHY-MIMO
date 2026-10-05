# Präkodiertes Multiplexing: die CSI-Verzerrung schließen

## Warum

Der BF/MUX-Vergleich ist in allem kontrolliert bis auf eine Achse: **die
Kanalkenntnis am Sender.** Beamforming nutzt `v₁`, Multiplexing nutzt
nichts — gleiche Leistung auf alle Ströme, Einheitsmatrix.

Dass das MUX benachteiligt, braucht keine Simulation: Die Einheitsmatrix
liegt in der Menge der zulässigen Präkodierer, ein über `F` optimierendes
MUX ist also mindestens so gut wie das heutige. **Die ausgewiesene
MUX-Zahl ist eine untere Schranke.**

Wie viel ungenutzt bleibt, zeigen die mittleren Eigenwerte von `HᴴH`:
bei 4×4 sind das 9,74 / 4,39 / 1,56 / 0,25 — ein Verhältnis von 39, und
der schwächste Modus bekommt denselben Leistungsanteil wie der stärkste.

Strukturell vergleicht die Studie heute „1 Strom mit CSIT" gegen „N
Ströme ohne CSIT". Beamforming ist dabei der Einstrom-Sonderfall
optimaler CSIT-Übertragung — bei niedriger SNR legt Water-Filling alles
auf den stärksten Modus, und das *ist* MRT. **Das Ziel dieser Erweiterung
ist nicht ein anderer Gewinner, sondern die fehlende Mitte:** wie viele
Ströme lohnen sich, wenn beide Seiten dieselbe Kanalkenntnis haben?

## Modell

    y = H·F·x + n,   yq = Q_b(y)   je Antenne und je Re/Im
    F = V·diag(√p),  V aus der SVD von H = U·Σ·Vᴴ
    Nebenbedingung: ‖F‖_F² = Σ pᵢ = 1

`V` dreht auf die Eigenmoden, `p` verteilt die Leistung darauf. Mit `p =
(1,0,…,0)` ist `F = v₁` — **das ist exakt der heutige BF-Präkodierer**,
und genau daraus wird der schärfste Test (V2 unten).

### Leistungsverteilung: drei Stufen, aufsteigend im Aufwand

1. **Gauß-Water-Filling** über `λᵢ` beim jeweiligen Arbeits-SNR.
   Standard, in zwei Zeilen hingeschrieben, und für die Frage „wie viele
   Moden lohnen sich" ausreichend, weil die Modenauswahl das Entscheidende
   ist.
2. **Gleiche Leistung auf eine ausgewählte Teilmenge** der Moden (Modus-
   auswahl ohne Feinverteilung). Als Kontrolle: liefert sie fast dasselbe,
   hängt das Ergebnis an der Auswahl und nicht an der Verteilung.
3. **Mercury/Water-Filling** (Lozano, Tulino, Verdú) — die für ein
   *endliches* Alphabet korrekte Verteilung; Gauß-Water-Filling
   überschätzt den Nutzen zusätzlicher Leistung auf einem bereits
   gesättigten Modus. Nur rechnen, wenn 1 und 2 sich deutlich
   unterscheiden.

Empfehlung: mit 1 und 2 starten, 3 erst bei Bedarf.

## Code: eine Zeile im Kern, wie bei BF

`ergodicMiAuto` reicht `H` heute unverändert an `miAuto`. Künftig:

    Heff = H * localPrecoderMux(H, snrDb, M, opt.alloc);   % Nr x Nt
    r    = miAuto(Heff, const, B, sigmaN, o);

Das ist derselbe Eingriff, den `ergodicMiBeamforming` mit `H*v₁` schon
macht. **Der MI-Kern bleibt unberührt**: `Heff` ist weiter `Nr × Nt`,
Tier-Wahl, Enumeration und Chunking ändern sich nicht.

| Datei | Änderung |
|---|---|
| `qam/core/precoderMux.m` | neu — `V·diag(√p)`, Verteilung über `opt.alloc` |
| `qam/core/ergodicMiAuto.m` | `opt.precoder` (Default `"none"` = heute, bitgleich) |
| `qam/sweep/runRuleSweep.m` | `opt.precoder` durchreichen, in den Dateinamen |
| `qam/sweep/runQamSweepMuxCsit.m` | neu — Treiber |
| `qam/validate/validatePrecodedMux.m` | neu — V1–V5 |

**Der Präkodierer hängt vom SNR ab** (Water-Filling tut das), wird also je
Realisierung UND je SNR-Punkt gebildet. Eine SVD je Ziehung ist gegenüber
der MI-Rechnung kostenlos.

## Die Normierung ist die Stelle, an der es schiefgehen kann

Heute normiert `qamConstellation` auf `Es = 1` **je Strom**; die
Gesamtsendeleistung ist damit `N_t`, und `exportToGearboxSEData` schiebt
die SNR-Achse um `10·log₁₀(N_t)`. Das war einer der vier
Modellasymmetrien, die für diese Studie geschlossen wurden.

Mit `‖F‖_F² = 1` ist die Gesamtleistung **1**, genau wie bei BF. Die
präkodierten Kurven tragen deshalb `snrReference = 'total'` und dürfen
**nicht** verschoben werden. Wird das übersehen, bekommt das präkodierte
MUX `10·log₁₀(N_t)` dB geschenkt — bei 4×4 sechs dB, also mehr als der
gesamte zu messende Effekt.

## Validierung (Schritt 0, vor dem Clusterlauf)

| | Prüfung | Kriterium |
|---|---|---|
| V1 | `precoder="none"` gegen die vorhandenen Kurven | **bitgleich** |
| V2 | `p = (1,0,…,0)` erzwungen | **bitgleich** zu `ergodicMiBeamforming`, inklusive Phasenkonvention |
| V3 | Leistungsnormierung | `‖F‖_F² = 1` für jedes `H` und jedes SNR |
| V4 | Monotonie | präkodiertes MUX ≥ Open-Loop-MUX an jedem SNR-Punkt (Einheitsmatrix liegt in der zulässigen Menge) |
| V5 | Grenzfall niedriges SNR | Water-Filling wählt genau einen Modus; MI fällt auf die BF-Kurve |

**V2 ist der entscheidende Test.** Er verbindet den neuen Pfad mit dem
bestehenden BF-Pfad und würde jede Verwechslung in Normierung, Phase oder
Spaltenreihenfolge der SVD sofort zeigen. V4 ist die Probe auf das
Argument, mit dem die Erweiterung überhaupt begründet wird — schlägt es
fehl, stimmt die Normierung nicht.

## Zuschnitt

- **Nur `scaledB`**, nur **K = 0**, `N ∈ {1,2,4}`, `M ∈ {4,16,64,256}`:
  12 Kurven. Die ADC-Regel und der Rice-Faktor sind getrennte Fragen und
  dürfen hier nicht mitvariieren.
- **Dieselben Kanalziehungen** wie MUX und BF (gleicher Threefry-Strom) —
  der Vergleich bleibt gepaart und die MC-Streuung kürzt sich in der
  Differenz.
- **Aufwand:** die MI-Kosten ändern sich durch das Präkodieren nicht
  (`M^Nt` bleibt `M^Nt`), also etwa ein MUX-Lauf: in der Größenordnung
  der 18 h, die `N ≤ 4` beim vorhandenen `scaledB`-Lauf gekostet hat.

## Gearbox-Seite

Eine weitere Variante, wie beim Rice-Sweep: `SE_data_muxcsit_scaledB/`,
`results/cmp_muxcsit_scaledB_d<d>/`. `analyze_mimo_comparison` bekommt sie
in die Variantenliste; die „bester Modus"-Spalte vergleicht dann BF gegen
*beide* MUX-Fassungen.

## Die Abbildung, auf die es hinausläuft

`cmp_csit.png`: E_bit über `R_eff`, drei Kurven — Open-Loop-MUX,
präkodiertes MUX, BF — je Distanz. **Die Kennzahl ist, ob und wo BF
seinen Vorsprung behält, wenn MUX dieselbe Kanalkenntnis bekommt.**

Zusätzlich aufschlussreich und fast gratis: die Zahl der aktiven Moden im
Optimum über der Rate. Sie beantwortet die eigentliche Frage direkt — bei
niedriger Rate ein Modus (also Beamforming), bei hoher alle.

## Was die Erweiterung NICHT klärt

- **Was CSI kostet.** Training, Rückkanal, Alterung der Kanalkenntnis
  bleiben außen vor. Der Vergleich wird dadurch fair in der *Information*,
  nicht in der *Energie* ihrer Beschaffung. Das ist der ehrlichere, aber
  immer noch nicht vollständige Stand.
- **Unvollkommene CSIT.** `V` aus dem wahren `H`. Ein Schätzfehler träfe
  BF und präkodiertes MUX, nicht das Open-Loop-MUX — die Richtung dieser
  dritten Verzerrung wäre wieder eine andere.
- **N > 4.** Hängt weiter an den beiden fehlenden `fixedB`-Kurven.
