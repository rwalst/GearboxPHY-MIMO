# Plan: Butler-Matrix im Gearbox

Stand 2026-10-08. **Zurueckgestellt** (Entscheidung vom 2026-10-08): die Butler-Matrix wird
vorerst nicht gebaut und bleibt als Ausblick stehen. Nur Plan, nichts davon ist gebaut. Baut
auf `ANALOG_BEAMFORMING.md` auf.

## Was eine Butler-Matrix ist und was sie hier leisten soll

Ein passives N x N-Netzwerk aus 3-dB-Kopplern und festen Phasengliedern. Es bildet N
Antennentore auf N Strahltore ab und rechnet dabei eine raeumliche DFT: jedes Strahltor gehoert
zu einem festen, zu den anderen orthogonalen Strahl. Keine Gleichleistung, keine Steuerung,
N muss eine Zweierpotenz sein.

Zwei Verwendungen, die sich im Aufwand stark unterscheiden:

| | A: fester Strahl, ein Strom | B: K Stroeme ueber K Strahlen |
|---|---|---|
| Ketten je Seite | 1, per Schalter auf ein Strahltor | K <= N, je eine an einem Strahltor |
| ersetzt | die N Phasenschieber des analogen Beamformings | N - K Wandlerketten des digitalen Multiplexings |
| neue MI-Kurven | nein | ja |
| Aenderung am Framework | klein | gross (Stromzahl ungleich Antennenzahl) |

B ist das "analoge Multiplexing", nach dem gefragt wurde: die Trennung der Stroeme geschieht
im passiven Netzwerk, es bleibt aber eine Kette je Strom.

## Die Kanalfrage zuerst

Ob B ueberhaupt etwas bringt, entscheidet allein der Kanal:

- **i.i.d. Rayleigh:** die DFT ist unitaer, der Strahlraumkanal ist wieder i.i.d. Rayleigh.
  Die Energie verteilt sich gleichmaessig auf alle N Strahlen. K Strahlen auszuwaehlen ist dann
  Antennenauswahl ohne Arraygewinn; mit K = N ist es statistisch dasselbe wie digitales
  Multiplexing, nur mit Zusatzdaempfung. Die Butler-Matrix kann hier nicht gewinnen.
- **Reines LOS, Antennenzeile:** Rang 1, ein Strahl traegt alles. Es gibt nur einen Strom;
  das ist Verwendung A.
- **Dazwischen (wenige Pfade, Rice):** die Energie sitzt in wenigen Strahlen. Nur hier lohnt
  B, und nur dafuer ist es bei Millimeterwellen gedacht.

Folge: B braucht ein Kanalmodell mit wenigen Pfaden. `riceChannel` (ein LOS-Pfad plus
i.i.d.-Anteil) reicht dafuer nur bedingt, weil der Streuanteil wieder gleichmaessig im
Strahlraum liegt. Sauberer waere ein geometrischer Kanal mit L Pfaden und Winkeln.

## Phase 0: Zahlen beschaffen (Literatur, kein Code)

- Einfuegedaempfung von Butler-Matrizen ueber N und Traeger, 10 bis 15 gemessene Designs
  (4 x 4 und 8 x 8 bei 28 und 60 GHz, CMOS, SIW und Leiterplatte). Erwartung, UNGEPRUEFT:
  die Daempfung waechst mit der Stufenzahl log2(N), Groessenordnung 1 bis 2 dB je Stufe.
- Daempfung des Strahlwahlschalters (1 aus N).
- Amplituden- und Phasenfehler der Strahlen, falls angegeben.
- Ergebnis: eine Formel L_BM(N, f_c) mit Quelle, analog zum Phasenschieber-Survey.

## Phase 1: Verwendung A, fester Strahl (LOS, keine neuen Kurven)

Modell, je Seite mit N > 1:

- keine Phasenschieber, keine DC-Leistung im Netzwerk;
- Daempfung L_BM(N) + L_Schalter an der Stelle des Phasenschiebers (hinter dem LNA, vor dem
  PA), mit denselben zwei Behandlungen wie beim passiven Phasenschieber (Ausgleich oder Abzug);
- N PAs und N LNAs an den Antennentoren, eine Wandlerkette;
- **Strahlraster statt Phasenquantisierung:** der Strahl laesst sich nicht nachfuehren. Der
  Gewinnverlust gegenueber N, gemittelt ueber die Richtung, ist nachgerechnet 0.87 / 1.06 /
  1.10 / 1.11 dB bei N = 2 / 4 / 8 / 16 je Seite, im unguenstigsten Fall 3.0 bis 3.9 dB.

Umsetzung: ein vierter `psType = "butler"` in `analogBeamformingParams.m` (Daempfung aus
L_BM(N), Rasterverlust statt `psBits`), drei Unit-Tests, eine Variante `abf_butler` in
`run_analog_bf_distance`. Aufwand etwa einen halben Tag nach Phase 0. Laeuft mit den
vorhandenen Kurven.

Erwartetes Ergebnis: guenstiger als aktive Phasenschieber, etwa 1 dB je Seite schlechter im
Linkbudget als ideale Phasen; ob es passive Phasenschieber schlaegt, haengt an L_BM gegen
7.5 dB.

## Phase 2: Verwendung B, K Stroeme

### 2a Framework: Stromzahl von der Antennenzahl trennen

Heute gilt im Multiplexing-Modus Stromzahl = N_t (Kurvenobergrenze N_t * log2 M,
Dateiname `SE_<M>_QAM_<N>x<N>.mat`, Ketten je Antenne). Noetig:

- Antennenkonfiguration bekommt ein Feld `K` (Stroeme = Ketten je Seite);
- Dateiname `SE_<M>_QAM_<N>x<N>_K<K>.mat`, `loadSECurve` und `filterAvailableAntennaConfigs`
  kennen es;
- im QAM-Gang zaehlen DAC, ADC, Mischer und LO-Verteilung mit K, PA und LNA mit N;
- Kurvenobergrenze K * log2 M;
- Voreinstellung K = N_t, damit alles Bisherige bitgleich bleibt (Golden Master).

Das ist der groesste Eingriff und der einzige mit Risiko fuer bestehende Ergebnisse.

### 2b MI-Kurven (QuantizedMimoMI)

- Strahlraumkanal H_b = F_r' * H * F_t mit den DFT-Matrizen;
- Strahlwahl: je Seite K Strahlen (Start: groesste Zeilen- und Spaltennormen; spaeter
  gemeinsame Wahl);
- MI des K x K-Kanals mit B-Bit-ADC je Kette ueber die vorhandene Maschinerie
  (`ergodicMiAuto` auf dem effektiven Kanal). Kosten wie Multiplexing K x K, also fuer K <= 4
  ueberschaubar, HPC;
- ADC-Regel mit K statt N (`scaledB`: + log2 K);
- SNR auf Gesamtleistung, Modus `beamspace` im Export;
- Kanal: Entscheidung noetig (siehe unten).

Kontrollen: K = N im Rayleigh-Kanal muss statistisch die Multiplexing-Kurve ergeben; K = 1
im reinen LOS mit Strahl auf Raster muss die bfideal-Kurve ergeben.

### 2c Studie

Varianten: digitales Multiplexing (N Ketten), Butler K aus N fuer K = 1, 2, 4, analoges
Beamforming. Achsen: Distanz, Rate und die Kanalachse (Rice-K oder Pfadzahl). Auswertung wie
`analyze_bf_vs_mux_qam` mit symmetrischer Maskierung.

Aufwand: 2a zwei bis drei Tage mit Tests, 2b zwei Tage plus HPC-Zeit, 2c ein Tag.

## Entscheidungen, die vor Phase 2 gebraucht werden

1. **Ziel:** nur A (billige Alternative zum Phasenschieber) oder auch B?
2. **Kanal fuer B:** Rice wie bisher (vergleichbar mit der laufenden Studie, aber fuer die
   Butler-Matrix unguenstig) oder geometrischer Mehrpfadkanal (passend, aber ein neues
   Kanalmodell fuer ALLE Varianten, sonst ist der Vergleich nicht fair).
3. **Ort von PA und LNA:** an den Antennentoren (N Stueck, Daempfung der Matrix schadet weder
   Sendeleistung noch Rauschzahl stark, aber jeder PA sieht die Summe aller Stroeme) oder an
   den Strahltoren (K Stueck, billiger, aber die Daempfung geht voll in Sendeleistung und
   Rauschzahl).
4. **Strahlwahl:** ideal und ohne Kosten, oder mit Schaltverlust und endlicher Kanalkenntnis?

## Risiken

- Das Ergebnis von B ist fast vollstaendig eine Aussage ueber das Kanalmodell.
- Im Rayleigh-Kanal ist die Butler-Matrix beweisbar ohne Nutzen; ein Vergleich nur dort waere
  irrefuehrend.
- Ohne Phase 0 ist L_BM geraten. Die Daempfung waechst mit N und kann den Arraygewinn bei
  grossen N aufzehren.
- 2a aendert, wie das Framework Antennen und Stroeme zaehlt; ohne den Golden Master als
  Sicherung nicht anfangen (er ist reihenfolgeabhaengig, siehe `studies/analog_bf/TODO.md`).

## Vorschlag zur Reihenfolge

Phase 0, dann Phase 1. Danach entscheiden, ob B den Aufwand lohnt -- mit dem Ergebnis von
Phase 1 und der Kanalentscheidung in der Hand.
