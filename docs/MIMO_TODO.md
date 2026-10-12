# MIMO im Gearbox-PHY — Arbeitsplan

**Ziel.** Das Gearbox wählt heute Gang, Bandbreite, Tastverhältnis und
Modulationsordnung für SISO. Es soll zusätzlich über die **Antennen­architektur**
entscheiden: Multiplexing, digitales Beamforming oder analoges Beamforming —
und zwar so, dass die Wahl für jeden Kanal und jede Wandler­annahme
nachvollziehbar ist.

Stand: 2026-10-12, Entscheidungen E1/E3/E4/E5 getroffen (siehe Abschnitt 5).
Dieses Dokument ist der gemeinsame Plan, nicht die
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
| Rice K = 3 | – | **K** 16/20, 4 Ecken laufen (AP1), nur 3b | – |
| Rice K = 30 | – | **K** 16/20, 4 Ecken laufen (AP1), nur 3b | – |
| LOS K → ∞ | – | **K** 20/20, nur 3b | – |

### 2.2 Digitales BF (ADC-Regel als dritte Achse)

| Kanal | fixedB | scaledB | DAC-Quantisierung (+0…+3 bit) |
|---|---|---|---|
| Rayleigh K = 0 | ✓ 36/36, 3a + 3b | ✓ 3a + 3b | **K** MI-Kurven da, **Export fehlt** (AP4) |
| Rice K = 3 / 30 | – | **K** 24/24 (N ≤ 4), 8 Ecken laufen (AP1), nur 3b | – |
| LOS K → ∞ | ✓ `bfideal` 3a + 3b | ✓ 3a + 3b | **K** MI-Kurven da, **Export fehlt** (AP4) |

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

### AP1 — Rice bei großen Arrays *(entschieden: wird gerechnet)*
Rice lief bei N = 8 und 16 nur auf M <= 16. **Beide Treiber stehen seit
QuantizedMimoMI 2cd285a auf dem vollen 20er-Gitter**, der Export holt sein
N-Raster seit cf8d06e aus dem Datenordner statt aus `NS_RICE = [1 2 4]`.

Der Umfang war größer als zuerst genannt — digitales BF hatte bei Rice
dieselbe Grenze:

| Seite | neue Kurven | Kosten je K | zusammen |
|---|---|---|---|
| MUX `scaledB` | 4 (N = 8, 16 × M = 64, 256) | 35,6 h | **71,2 h** |
| digitales BF `scaledB` | 8 (N = 8, 16 × alle M) | ~0,4 h | **< 1 h** |

Die MUX-Zahlen sind keine Hochrechnung: Rice kostet exakt so viel wie
Rayleigh (N=4/M=256 braucht 5,60 h bei K = 0, 3 **und** 30), also sind die
K=0-Zwillinge die Rechnung — 8x8/M=64 0,70 h, 8x8/M=256 11,17 h,
16x16/M=64 1,40 h, 16x16/M=256 22,35 h.

**Job-Zuschnitt:** je K zwei Jobs in Folge, denn 35,6 h passen nicht in ein
24-h-Fenster. Die größte einzelne Kurve (16x16/M=256, 22,4 h) passt noch,
kein Einzelpunkt sprengt also den Job. Fertige Kurven werden anhand der
Datei übersprungen, eine angefangene setzt am nächsten SNR-Punkt fort.

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

### AP4 — DAC-Quantisierung am Sender *(entschieden: wird gelaufen)*
Hier stand „Studie gebaut, nicht gelaufen" — die Lücke sitzt eine Stufe
früher: **es gibt keinen einzigen `SE_data_*_dac*`-Ordner**, der Export
vor dem Sweep ist also auch noch nicht gelaufen. Die MI-Kurven selbst
liegen vollständig (je 20 Dateien in `bf_rayleigh_dac0..3`,
`bf_ideal_dac0..3[_common]`, `bf_los_digital_dac0..3`,
`bf_los_digital_ideal`).

**Beide Schritte sind am 2026-10-12 gelaufen** (Protokoll
`../nachtraegliches_protokoll.txt`): der Export schrieb 19 Ordner, der
Distanz-Sweep alle drei DAC-Modelle × zwei LO-Fälle × drei Kanäle plus die
analogen Varianten. Dabei sind zwei Dinge aufgefallen:

**(a) Sechs Ordner fehlen wirklich — die `_common`-Stufen +1..+3.** Erwartet
waren 25 Ordner, geschrieben 19. Es fehlen
`SE_data_bf_fixedB_dac{1,2,3}_common` und
`SE_data_bflosd_fixedB_dac{1,2,3}_common`, weil die MI-Quellen
`bf_rayleigh_dac{1,2,3}_common` und `bf_los_digital_dac{1,2,3}_common` nicht
existieren — **120 MI-Kurven**. Nur `bf_ideal` hat alle vier `_common`-Stufen.
Folge: der Vergleich „gemeinsame Aussteuerung" ist über die DAC-Stufen nur
für `bfideal` (LOS, ein ADC hinter dem Kombinierer) lesbar; bei Rayleigh und
bei LOS-mit-ADC-je-Antenne gibt es ihn nur bei +0 bit. Das Protokoll zeigt
das direkt: `+0_common` 18 mal, `+1/+2/+3_common` je 6 mal (nur die
`los`-Läufe).

**(b) `isfile` setzt auf dem UNC-Share aus — und wirft dabei still
Kandidaten aus der Optimierung.** Fünf Warnungen `gearboxphy:mimoCurveMissing`
betreffen Kurven, die im SELBEN Protokoll vom Export geschrieben wurden.
Jeder betroffene Ordner wird in 6 Läufen benutzt und meldet in genau 1 --
fehlte die Datei, käme die Meldung sechsmal. `filterAvailableAntennaConfigs`
läuft nach der Warnung bewusst weiter, also hatten diese Läufe eine kleinere
Kandidatenmenge als ihre Geschwister und sind nicht gegeneinander lesbar.
Betroffen sind `dbfdac_distance_losd_lo12p5mW_analytic_1V`,
`..._losd_lo12p5mW_survey`, `..._los_loShared_analytic_1V`,
`..._ray_loShared_survey` und ein `abfdac_distance_abfray_*_analytic`.
Offen, wie das abgestellt wird (Wiederholversuch, Vorabprüfung im Client
statt je Worker, oder harter Fehler) -- siehe E7.

Die beiden Schritte waren:
1. `export_dbf_dac_curves` — erzeugt die `SE_data_*_dac<k>`-Ordner.
2. `run_dbf_dac_distance` — 25 Worker, Zeitbedarf nicht gemessen,
   `SKIP_EXISTING` trägt einen Neustart.

**E4 ist entschieden (ja, deckeln) und umgesetzt:**
`+gearboxphy/+data/capDacCurvesAgainstIdeal.m` begrenzt jede DAC-Kurve
punktweise auf die Kurve mit idealem DAC derselben (M, N); der Export ruft
das nach jedem Ordner auf. Gemessen an bflosd/dac2: 247 von 1056 Punkten
lagen darüber, bis 0,0209 bit — alle gedeckelt, keiner angehoben. Jede
Datei trägt danach `dacCapRef`, `dacCapPoints`, `dacCapMaxBit` und
`dacCapUncovered`. Abgedeckt von `tests/+unit/DacCapTest.m` (7 Tests).

### AP5 — DAC-Leistungsmodell *(entschieden: ja — und schon gebaut)*
Auch hier war der Plan überholt: der Schalter **existiert**, ist verdrahtet
und getestet.
- `+physics/dacConstants.m`: `analytic` (3 V, Default, bitgleich zu allen
  bestehenden Ergebnissen), `analytic_1V` (Diss. Kap. 5/6),
  `survey` (1,2 µW je LSB + 0,25 pJ je bit·sample, 5-%-Quantil der
  96-DAC-Übersicht).
- `makeScenarioConfig`: `dacPowerModel`, Vorgabe `analytic` — Default also
  unverändert, wie in E3 verlangt.
- `resolveScenarioForCarrier` setzt die Konstanten, `tests/+unit/DacModelTest.m`
  deckt den Schalter ab, `studies/common/bf_arch_scenario.m` nimmt `dacModel`
  als 7. Argument.
- `run_dbf_dac_distance` läuft bereits über alle drei Modelle
  (`P.DAC_MODELS`).

Zu tun bleibt damit **nur der Lauf**, und er fällt mit AP4 zusammen: derselbe
Treiber liefert beide Achsen. Was noch fehlt, ist die Modellachse in
`run_analog_bf_distance` (dort nur `ADC_MODELS`, DAC bleibt `analytic`) —
nötig nur, falls die Analog/Digital-Aussage mit `survey` wiederholt werden
soll; `run_dbf_dac_distance` rechnet die analogen Varianten als
`abfdac_distance_*` aber ohnehin mit.

**Erstabschätzung ohne Sweep:** DAC-Anteil 25 % → 2 %, E_bit −24 %,
E_BF/E_MUX 1,07 → 0,89 bei 500 m und 1 Gbit/s. Das dreht die Rangfolge
BF↔MUX, taugt also nicht als Fußnote.

### AP6 — Auswertung und Abbildungen *(Gearbox-Seite)*
`analyze_analog_bf` ist gelaufen, hat aber nur `results/abf_figures/abf_summary.csv`
erzeugt — keine Abbildungen, während `results/cmp_figures/` rund 20 PNGs hat.
Für `results/dbfdac_distance_*` / `abfdac_distance_*` gibt es noch kein
Auswertungsskript. Für die Gesamtaussage fehlt eine Abbildung, die alle drei
Architekturen über Kanal und Distanz zusammenführt.

---

## 4. Was jetzt in welcher Reihenfolge läuft

**Ohne neuen MI-Lauf** (Gearbox-Seite, Stunden):

1. `export_dbf_dac_curves` → die fehlenden `SE_data_*_dac*`-Ordner (AP4.1).
2. `run_dbf_dac_distance` → DAC-Quantisierung × drei Leistungsmodelle
   (AP4.2 + AP5), 25 Worker.
3. `run_analog_bf_distance` um die Rice-Datenordner erweitern (AP3) — die
   Kurven liegen als `SE_data_abf_fixedB_K3/_K30/_KInf` längst da.
4. `run_mimo_comparison_rate` für `mux_alphabetB` und die fünf
   Rice-Varianten (AP2), 100 Kerne, 8 h je Lauf.

**MI-Läufe** (QuantizedMimoMI, HPC):

5. `runQamSweepRiceBf` — 16 neue Kurven, unter 1 h. Zuerst, weil billig und
   weil es das gemeinsame Gitter sofort absichert.
6. `runQamSweepRiceMux` — 8 neue Kurven, 71,2 h, je K zwei Jobs in Folge.

**Danach**: Export erneut (holt das N-Raster jetzt selbst), dann AP2 für die
Rice-Varianten auf dem vollen Raster, dann AP6.

## 5. Entscheidungen

| # | Frage | Stand |
|---|---|---|
| E1 | Rice bei N = 8, 16 rechnen? | **JA** (2026-10-12). Gegen meine Empfehlung, die auf die 71 h abhob; der Gewinn ist, dass die Hüllkurve über (M,N) bei N >= 8 wieder vollständig ist und Rice auf demselben N-Raster läuft wie K = 0. Die Aussage „das Gearbox wählt M >= 64 bei N >= 8 nie" wird damit für Rice belegt statt unterstellt. Treiber umgestellt, Export zieht nach. |
| E3 | DAC-Leistungsmodell neu? | **JA** (2026-10-12), als Schalter mit altem Default — und genau so schon gebaut. Zu tun bleibt der Lauf, siehe AP5. |
| E5 | ZXM / IR / CPM in die MIMO-Matrix? | **NEIN** (2026-10-12). ZXM-MIMO ist bei N_t >= 2 blockiert (der komplexe Kanal braucht den Gruppenpfad über 2·N_t Ströme); die SISO-Gänge decken den Kleinratenbereich ab. |
| E2 | Rice auch für `fixedB` und `alphabetB`? | offen. Empfehlung: nein, nur `scaledB` — die Regel kostet nachweislich nichts (Median 0,00 %), ein zweites Rice-Raster bringt keine neue Aussage. |
| E4 | DAC-Kurven am Ideal-DAC deckeln? | **JA** (2026-10-12), umgesetzt und getestet — siehe AP4. Quantisierung darf nicht helfen, sonst bevorzugt `minOverDacLevels` genau die Stufe, die am meisten rundet. |
| E7 | Wie wird der `isfile`-Aussetzer auf dem UNC-Share abgestellt? | offen, und er verfälscht Ergebnisse still. Empfehlung: die Kandidatenprüfung EINMAL im Client machen und das Ergebnis in den parfor broadcasten, statt sie je Worker und je Distanz zu wiederholen -- das ist auch 25× weniger Dateizugriffe. Zusätzlich die fünf betroffenen Läufe neu rechnen. |
| E6 | N > 16? | offen. Empfehlung: nein — `alphabetB` ist dort nicht rechenbar, und die Phasenquantisierung verliert bei großen Arrays ohnehin. |

## 6. Inventur der Kurvendateien (2026-10-12, nach dem Pull)

Gegen das erwartete Gitter geprüft, Bitzahl je Regel aus `adcBitsRule`.
**Vollständig:** `bHalf` 20/20 · `rule_mux` scaledB K=0 und K=Inf je 20/20,
alphabetB 15/15 · `bf_rayleigh` K=0 (fixedB+scaledB) 40/40 · `bf_ideal`
40/40 · `bf_analog` **80/80** über alle vier K · `bf_los_digital_ideal`
20/20 · alle 19 vorhandenen DAC-Ordner je 20/20.

**Es fehlen genau 144 Kurven in drei Blöcken:**

| Block | Ordner | fehlend | Kosten | Treiber |
|---|---|---|---|---|
| A | `rule_mux` (MUX, scaledB) | 8: N = 8, 16 × M = 64, 256 × K = 3, 30 | 35,6 h je K | `runQamSweepRiceMux` |
| B | `bf_rayleigh` (dig. BF, scaledB) | 16: N = 8, 16 × alle M × K = 3, 30 | < 1 h je K | `runQamSweepRiceBf` |
| C | `bf_rayleigh_dac{1,2,3}_common`, `bf_los_digital_dac{1,2,3}_common` | 120: 6 Ordner × 20 | **0,96 h zusammen** | s. u. |

A und B sind AP1 (Entscheidung E1), die Treiber stehen schon auf dem vollen
Gitter.

**Block C ist eine Zeile je Treiber.** `runQamSweepBfIdealDac` hat
`DAC_OFFSETS_COMMON = [0 1 2 3]`, die beiden anderen haben dort `0`:
`runQamSweepBfRayleighDac.m:49` und `runQamSweepBfLosDigitalDac.m:73`. Auf
`[0 1 2 3]` gesetzt, rechnet der Lauf nur die sechs fehlenden Ordner --
fertige Kurven werden anhand der Datei übersprungen. Kosten aus den
vorhandenen `dac0_common`-Zwillingen gemessen: 0,24 h je Rayleigh-Ordner,
0,08 h je LOS-digital-Ordner.

**Eine Namensabweichung, die keine Lücke ist:** `bf_analog` schreibt K = 0
als `_K0`, überall sonst heißt K = 0 „kein Suffix". Eine Prüfung nach der
üblichen Konvention meldet dort 20 Fehlstellen, die nicht existieren.

### 6.1 Welche MI-Kurven fehlen

Alle fehlenden Kurven liegen in **QuantizedMimoMI** (`qam/results/`) — im
Gearbox-Repo fehlt nichts, was an der Quelle vorhanden wäre. Umgekehrt
gilt das nicht: siehe 6.2.

**Block A + B — der Rice-Kanal bei großen Arrays** (24 Kurven). Beide
Modi haben bei Rice nur Arrays bis 4×4; es fehlt die obere Hälfte der
Array-Achse. Die ADC-Auflösung ist dabei keine freie Größe, sondern folgt
der Regel `scaledB` (½·log₂M + log₂N + 3) — sie steht hier nur, weil sie
den Rechenaufwand bestimmt.

| Block | Modus | Kanal | Array | Modulation | ADC | Kurven |
|---|---|---|---|---|---|---|
| A | Multiplexing | Rice K = 3 (4,8 dB) | 8×8 | 64- und 256-QAM | 9 / 10 bit | 2 |
| A | Multiplexing | Rice K = 3 | 16×16 | 64- und 256-QAM | 10 / 11 bit | 2 |
| A | Multiplexing | Rice K = 30 (14,8 dB) | 8×8 | 64- und 256-QAM | 9 / 10 bit | 2 |
| A | Multiplexing | Rice K = 30 | 16×16 | 64- und 256-QAM | 10 / 11 bit | 2 |
| B | digitales Beamforming | Rice K = 3 | 8×8 | alle vier Ordnungen | 7…10 bit | 4 |
| B | digitales Beamforming | Rice K = 3 | 16×16 | alle vier Ordnungen | 8…11 bit | 4 |
| B | digitales Beamforming | Rice K = 30 | 8×8 | alle vier Ordnungen | 7…10 bit | 4 |
| B | digitales Beamforming | Rice K = 30 | 16×16 | alle vier Ordnungen | 8…11 bit | 4 |

Die MUX-Seite braucht nur die beiden hohen Modulationsordnungen, weil
4- und 16-QAM dort schon gerechnet sind (siehe 6.2); die BF-Seite hat bei
8×8 und 16×16 noch gar nichts. Treiber: `runQamSweepRiceMux` (35,6 h je K)
und `runQamSweepRiceBf` (unter 1 h je K), beide auf dem vollen Gitter.

**Block C — der Vergleichsfall „gemeinsame Aussteuerung" bei gröberem DAC**
(120 Kurven). Eine Aussteuerung für alle Antennen statt einer je Antenne;
die Aussteuerung je Antenne setzt eine stufenlose Verstärkung hinter jedem
DAC voraus, die niemand bezahlt, und dieser Fall zeigt, was sie wert ist.
Gerechnet ist er nur beim feinsten DAC (+0 bit) — und nur für LOS mit
einem ADC hinter dem Kombinierer gibt es ihn über alle Stufen.

| Modus | Kanal / Empfänger | fehlende DAC-Stufen | Kurven | Kosten |
|---|---|---|---|---|
| digitales Beamforming | Rayleigh | +1, +2, +3 bit | 60 | 0,72 h |
| digitales Beamforming | LOS, ein ADC je Antenne | +1, +2, +3 bit | 60 | 0,24 h |

Jede der sechs fehlenden Kombinationen deckt das volle Gitter ab: alle
fünf Arraygrößen (SISO bis 16×16) × alle vier Modulationsordnungen, ADC
nach `fixedB` (4 bis 7 bit), Kanal durchweg K = 0. Die Stufenangabe ist
relativ zur idealen DAC-Auflösung ½·log₂M.

Kosten gemessen an den vorhandenen Zwillingen bei +0 bit, die dieselbe
Arbeit sind: **0,96 h für alle 120.** Auslöser ist eine Zeile je Treiber —
`runQamSweepBfRayleighDac.m:49` und `runQamSweepBfLosDigitalDac.m:73`
tragen `DAC_OFFSETS_COMMON = 0`, wo `runQamSweepBfIdealDac` `[0 1 2 3]` hat.

### 6.2 Gerechnet, aber nicht exportiert (8 Kurven)

Multiplexing im Rice-Kanal, K = 3 und 30, bei **8×8 und 16×16 mit 4- und
16-QAM**: diese Kurven liegen an der Quelle und sind im Gearbox-Repo nicht
als `SE_data`-Kurve vorhanden.

Das ist Absicht: `localAvailableNs` nimmt eine Arraygröße nur mit allen
vier Modulationsordnungen, und bei 8×8 und 16×16 hat Rice bisher nur die
beiden niedrigen. Eine halbe Zeile verzerrt die Hüllkurve über
(Modulation, Array) genauso wie eine fehlende. **Sie werden automatisch
mitexportiert, sobald Block A gerechnet ist** — Block A hebt also 16
Kurven in die Studie, nicht 8.

### 6.3 Kurz, aber vollständig

Drei `SE_data`-Ordner haben weniger als 16 MIMO-Kurven, ohne eine Lücke zu
sein:

| Ordner | Kurven | warum vollständig |
|---|---|---|
| `SE_data_bf_scaledB_K3`, `_K30` | 8 | deckungsgleich mit der Quelle; digitales BF hat bei Rice gar kein N = 8/16 (das ist Block B) |
| `SE_data_mux_alphabetB` | 11 | die fünf Fehlenden sind nicht rechenbar: `alphabetB` verlangt B = 27 (8×8/M=64) bis 67 (16×16/M=256), über 20 bricht `adcBitsRule` ab |

## 7. Grenzen, die in jede Aussage gehören

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
