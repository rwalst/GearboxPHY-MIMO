# MIMO im Gearbox-PHY — Arbeitsplan

**Ziel.** Das Gearbox wählt heute Gang, Bandbreite, Tastverhältnis und
Modulationsordnung für SISO. Es soll zusätzlich über die **Antennen­architektur**
entscheiden: Multiplexing, digitales Beamforming oder analoges Beamforming —
und zwar so, dass die Wahl für jeden Kanal und jede Wandler­annahme
nachvollziehbar ist.

Stand: 2026-10-12. Dieses Dokument ist der gemeinsame Plan, nicht die
Dokumentation der Ergebnisse — die steht in `HPC_RUNBOOK_MIMO_VERGLEICH.md`,
`HPC_RUNBOOK_ANALOG_BF.md` und `HPC_RUNBOOK_DAC.md`.

---

## 1. Die drei Achsen

| Achse | Werte | Wo sie eingestellt wird |
|---|---|---|
| **Kanal** | LOS (K → ∞), Rice (K = 3, 30), Rayleigh (K = 0) | `riceChannel.m`, `opt.K` der Treiber |
| **Architektur** | MUX (N Ströme), digitales BF (1 Strom, N Ketten), analoges BF (1 Strom, 1 Kette, N Phasenschieber) | `opt.mode`, `beamformingArch` |
| **Auflösung / Hardware** | MUX + digitales BF: ADC-Regel `fixedB` / `scaledB` / `alphabetB`; analoges BF: PS-Modell `active` / `passive_pen` / `passive_comp` | `adcBitsRule.m`, `psType` |

Die drei Achsen sind **nicht** vollständig kreuzbar: `alphabetB` ist nur für
15 der 20 (N, M) rechenbar (B ≤ 20), und für analoges BF ist jede ADC-Regel
außer `fixedB` sinnlos — es gibt nur einen Wandler.

---

## 2. Belegungsmatrix

Legende: **✓** Kurven da und Studie gelaufen · **K** nur Kurven da · **–** fehlt
· **n/a** nicht sinnvoll

### 2.1 MUX (ADC-Regel als dritte Achse)

| Kanal | fixedB | scaledB | alphabetB |
|---|---|---|---|
| Rayleigh K = 0 | ✓ 20/20, 3a + 3b | ✓ 20/20, 3a + 3b | **K** 15/15, nur 3b |
| Rice K = 3 | – | **K** 16/20 (N ≤ 4 im Export), nur 3b | – |
| Rice K = 30 | – | **K** 16/20 (N ≤ 4 im Export), nur 3b | – |
| LOS K → ∞ | – | **K** 20/20, nur 3b | – |

### 2.2 Digitales BF (ADC-Regel als dritte Achse)

| Kanal | fixedB | scaledB | DAC-Quantisierung (+0…+3 bit) |
|---|---|---|---|
| Rayleigh K = 0 | ✓ 36/36, 3a + 3b | ✓ 3a + 3b | **K** `bf_rayleigh_dac{0..3}`, Studie gebaut, nicht gelaufen |
| Rice K = 3 / 30 | – | **K** 24/24 (N ≤ 4), nur 3b | – |
| LOS K → ∞ | ✓ `bfideal` 3a + 3b | ✓ 3a + 3b | **K** `bf_ideal_dac{0..3}[_common]` |

### 2.3 Analoges BF (PS-Modell als dritte Achse)

| Kanal | active (20 mW) | passive_pen | passive_comp |
|---|---|---|---|
| LOS (Fall 1, über `bfideal`) | ✓ gelaufen | ✓ | ✓ |
| Rayleigh (Fall 2, phase-only) | ✓ `abfray_*` gelaufen | ✓ | ✓ |
| Rice K = 3 / 30 / ∞ | **K** `SE_data_abf_fixedB_K*` da, **kein Sweep** | **K** | **K** |

Zusätzlich gelaufen: digitale Referenz mit LO-Verteilung
(`dbf_ideal_lo4mW / lo12p5mW / lo17mW`) und beide ADC-Leistungsmodelle
(`envelope`, `quantile5`).

---

## 3. Lücken, als Arbeitspakete

### AP1 — Rice bei großen Arrays *(MI-Seite, teuer)*
Es fehlen 8 Kurven: N = 8 und 16 bei M = 64 und 256, je K = 3 und 30.
Solange sie fehlen, steht `NS_RICE = [1 2 4]` im Export, und der Rice-Teil der
Studie hat ein anderes N-Raster als K = 0.

Geschätzte Rechenzeit aus den gemessenen `scaledB`-Zwillingen (200 Kerne):
16×16/M=256 22,4 h · 8×8/M=256 11,2 h · 16×16/M=64 1,4 h · 8×8/M=64 < 1 h
→ **rund 36 h je K, zusammen ~72 h.** Passt nicht in ein 24-h-Fenster;
der Checkpoint je SNR-Punkt trägt das, aber es sind mehrere Starts.

### AP2 — 3a für die fehlenden Varianten *(Gearbox-Seite, mittel)*
`results/cmp_<variante>_d<d>/` liegt für 7 Varianten je d = 50/500/5000 m
vollständig vor. Es fehlen: `mux_alphabetB` und alle Rice-Varianten
(`mux_scaledB_K3/K30/KInf`, `bf_scaledB_K3/K30`) — also 5 Varianten × 3 Distanzen.
3b (`results/cmp_distance_*.mat`) liegt dagegen für alle 12 Varianten vor, der
Rate-Sweep ist der Nachzügler. **100 Kerne, 8 h je Lauf.**

### AP3 — Rice für analoges BF *(Gearbox-Seite, billig)*
Die Kurven liegen schon als `SE_data_abf_fixedB_K3/_K30/_KInf`. Es fehlt nur
der Distanz-Sweep mit diesen Datenordnern — eine Variantenzeile in
`run_analog_bf_distance.m`. **Stunden, kein neuer MI-Lauf.**

### AP4 — DAC-Quantisierung am Sender *(gebaut, nicht gelaufen)*
`studies/digital_bf_dac/{export_dbf_dac_curves, run_dbf_dac_distance}.m` sind
fertig, die Kurven liegen (`SE_data_bf_rayleigh_dac{0..3}`,
`SE_data_bf_ideal_dac{0..3}[_common]`), aber von den Zielen
`results/dbfdac_distance_*` und `results/abfdac_distance_*` existiert keines.
**Offene Entscheidung vorab:** die exportierten Kurven am Ideal-DAC deckeln?
Bei Rayleigh liegt die +0-bit-Kurve für M ≥ 64, N ≥ 4 bis zu 0,10 bit
*darüber* (zufälliges Multiplexing durch den Rundungsfehler) — real, aber für
einen Empfänger mit angepasstem Filter nicht nutzbar.

### AP5 — DAC-Leistungsmodell *(nicht gebaut)*
Heute: Cui-Beispielwerte für 0,5 µm (3 V), rund 6× zu teuer; 68 % der
vermessenen DACs liegen darunter. Vorschlag liegt vor
(`P ≥ 1,2 µW·(2^b−1) + 0,25 pJ·b·f_s`, Deck
`Groupmeetings/DAC_Power_Model_Proposal.pptx`). Es fehlt der Szenario-Schalter
analog zu `adcPowerModel`, dann ein Wiederholungslauf.
**Erstabschätzung ohne Sweep:** DAC-Anteil 25 % → 2 %, E_bit −24 %,
E_BF/E_MUX 1,07 → 0,89 bei 500 m, 1 Gbit/s. Das ist groß genug, um die
Rangfolge BF↔MUX zu drehen.

### AP6 — Auswertung und Abbildungen *(Gearbox-Seite)*
`analyze_analog_bf` ist gelaufen, hat aber nur `results/abf_figures/abf_summary.csv`
erzeugt — keine Abbildungen, während `results/cmp_figures/` rund 20 PNGs hat.
Für `results/dbfdac_distance_*` / `abfdac_distance_*` gibt es noch kein
Auswertungsskript. Für die Gesamtaussage fehlt eine Abbildung, die alle drei
Architekturen über Kanal und Distanz zusammenführt.

---

## 4. Reihenfolge

```
AP3 (Rice analog)  ─┐
AP2 (3a fehlend)   ─┼─► AP6 (Auswertung)   ... ohne neue MI-Laeufe moeglich
AP4 (DAC-Quant.)   ─┘

AP1 (Rice N=8,16)  ──► AP2 fuer Rice mit vollem Raster
AP5 (DAC-Modell)   ──► Wiederholung aller Distanz-Sweeps
```

**Billig zuerst:** AP3, AP2 und AP4 brauchen keinen neuen MI-Lauf und schließen
die Matrix bis auf das Rice-N-Raster. AP1 und AP5 sind die teuren und sollten
erst nach einer Entscheidung starten.

---

## 5. Entscheidungen, die ich brauche

| # | Frage | Meine Empfehlung |
|---|---|---|
| E1 | Rice bei N = 8, 16 rechnen (~72 h) oder Rice bei N ≤ 4 belassen und das sagen? | Belassen. Der Rice-Befund (K\* ≈ 16,5 bei 56 m) ist bei N ≤ 4 gemessen und ändert sich mit größeren Arrays qualitativ nicht — BF gewinnt dort nur deutlicher. |
| E2 | Rice auch für `fixedB` und `alphabetB`, oder weiter nur `scaledB`? | Nur `scaledB`. Die Regel kostet nachweislich nichts (Median 0,00 %), ein zweites Rice-Raster bringt keine neue Aussage. |
| E3 | DAC-Leistungsmodell (AP5) bauen und alles wiederholen? | Ja, aber als **Schalter mit altem Default**, und erst die BF/MUX- und Analog/Digital-Studien wiederholen, nicht alles. |
| E4 | DAC-Kurven am Ideal-DAC deckeln (AP4)? | Ja, deckeln und den Effekt im Docstring erklären. Quantisierung darf nicht helfen. |
| E5 | Gehören ZXM / IR / CPM in die MIMO-Matrix? | Nein, vorerst nicht. ZXM-MIMO ist über N_t ≥ 2 blockiert (komplexer Kanal braucht 2·N_t Ströme), und die SISO-Gänge decken den Kleinratenbereich ab. |
| E6 | N > 16? | Nein. `alphabetB` ist dort nicht rechenbar, und die Phasenquantisierung verliert bei großen Arrays ohnehin. |

---

## 6. Grenzen, die in jede Aussage gehören

Keine davon ist ein Fehler; jede schiebt das Ergebnis in eine bekannte Richtung.

- **Frequenzflacher Kanal** — ein Tap, keine Verzögerungsachse. Die Bandbreite
  ist eine freie Variable des Optimierers; am oberen Ratenende liegt sie zwei
  bis drei Größenordnungen über der Kohärenzbandbreite. *(Richtung unbekannt.)*
- **i.i.d. Rayleigh ist vollrangig** — begünstigt MUX; BF verliert 0,6 bis
  6,8 dB gegen N_t·N_r.
- **ADC = Walden-Bestfall** (Median 26× optimistisch), **DAC = 3 V**
  (rund 6× pessimistisch) — beide zusammen begünstigen digitale Architekturen.
- **LO-Verteilung wird im digitalen Zweig nicht berechnet** — begünstigt
  digital; mit 12,5–17 mW je Mixer gewinnt analog ab 180–240 m.
- **MI ist bei N ≥ 4 und M ≥ 64 eine untere Schranke** (7–13 % Schlupf nahe der
  Sättigung) — wirkt gegen MUX.
- **Phasenquantisierung** `G = 1 + (N−1)·sinc²` ist gegenüber echter Rundung
  leicht pessimistisch (≤ 1,1 dB bei 1 bit) — wirkt gegen analog.
