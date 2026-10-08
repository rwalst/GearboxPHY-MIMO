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

Im Repo leben zwei Konventionen nebeneinander, und jede ist in ihrer
eigenen Datei die natürliche Wahl:

| | Normierung | Gesamtleistung | `snrDb` ist … |
|---|---|---|---|
| MUX heute | `qamConstellation`: `E\|x_i\|² = 1` **je Komponente** | `N_t` | SNR **je Strom** |
| BF | `‖v₁‖ = 1`, ein Strom | `1` | SNR **gesamt** |

`exportToGearboxSEData` versöhnt sie, indem es `'perStream'`-Kurven um
`10·log₁₀(N_t)` schiebt. Dahinter steckt eine einzige Invariante:

> **Die Verschiebung muss `10·log₁₀(‖F‖_F²)` sein.**

Heute sind das nur die zwei Sonderfälle `F = I` (`‖F‖_F² = N_t`) und
`F = v₁` (`‖F‖_F² = 1`).

**Das präkodierte MUX fällt genau dazwischen:** Es sieht aus wie MUX —
`N_t` Ströme, `ergodicMiAuto`, derselbe Export — ist aber wie BF
normiert. Beide Hälften der Buchführung können in **zwei
entgegengesetzte Richtungen** auseinanderlaufen:

- **Label vergessen — 6 dB Strafe.** Fehlt `snrReference` in der `.mat`,
  nimmt `exportToGearboxSEData` `'perStream'` an und schiebt um
  `+10·log₁₀(N_t)`. **Das ist der wahrscheinlichere Fehler, weil er der
  Default ist.**
- **Budget falsch — 6 dB Geschenk.** Water-Filling mit Gesamtbudget `N_t`
  statt 1 (die naheliegende Wahl „gleiche Leistung wie bisher“) und dann
  `'total'` dranschreiben, weil „präkodiertes MUX ist wie BF“.

Eine Plausibilitätsprüfung, die man instinktiv machen würde, fällt dabei
weg: mit `F = V·diag(√p)` haben die Spalten `‖f_i‖² = p_i ≠ 1`. Die
Ströme sind einzeln **nicht** mehr auf `Es = 1` normiert, die Leistung
steckt in `F`.

### Warum es nicht von selbst auffällt

`miGivenH.m:14` holt den Aussteuerungspegel aus dem *tatsächlichen*
Empfangssignal:

    Mu = Xall * H.';
    sigmaYre = sqrt(mean(abs(Mu(:)).^2)/2 + sigmaN^2/2);

Der Quantisierer skaliert sich also selbst auf das, was man ihm
hinreicht — wie eine ideale AGC. Mit falsch normiertem `H*F` passt der
ADC seinen Clipping-Pegel sauber an, die MI ist **in sich vollständig
konsistent**, und kein Test schlägt an. Der Fehler erscheint erst als
6-dB-Verschiebung auf der SE-Kurve — und dort sieht er wie ein
*Ergebnis* aus, nicht wie ein Bug. Die einzige Stelle, die überhaupt
trägt, wie viel Leistung ausgegeben wurde, ist der String
`snrReference`.

Bei 4×4 sind das `10·log₁₀(4) = 6,02` dB — mehr als der gesamte zu
messende Effekt, und systematisch in eine Richtung, hebt sich also über
die Realisierungen nicht heraus.

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
Spaltenreihenfolge der SVD sofort zeigen. Bei falschem Leistungsbudget ist
`F = √N_t·v₁`, und die Kurve käme exakt `10·log₁₀(N_t)` dB **besser** als
BF heraus — ein lautes Scheitern statt eines plausiblen Ergebnisses. V4 ist die Probe auf das
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

---

# Nachtrag nach Durchsicht des MI-Kerns (2026-10-08)

Drei Stellen, an denen der Plan oben an der Implementierung vorbeigeht —
alle drei fallen erst im Clusterlauf auf, zwei als verschwendete
Rechenzeit, eine als Fehlersuche an einem Test, der aus einem legitimen
Grund fehlschlägt. Danach, was daraus für die Wahl von `s` folgt.

## Vorab: `s`

`s` ist die **Zahl der gleichzeitig gesendeten Datenströme** — die
Spaltenzahl des Präkodierers, also die Länge von `x` in `y = H·F·x + n`
(`H`: `N_r × N_t`, `F`: `N_t × s`, `x`: `s × 1`).

Die Studie kennt bisher nur die beiden Extremwerte: Open-Loop-MUX ist
`F = I`, also `s = N_t`, und Beamforming ist `F = v₁`, also `s = 1`.
Dazwischen liegt nichts — das ist die „fehlende Mitte" aus dem Abschnitt
*Warum*.

**Drei Zahlen, die nicht zu verwechseln sind:** `N_t` Sendeantennen
(PA-Ketten), `N_r` Empfangsantennen (**Wandler**, unabhängig von `s`),
und `s` Ströme (Ratenobergrenze `s·log₂M`, Simulationskosten `M^s`,
`alphabetB`-Bits `s·½log₂M + 3`). Nach oben ist `s ≤ min(N_t, N_r)` und
praktisch durch den Kanalrang begrenzt — im Rang-1-Kanal trägt nur
`s = 1` etwas, jeder weitere Strom bekommt einen Modus mit Gewinn null.

Warum die Mitte überhaupt interessant ist, zeigen die mittleren
Eigenwerte von `HᴴH` (gemessen, i.i.d. Rayleigh): bei `N = 4` sind das
9,76 / 4,40 / 1,57 / 0,25 — die zwei stärksten Moden tragen 89 % des
Kanalgewinns, und heutiges Multiplexing legt trotzdem ein Viertel der
Leistung auf einen Modus, der 1,6 % trägt. Bei `N = 8` tragen die vier
stärksten ebenfalls 89 %.

## 1. `s` gehört in den Sweep, nicht ins Water-Filling

Der Plan oben lässt die Zahl der aktiven Moden aus dem Water-Filling
fallen. Das kollidiert mit drei Dingen im Bestand:

**`ergodicMiAuto` entscheidet die Tier-Wahl EINMAL je Konfiguration.**
Der Kopfkommentar sagt warum: sie „hängt nicht von `H` ab". Mit
Water-Filling hängt die aktive Modenzahl sehr wohl von `H` ab — und vom
SNR-Punkt. `oBase.method` und `Xall` werden aber vor dem `parfor`
gebildet und an alle Worker gebroadcastet. Die Vorberechnung wäre damit
schlicht falsch.

**Eine Nullspalte in `F` spart nichts.** `nComb = M^Nt` steht in
`ergodicMiAuto.m:31`, unabhängig davon, wie viele Spalten von `H*F`
tatsächlich Null sind. Eine Realisierung, in der Water-Filling genau
einen Modus wählt, kostet dann so viel wie das volle Multiplexing,
obwohl sie Beamforming rechnet. Der Wert bliebe richtig — die inaktiven
Komponenten von `x` tragen nichts zu `yq` bei, also auch nichts zur MI —
nur bezahlt man `M^16` für ein `M^1`-Problem.

**Richtig ist, `Heff` auf seine `s` Spalten ungleich Null zu reduzieren**
und `Xall` mit `s` Komponenten zu bauen. Dann ist `nComb = M^s`, und das
ist der eigentliche Hebel: `s = 2` ist bei jedem `M` höchstens Tier 2
(`M² ≤ 65536`), unabhängig von `N`. Die heutige 16×16-Kurve ist nicht
teuer, weil sie 16 Antennen hat, sondern weil sie 16 Ströme hat.

**Daraus folgt der Zuschnitt:** `s` wird gesweept wie `M` und `N`, mit
gleicher Leistung auf den `s` stärksten Moden — also Stufe 2 der
Leistungsverteilung als Produktionspfad, nicht Stufe 1. Water-Filling
bleibt als Gegenprobe auf EINER Konfiguration.

Das ist nicht nur billiger, es ist auch die richtige Zielfunktion.
Water-Filling maximiert die Gaußsche Rate bei fester Leistung. Das
Gearbox minimiert Energie je Bit, und der ADC-Preis hängt über die
Bit-Regel an `s`. Diese beiden Optima fallen nicht zusammen. Lässt man
das Gearbox `s` aus der Kandidatenliste wählen, beantwortet es die Frage
des Plans — „wie viele Ströme lohnen sich" — nach seinem eigenen Maß
statt nach einem fremden.

Für das Gearbox ist das **keine neue Optimierungsdimension**:
`+sweep/runSweep.m` zählt die Kandidaten aus `gear.antennaConfigs`
ohnehin durch. `s` verlängert diese Liste, mehr nicht.

## 2. Die ADC-Regel bedeutet unter Präkodierung etwas anderes

Der Zuschnitt „nur scaledB" hält die Regel konstant, aber nicht ihre
Begründung:

| Regel | heute begründet mit | unter Präkodierung |
|---|---|---|
| `fixedB` | `½log₂M`, unabhängig von allem | unverändert gültig |
| `alphabetB` | `N_t` Ströme überlagern sich | **`s`** Ströme überlagern sich → `s·½log₂M + 3` |
| `scaledB` | Amplitude je Antenne wächst mit `√N_t` | gilt so nicht mehr: die Gesamtleistung ist auf 1 normiert, nicht auf `N_t` |

`alphabetB` ist damit unter Präkodierung erstmals bei grossen Arrays
rechenbar: 16×16 mit `s = 2` und `M = 4` verlangt `B = 5` statt `B = 19`.
Genau die Zelle, an der die Regel heute die Antwort kippt (Folie 9 des
ADC-Decks: MUX geht bei 1 km von `(4,16)` auf `(4,8)` zurück), wäre dann
überhaupt erst sauber zu rechnen.

### Die Dynamik-Begründung von `scaledB` trägt unter Präkodierung nicht mehr

Das `+1 Bit je Verdopplung` kam aus der Normierung **je Strom**
(`E|x_i|² = 1`, Gesamtleistung `N_t`): der Empfangspegel je Antenne wächst
dann mit `N_t`, der Docstring von `adcBitsRule.m` nennt die gemessenen
1,0 / 4,0 / 16,0 bei `N_t` = 1/4/16.

Präkodierung erzwingt `‖F‖_F² = 1`. Damit verschwindet genau die
Inflation, aus der der `log₂N`-Term stammte. Gemessen (4000 Ziehungen je
Zelle, i.i.d. Rayleigh, gleiche Leistung auf den `s` stärksten Moden):

| `s/N` | `E\|y_m\|²` gemessen | Marchenko-Pastur | `½log₂g` [Bit] |
|---|---|---|---|
| 16/16 | 1,00 | 1,00 | 0,00 |
| 8/16, 4/8 | 1,78 | 1,79 | 0,42 |
| 4/16, 2/8, 1/4 | 2,48 | 2,49 | 0,65 |
| 2/16, 1/8 | 2,97 | 3,01 | 0,79 |
| 1/16 | 3,32 | 3,36 | 0,87 |
| `s/N → 0` | — | **4** (MP-Kante) | **1,00** |

Der Pegel hängt **nur von `s/N` ab**, nicht von `N`: `g` ist der
Mittelwert der obersten `s/N`-Quantile des Marchenko-Pastur-Gesetzes auf
`[0,4]`, läuft also von 1 (`s = N`) bis 4 (`s ≪ N`). **Die gesamte
Arraygrößen-Abhängigkeit der Dynamik ist damit analytisch auf ein Bit
beschränkt — für jedes `N`.** `scaledB` verlangt bei `N = 16` vier.

Die Spannung gibt es übrigens schon heute: der Docstring argumentiert
selbst `½log₂N_t`, die Regel nimmt `log₂N_t`. Präkodierung macht die
Frage nur unausweichlich.

### Vier Optionen, Entscheidung offen

| | Regel | Dafür | Dagegen |
|---|---|---|---|
| 1 | `log₂N_r` behalten | Kontinuität: jede vorhandene Kurve behält ihre Bedeutung, Variantenliste und Export unberührt | physikalisch nicht mehr gedeckt, ~3 Bit Überprovisionierung bei `N = 16` — und zwar in der Richtung, die große Arrays bestraft, also genau den Gewinn verdeckt, den der Lauf zeigen soll |
| 2 | `log₂s` | alle drei Regeln auf einer Achse: `+0` / `+log₂s` / `+s·½log₂M`; bei `s = 1` fallen alle drei zusammen, BF hat genau eine Regel | stützt sich auf das **Alphabet**-Argument statt auf die Dynamik (Begründungswechsel, nicht Parameterwechsel); `N_r` kommt nicht mehr vor |
| 3 | `½log₂g(s/N)` | die hergeleitete Variante | ganzzahlig gerundet ist das `fixedB` oder `fixedB+1`; `g` ist das Rayleigh-Gesetz, die Regel wäre an `K` gekoppelt und keine geschlossene Form in `(M,N,s)` mehr |
| 4 | `scaledB` weglassen | das ADC-Deck zeigt `fixedB` ≈ `scaledB` (Median 0,00 %, Spanne −5,1…+8,7 %, 293 Punkte); Option 3 sagt, die begründete Mitte liegt ≤ 1 Bit von `fixedB` — halbiert den Lauf | bricht mit der Variantenliste; `scaledB` ist die gewählte Arbeitsannahme |

**Empfehlung: 4 für den ersten Lauf, 2 falls später eine Mitte gebraucht
wird.** Die Schlussfolgerungen tragen die beiden Einfassungen; die Mitte
hat bisher keine Aussage gekippt, und unter Präkodierung wird ihre
Grundlage schwächer statt stärker. **Das ist eine Nutzerentscheidung, keine
Herleitung** — sie steht auf derselben Stufe wie die Wahl von `alphabetB`
gegen `½log₂N_t` im Oktober.

`alphabetB` ist von alldem nicht betroffen: dort steht die Antwort fest,
weil die Begründung wörtlich „`N_t` Ströme überlagern sich" lautet.

## 3. V4 kann aus einem legitimen Grund fehlschlagen

> V4: präkodiertes MUX ≥ Open-Loop-MUX an jedem SNR-Punkt … schlägt es
> fehl, stimmt die Normierung nicht.

Der Schluss trägt nicht. Die Einheitsmatrix liegt zwar in der zulässigen
Menge, aber Gauß-Water-Filling **sucht sie dort nicht**: es maximiert die
Gaußsche Kapazität, nicht die quantisierte Endalphabet-MI. Ein
Präkodierer, der für Gauß optimal ist, kann für QAM hinter einem
`B`-Bit-ADC schlechter sein als gleiche Leistung. V4 darf also als
*Diagnose* laufen, nicht als Abbruchkriterium — sonst sucht man einen
Normierungsfehler, den es nicht gibt.

**Der schärfere Test an dieser Stelle ist ein anderer.** Bei `s = N_t`
und gleicher Leistung ist `F = V/√N_t` unitär bis auf den Faktor. Für
einen *gaussverteilten* Eingang wäre das ein No-Op — `V P Vᴴ` lässt die
Kovarianz `HHᴴ` unberührt. Für QAM hinter einem Quantisierer ist es
keines: die Konstellation dreht sich gegen das feste Quantisierungsraster.
Also:

| | Prüfung | Kriterium |
|---|---|---|
| V6 | `s = N_t`, gleiche Leistung, gegen Open-Loop-MUX nach dem `10log₁₀(N_t)`-Shift | Differenz in der Größenordnung des MC-Fehlers. **Keinesfalls 3/6/9/12 dB** |

V6 misst genau die 6-dB-Falle, vor der der Plan oben warnt, und trennt
sie von echten Effekten: Was übrig bleibt, ist die Drehung gegen das
Raster — ein Messartefakt der Präkodierung, kein Informationsgewinn. Beim
Vergleich von `s = N_t` gegen Open-Loop muss dieser Rest bekannt sein,
sonst wird er als CSIT-Gewinn gelesen.

Ebenfalls zu korrigieren: `H·V` ist bei K = 0 **nicht** verteilungsgleich
zu `H`. Die Rechtsrotationsinvarianz des i.i.d.-Gauß-Kanals gilt für ein
von `H` unabhängiges unitäres `Q`; `V` stammt aus der SVD von `H` selbst,
und `H·V = U·Σ` hat orthogonale Spalten mit fallender Norm. Ein Test, der
Verteilungsgleichheit prüft, würde zu Recht scheitern.

## Wie `s` gewählt wird

### `B` ist Hardware — daraus folgt alles Weitere

Unter `alphabetB` ist `B = s·½log₂M + 3`. Schwankt `s` je
Kanalrealisierung, muss der Wandler für `s_max` ausgelegt sein; man
bezahlt dann immer den schlechtesten Fall, und genau der Vorteil kleiner
`s` ist weg. **`s` ist deshalb ein Entwurfsparameter wie `N` und `M`,
keine momentane Anpassung.**

Die Alternative — Sender passt `s` je Realisierung an, Empfänger steht
auf `s_max` — ist ein gültiges System, aber dann ist die ADC-Frage bei
`s_max` entschieden und `alphabetB` bleibt bei großen Arrays unrechenbar.
Sie gehört damit nicht in diesen Lauf.

### Das Gearbox wählt, durch Aufzählung

`+sweep/runSweep.m` probiert für jeden Punkt `(order, R, f_c)` schon
heute jeden Kandidaten aus `gear.antennaConfigs` durch und behält das
kleinste `E_bit` (MIMO_EXTENSION.md, Entscheidung 4). `s` wird ein
drittes Feld im Kandidaten-Struct, die Liste wird länger — **keine neue
Optimierungsdimension**.

Das ist auch die richtige Zielfunktion. Water-Filling maximiert die
Gaußsche Rate bei fester Leistung; das Gearbox minimiert Energie je Bit
bei fester Rate und sieht dabei den Wandlerpreis. Die beiden Optima
fallen nur zusammen, wenn der ADC gratis ist.

### Wogegen `s` abgewogen wird

| Richtung | Effekt | Größenordnung |
|---|---|---|
| **für** großes `s` | Ratenobergrenze `s·log₂M` steigt | linear |
| **gegen** | ADC: `B = s·½log₂M + 3`, `P_ADC ∝ N_r·2^B·B` (`+physics/adcPower.m`) | `M=4`, `s: 2→4` heißt `B: 5→7` — **5,6× ADC-Leistung** |
| **gegen** | der `s`-te Modus trägt nur noch `λ_s` | bei `N=4` tragen Moden 3+4 zusammen **11,4 %** der Spur, bei `N=8` die Moden 5–8 **10,9 %** |

Das Optimum liegt im Inneren und wandert mit der Rate: bei niedriger Rate
reicht ein Modus (`s = 1`, also Beamforming), bei hoher lohnen sich die
schwachen Moden trotz Wandlerpreis. Unter `fixedB` ist `s` beim ADC
gratis und das Optimum rutscht nach oben, unter `alphabetB` nach unten.
**Diese Verschiebung ist das Ergebnis des Laufs.**

### Water-Filling als Gegenprobe, nicht als Produktionspfad

Liefert Water-Filling auf einer Konfiguration ungefähr dasselbe `s` wie
das Gearbox, ist die Modenwahl robust gegen die Zielfunktion. Weicht es
ab, ist der ADC-Preis der Grund — und das ist eine Aussage wert. Die
Gründe gegen den Produktionspfad stehen in Abschnitt 1.

## Was das für die Rang-1-Zahl bedeutet

Der Zuschnitt „nur K = 0" ist für einen ersten Lauf richtig, lässt aber
die Zahl stehen, die am stärksten betroffen ist. Im Rang-1-Kanal hat
`HᴴH` genau einen Eigenwert ungleich Null. Präkodiertes MUX mit `s = 1`
**ist** dort Beamforming, Spalte für Spalte identisch — also `q = 1`
exakt, nicht `0,029`.

Die `0,029` aus `BF_vs_MUX_Channels.pptx` (Folie 7) misst damit nicht
„Beamforming schlägt Multiplexing", sondern „ein Sender mit CSIT schlägt
einen ohne" — in einem Kanal, in dem das Fehlen von CSIT maximal weh tut.
Das ist ein richtiges Ergebnis mit falscher Überschrift. Es gehört
spätestens dann richtiggestellt, wenn der präkodierte Lauf vorliegt; bis
dahin trägt die Folie die Einschränkung nicht.

## Zuschnitt, überarbeitet

- Produktionspfad: `s` stärkste Moden, gleiche Leistung, `s` gesweept.
- Raster: `N ∈ {1,2,4}`, `M ∈ {4,16,64,256}`, `s ∈ {1..N}` → 24 Kurven.
  Davon sind die 4 mit `s = 1` bitgleich zu vorhandenen BF-Kurven (Test
  V2) und müssen nicht gerechnet werden.
- Kosten: `s = 1` und `s = 2` sind Tier 2 und billig; die Rechenzeit
  steckt praktisch vollständig in `s = 4` bei `M ∈ {64,256}` — das ist
  genau die heutige 4×4-Kurve. **Vor dem Clusterlauf einen Zeitmesspunkt
  nehmen**, nicht aus der `#SBATCH`-Zeile schätzen (die letzte Schätzung
  nach dieser Methode lag um Faktor 30 daneben).
- `N ∈ {8,16}` mit `s ≤ 2` ist der erste Ausbau: `nComb` bleibt klein,
  nur `L^(2N_r)` wächst. Das ist die Zelle, in der heute gar nichts steht.

Kandidatenliste, Zweierpotenzen zuerst (`alphabetB` erlaubt beliebige
`s`, aber ungerade Werte verdoppeln die Kurvenzahl für wenig Auflösung):

| `N` | `s` | Kurven je `M` |
|---|---|---|
| 1 | 1 | 1 |
| 2 | 1, 2 | 2 |
| 4 | 1, 2, 4 | 3 |
| 8 | 1, 2, 4 (8) | 3–4 |
| 16 | 1, 2, 4 (8, 16) | 3–5 |

Die `s = 1`-Spalte ist bitgleich zu den vorhandenen BF-Kurven (Test V2)
und wird nicht gerechnet, sondern wiederverwendet.

## Gearbox-Seite, Ergänzung

Die Ratenobergrenze in `+gearboxphy/+gears/qamGear.m` ist
`N_t·log₂M`. Eine präkodierte Kurve mit `s < N_t` sättigt bei `s·log₂M`
— die Prüfung ist dann zu locker, schlägt also nicht fälschlich an, prüft
aber auch nichts mehr. Mit `s` in der `antennaConfig` wird daraus
`s·log₂M` und die Prüfung trägt wieder.
