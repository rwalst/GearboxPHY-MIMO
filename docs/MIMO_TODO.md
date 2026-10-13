# MIMO im Gearbox-PHY — Arbeitsplan

**Ziel.** Das Gearbox wählt heute Gang, Bandbreite, Tastverhältnis und
Modulationsordnung für SISO. Es soll zusätzlich über die **Antennen­architektur**
entscheiden: Multiplexing, digitales Beamforming oder analoges Beamforming —
und zwar so, dass die Wahl für jeden Kanal und jede Wandler­annahme
nachvollziehbar ist.

Stand: 2026-10-13 (Inventur nach `QuantizedMimoMI e1a72e2`), Entscheidungen E1/E3/E4/E5/E8/E9/E10 getroffen (Abschnitt 5).

**Code-Abgleich mit dem HPC: die ID wird erzeugt, nicht hier abgelesen.**
`codeManifest('snapshot')` am Arbeitsplatz, dann auf dem HPC
`codeManifest('diff', <id>)`. Eine fest eingetragene ID stand hier zweimal
(`a438306f0032`, `15762a1cd1cf`) und war beide Male nach dem nächsten
Commit falsch — das Manifest hasht auch `.md`, dieses Dokument gehört also
zu seinem eigenen Hash und entwertet jede ID, die man hineinschreibt.
Dieses Dokument ist der gemeinsame Plan, nicht die
Dokumentation der Ergebnisse — die steht in `HPC_RUNBOOK_MIMO_VERGLEICH.md`,
`HPC_RUNBOOK_ANALOG_BF.md` und `HPC_RUNBOOK_DAC.md`.

---

## 1. Die drei Achsen

| Achse | Werte | Wo sie eingestellt wird |
|---|---|---|
| **Kanal** | LOS (K → ∞), Rice (K = 3, 30), Rayleigh (K = 0) | `riceChannel.m`, `opt.K` der Treiber |
| **Architektur** | MUX (N Ströme), digitales BF (1 Strom, N Ketten), analoges BF (1 Strom, 1 Kette, N Phasenschieber) | `opt.mode`, `beamformingArch` |
| **Auflösung / Hardware** | MUX: ADC-Regel `fixedB` / `scaledB` / `alphabetB`; digitales BF: `fixedB` (ein Strom, siehe E8); analoges BF: PS-Modell `active` / `passive_pen` / `passive_comp` | `adcBitsRule.m`, `psType` |

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
| Rayleigh K = 0 | ✓ 36/36, 3a + 3b | ✓ 3a + 3b | ✓ MI-Kurven 24/24 Ordner, **Export fehlt** (AP4) |
| Rice K = 3 / 30 | **K** nur N = 1; N ≥ 2 laufen (AP1/B) | überholt (E8) | – |
| LOS K → ∞ | ✓ `bfideal` 3a + 3b | ✓ 3a + 3b | ✓ MI-Kurven 24/24 Ordner, **Export fehlt** (AP4) |

Die `scaledB`-Spalte ist für digitales BF seit E8 **keine Alternative mehr,
sondern eine Messung**: bei K = 0 liegen beide Regeln vor, und ihre
Differenz ist der Preis der Regel (bis 2,65 % im Verhältnis BF/MUX). Für
neue Läufe trägt die BF-Seite `fixedB` — ein Strom, Alphabet M unabhängig
von N.

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

Der Umfang war zweimal größer als zuerst genannt: digitales BF hatte bei
Rice dieselbe Array-Grenze, und **E8 hat die BF-Seite zusätzlich auf
`fixedB` umgestellt** (`c3fdb58`) — dort gibt es `fixedB` bisher nur bei
N = 1, wo alle Regeln zusammenfallen, also wird sie für jedes N ≥ 2 neu
gerechnet.

| Seite | Regel | neue Kurven je K | Kosten je K | zusammen |
|---|---|---|---|---|
| MUX | `scaledB` | 4 (N = 8, 16 × M = 64, 256) | 35,6 h | **71,2 h** |
| digitales BF | `fixedB` | 16 (N = 2…16 × alle M) | < 1 h | **< 2 h** |

Die MUX-Zahlen sind keine Hochrechnung: Rice kostet exakt so viel wie
Rayleigh (N=4/M=256 braucht 5,60 h bei K = 0, 3 **und** 30), also sind die
K=0-Zwillinge die Rechnung — 8x8/M=64 0,70 h, 8x8/M=256 11,17 h,
16x16/M=64 1,40 h, 16x16/M=256 22,35 h.

**Job-Zuschnitt:** die MUX-Seite läuft seit `8cac31b` als **zwei
gleichzeitige Jobs**, einer je Rice-Faktor (`runQamSweepRiceMuxK3`,
`...K30`, je 200 Kerne in eigener Allokation) — 35,6 h Wandzeit statt
71,2 h. Erlaubt die Partition keine 40 h, reichen zwei Fenster je Job: die
größte einzelne Kurve (16x16/M=256, 22,4 h) passt noch, kein Einzelpunkt
sprengt also den Job. Fertige Kurven werden anhand der Datei übersprungen,
eine angefangene setzt am nächsten SNR-Punkt fort — auch Checkpoints des
alten, ungeteilten Treibers gelten weiter, weil die Signatur je Kurve
unverändert ist.

### AP2 — 3a für die fehlenden Varianten *(Gearbox-Seite, mittel)*
`results/cmp_<variante>_d<d>/` liegt für 7 Varianten je d = 50/500/5000 m
vollständig vor. Es fehlen: `mux_alphabetB` und alle Rice-Varianten
(`mux_scaledB_K3/K30/KInf`, `bf_fixedB_K3/K30`) — also 5 Varianten × 3
Distanzen. **100 Kerne, 8 h je Lauf.**

3b (`results/cmp_distance_*.mat`) liegt für 12 Varianten vor, aber zwei
davon sind seit E8 überholt: `bf_scaledB_K3` und `_K30`. An ihre Stelle
treten `bf_fixedB_K3/_K30`, die es noch nicht gibt — sie entstehen erst
mit Block B und dem folgenden Export. Lesbar sind also 10 der 12.

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
analogen Varianten. **Beide müssen wiederholt werden** — der Export, weil
er jetzt deckelt (E4) und die `_common`-Stufen dazukommen; der Sweep, weil
`E` seit E9 den anderen Fall trägt. Dabei sind zwei Dinge aufgefallen:

**(a) MI-SEITE ERLEDIGT am 2026-10-12, EXPORT OFFEN.** Es fehlten sechs
Ordner — die `_common`-Stufen +1..+3; sie sind gerechnet (`592f149`), alle
24 DAC-Ordner sind vollständig. **Übersetzt sind sie noch nicht:** unter
`data/` liegen 6 `_common`-Ordner (`bfideal` +0…+3, `bf_fixedB` +0,
`bflosd` +0), es fehlen `SE_data_bf_fixedB_dac{1,2,3}_common` und
`SE_data_bflosd_fixedB_dac{1,2,3}_common`. Der nächste Exportlauf schreibt
also **25 Ordner statt 19** — das ist die Prüfgröße dafür, dass er
vollständig durchgelaufen ist.
Ursprünglicher Befund: erwartet waren 25 Ordner, geschrieben 19. Es fehlten
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

### AP7 — Arbeitspunkt je Punkt *(erledigt 2026-10-13)*
Gespeichert war nur, **was** ein Arbeitspunkt kostet (E_bit und seine
Aufteilung), nicht **wo** er betrieben wird: Spektraleffizienz und der von
der Kurve geforderte SNR lebten nur als lokale Variablen in `computeCore`.

Jetzt tragen alle vier Gänge `SE`, `SNR_rx_dB`, `SNR_tx_dB`, `P_t_W`,
`B_Hz` und `gamma` heraus — durch `optimizeOnePoint`, die Checkpoints und
`saveAllResults` (`0ac0e18`) — und alle fünf Distanz-Studien legen `SE` und
`SNRrx_dB` in der Form ihrer Energiefelder ab (`8e1e2d3`).

**Nicht im Leistungsbudget:** dessen Felder summieren sich zu E_bit. Vier
Auswertungen, zwei Unit-Tests und eine `assert`-Prüfung in
`run_beamforming_distance_sweep` (`setdiff(fieldnames(pb), [TXF RXF])` muss
leer sein) verlassen sich darauf.

**Ein Fehler von mir dabei, gefunden und behoben vom Nutzer (`6c76e68`):**
in `saveAllResults` standen die zwei neuen Argumente im `arguments`-Block,
aber nicht in der Funktionszeile — damit brach JEDER `runSweep`-Lauf beim
Speichern der ersten Kombination ab. Die Unit-Suite und der Golden Master
fahren `runSweep` nicht und waren trotzdem grün; was es gefunden hätte,
sind `tests/smoke_test.m` und `tests/mimo_smoke_test.m`. **Diese zwei
gehören nach jeder Änderung an der Sweep- oder Speicherebene dazu.**

**Vorhandene Ergebnisdateien tragen die Felder nicht** — sie entstehen erst
in neuen Läufen. Die 18 `dbfdac_distance_*` werden wegen E9 ohnehin neu
gerechnet, die übrigen Studien behalten ihre alten Dateien bis zur
Wiederholung.

### AP6 — Auswertung und Abbildungen *(Gearbox-Seite)*
`analyze_analog_bf` ist gelaufen, hat aber nur `results/abf_figures/abf_summary.csv`
erzeugt — keine Abbildungen, während `results/cmp_figures/` rund 20 PNGs hat.
Für `results/dbfdac_distance_*` / `abfdac_distance_*` gibt es noch kein
Auswertungsskript. Für die Gesamtaussage fehlt eine Abbildung, die alle drei
Architekturen über Kanal und Distanz zusammenführt.

---

## 4. Was jetzt in welcher Reihenfolge läuft

**Block B und D sind gerechnet** (`82c9ad8`, `e1a72e2`), Block C schon am
2026-10-12. Es fehlen **noch 2 Kurven**:

| Block | Ordner | fehlend | Kosten | Treiber |
|---|---|---|---|---|
| A | `rule_mux` (MUX, `scaledB`) | **2**: 16×16/256-QAM bei K = 3 und 30 | 22,4 h je Kurve, parallel | `runQamSweepRiceMuxK3`, `...K30` |

Vollständig sind damit: MUX `fixedB`/`scaledB` (K = 0, ∞)/`alphabetB`,
digitales BF `fixedB`+`scaledB` bei K = 0, **digitales BF `fixedB` bei
Rice (40/40, Block B)**, ideales BF, analoges BF über alle vier K, und
**alle 24 DAC-Ordner inklusive Rice (Block C und D)**.

**Diese zwei Kurven blockieren das N-Raster, nicht die Kette.** Der Export
nimmt eine Arraygröße nur mit allen vier Modulationsordnungen
(`localAvailableNs`); ohne 16×16/256-QAM läuft der Rice-MUX-Teil also auf
N ∈ {1, 2, 4, 8} statt bis 16. Wer nicht warten will, kann die
Gearbox-Seite jetzt starten und das kleinere Raster in Kauf nehmen — dann
aber nach Ankunft der zwei Kurven Export und 3b wiederholen
(`localUpToDate` erzwingt das von selbst).

A und B sind AP1 (Entscheidung E1); Block B ist durch E8 von 16 auf 32
Kurven gewachsen, weil die BF-Seite unter der neuen Regel bei allen N ≥ 2
neu gerechnet wird. Alle Treiber sind umgestellt, committet und gepusht.

Für Block A und B stehen die Treiber auf dem vollen Gitter. **Block A ist
auf zwei gleichzeitige Jobs aufgeteilt**, je ein Rice-Faktor:

```
git pull                                  # bis 592f149

# Block B zuerst, billig und sichert das gemeinsame Gitter
salloc --nodes=1 --cpus-per-task=200 --mem=64G --time=02:00:00
matlab -batch "addpath('<...>/QuantizedMimoMI'); setupPath; runQamSweepRiceBf"

# Block A: ZWEI GETRENNTE Allokationen, gleichzeitig, je 200 Kerne
salloc --nodes=1 --cpus-per-task=200 --mem=64G --time=40:00:00
matlab -batch "addpath('<...>/QuantizedMimoMI'); setupPath; runQamSweepRiceMuxK3"
# und parallel dazu, in einer eigenen Allokation:
matlab -batch "addpath('<...>/QuantizedMimoMI'); setupPath; runQamSweepRiceMuxK30"
```

Je Job 35,6 h, zusammen also 35,6 h Wandzeit statt 71,2 h. Die beiden
Treiber sind je zwei Zeilen und delegieren an `runQamSweepRiceMux(K)` --
die Konfiguration bleibt an einer Stelle, weil zwei Vollkopien genau dort
auseinanderliefen, wo die Studie auf Gleichheit beruht.

**Getrennte Allokationen, nicht zwei Aufrufe in derselben:** jeder Job
will 200 Kerne für sich, und `startPool` leitet `JobStorageLocation` aus
`SLURM_JOB_ID` ab. Seit 2026-10-12 hängt zusätzlich die Prozess-ID im
Pfad, der Fall ist also abgefangen statt nur dokumentiert. Kollisionsfrei
sind die beiden ohnehin: gleiche Zielordner, aber Dateinamen mit
K-Suffix, und der Checkpoint liegt unter dem Kurvennamen.

Erlaubt die Partition keine 40 h, reichen zwei Fenster je Job — fertige
Kurven werden anhand der Datei übersprungen, eine angefangene setzt am
nächsten SNR-Punkt fort, und die größte einzelne Kurve (16×16/256-QAM,
22,4 h) passt noch in ein 24-h-Fenster.

**Nichts muss vorher gelöscht werden.** Jede Übersprunglogik im Ablauf ist
entweder dateinamenbasiert (und damit kollisionsfrei, weil `fixedB` andere
B-Werte liefert als `scaledB` und neue (N,M) neue Namen ergeben) oder sie
prüft Signatur und Alter: 3b verlangt passendes `CFG` **und**
Quellkurven, die älter sind als das Ergebnis (`localCfgMatches` +
`localUpToDate`), `run_dbf_dac_distance` verlangt `dacScaleStandard`, 3a
überspringt gar nichts, und der Export schreibt immer. Wer es erzwingen
will: `SKIP_EXISTING = false` in `run_mimo_comparison_distance.m:86`.

**Zwei verwaiste Artefakte** entstehen durch E8 und werden von keinem
Skript mehr gelesen: `data/SE_data_bf_scaledB_K3`/`_K30` und
`results/cmp_distance_bf_scaledB_K3`/`_K30.mat`. Sie bleiben liegen, weil
sie die Datenbasis der 2,65-%-Aussage sind; löschen wäre reine
Aufräumarbeit (die Git-Historie trägt sie ohnehin).

**Block C war eine Zeile je Treiber** und ist am 2026-10-12 gerechnet.
`runQamSweepBfRayleighDac` und `runQamSweepBfLosDigitalDac` trugen
`DAC_OFFSETS_COMMON = 0`, wo `runQamSweepBfIdealDac` `[0 1 2 3]` hat; auf
`[0 1 2 3]` gesetzt, rechnete der Lauf genau die sechs fehlenden Ordner,
weil fertige Kurven anhand der Datei übersprungen werden. Vorab aus den
`dac0_common`-Zwillingen geschätzt: 0,24 h je Rayleigh-Ordner, 0,08 h je
LOS-digital-Ordner.

**Eine Namensabweichung, die keine Lücke ist:** `bf_analog` schreibt K = 0
als `_K0`, überall sonst heißt K = 0 „kein Suffix". Eine Prüfung nach der
üblichen Konvention meldet dort 20 Fehlstellen, die nicht existieren.

### 6.1 Welche MI-Kurven fehlen

Alle fehlenden Kurven liegen in **QuantizedMimoMI** (`qam/results/`) — im
Gearbox-Repo fehlt nichts, was an der Quelle vorhanden wäre. Umgekehrt
gilt das nicht: siehe 6.2.

**Block A + B — der Rice-Kanal** (40 Kurven). Die ADC-Auflösung ist keine
freie Größe, sondern folgt der Regel — und die ist seit E8 **je Modus eine
andere**: MUX `scaledB` (½·log₂M + log₂N + 3), digitales BF `fixedB`
(½·log₂M + 3). Block A füllt die obere Hälfte der Array-Achse; Block B
rechnet die BF-Seite unter der neuen Regel komplett neu, weil es dort
`fixedB` bisher nur bei N = 1 gibt (wo alle Regeln zusammenfallen).

| Block | Modus | Kanal | Array | Modulation | ADC | Kurven |
|---|---|---|---|---|---|---|
| A | Multiplexing | Rice K = 3 (4,8 dB) | 8×8 | 64- und 256-QAM | 9 / 10 bit | 2 |
| A | Multiplexing | Rice K = 3 | 16×16 | 64- und 256-QAM | 10 / 11 bit | 2 |
| A | Multiplexing | Rice K = 30 (14,8 dB) | 8×8 | 64- und 256-QAM | 9 / 10 bit | 2 |
| A | Multiplexing | Rice K = 30 | 16×16 | 64- und 256-QAM | 10 / 11 bit | 2 |
| B | digitales Beamforming | Rice K = 3 | 2×2 … 16×16 | alle vier Ordnungen | 4…7 bit (`fixedB`) | 16 |
| B | digitales Beamforming | Rice K = 30 | 2×2 … 16×16 | alle vier Ordnungen | 4…7 bit (`fixedB`) | 16 |

Die MUX-Seite braucht nur die beiden hohen Modulationsordnungen, weil
4- und 16-QAM dort schon gerechnet sind (siehe 6.2). Treiber:
`runQamSweepRiceMux` (35,6 h je K) und `runQamSweepRiceBf` (unter 1 h je K,
`fixedB` braucht weniger ADC-Bits als die alte Rechnung), beide auf dem
vollen Gitter.

**Block C — erledigt am 2026-10-12.** Der Abschnitt bleibt stehen, weil er
das Modell erklärt, aber die Kurven liegen vor.
Eine Aussteuerung für alle Antennen statt einer je Antenne;
die Aussteuerung je Antenne setzt eine stufenlose Verstärkung hinter jedem
DAC voraus, die niemand bezahlt, und dieser Fall zeigt, was sie wert ist.
Gerechnet ist er nur beim feinsten DAC (+0 bit) — und nur für LOS mit
einem ADC hinter dem Kombinierer gibt es ihn über alle Stufen.

| Modus | Kanal / Empfänger | DAC-Stufen | Kurven | Stand |
|---|---|---|---|---|
| digitales Beamforming | Rayleigh | +1, +2, +3 bit | 60 | ✓ 2026-10-12 |
| digitales Beamforming | LOS, ein ADC je Antenne | +1, +2, +3 bit | 60 | ✓ 2026-10-12 |

**Seit E9 war das keine Ergänzung, sondern der Standardfall selbst** — die
gemeinsame Aussteuerung lag bei diesen beiden Kanälen nur bei +0 bit vor.
Jetzt trägt der Standard dasselbe vierstufige Raster wie der Vergleich,
und `run_dbf_dac_distance:commonIncomplete` darf nicht mehr auftreten.
Kommt die Warnung trotzdem, ist der Export nicht gelaufen.

Jede der sechs fehlenden Kombinationen deckt das volle Gitter ab: alle
fünf Arraygrößen (SISO bis 16×16) × alle vier Modulationsordnungen, ADC
nach `fixedB` (4 bis 7 bit), Kanal durchweg K = 0. Die Stufenangabe ist
relativ zur idealen DAC-Auflösung ½·log₂M.

Kosten gemessen an den vorhandenen Zwillingen bei +0 bit, die dieselbe
Arbeit sind: **0,96 h für alle 120.** Auslöser ist eine Zeile je Treiber —
`runQamSweepBfRayleighDac` und `runQamSweepBfLosDigitalDac` trugen
`DAC_OFFSETS_COMMON = 0`, wo `runQamSweepBfIdealDac` `[0 1 2 3]` hat. (Hier
standen Zeilennummern, 49 und 73; meine eigenen Docstring-Ergänzungen haben
sie auf 65 und 89 verschoben. Deshalb steht jetzt der Variablenname da.)

**Block D — DAC-Quantisierung über den Rice-Faktor** (320 Kurven,
Entscheidung E10). Die DAC-Achse war nur bei K = 0 und in den beiden
LOS-Grenzfällen gerechnet; der Schnittpunkt K\* ist damit für einen
**idealen** Sender-DAC bestimmt. Diese Kurven sagen, ob die endliche
Auflösung ihn verschiebt — und sie treffen BF stärker als MUX, weil nur
der digitale Präkodierer das Symbol dreht.

| Kanal | DAC-Stufen | Aussteuerung | Kurven | Kosten |
|---|---|---|---|---|
| Rice K = 3 | +0…+3 bit | gemeinsam + je Antenne | 160 | 2,3 h |
| Rice K = 30 | +0…+3 bit | gemeinsam + je Antenne | 160 | 2,3 h |

Gemessen, nicht geschätzt: die acht vorhandenen K=0-Ordner brauchten
zusammen 2,29 h (0,22 h je `perAntenna`-Ordner, 0,24…0,42 h je
`common`-Ordner, steigend mit der Stufe), und Rice kostet dasselbe wie
Rayleigh.

**Keine neuen Ordner.** Die Kurven landen in den bestehenden
`bf_rayleigh_dac<k>[_common]` und tragen `_K3`/`_K30` im Dateinamen — die
Konvention der Rice-Erweiterung („K im Dateinamen, bei K = 0 ohne
Suffix"), damit alle K einer Stufe beieinanderliegen und der Export K = 0
ohne Sonderfall findet. Der Export schreibt daraus
`SE_data_bf_fixedB_K<K>_dac<k>[_common]`, die Studie kennt die Kanäle
`ray3` und `ray30`.

**Reihenfolge innerhalb von D:** Block B muss vorher laufen. Die
Deckelung (E4) braucht als Referenz die Ideal-DAC-Kurve desselben K, also
`SE_data_bf_fixedB_K3`/`_K30` — und die entstehen erst aus Block B und dem
Vergleichsexport. Fehlt die Referenz, warnt der Export mit
`export:noDacCapRef` statt ungedeckelt zu schreiben.

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
| `SE_data_bf_scaledB_K3`, `_K30` | 8 | **überholt durch E8** — digitales BF trägt bei Rice jetzt `fixedB`. Die Ordner bleiben als Beleg der alten Rechnung liegen, werden aber nicht mehr erzeugt noch gelesen; dasselbe gilt für `results/cmp_distance_bf_scaledB_K3/_K30.mat` |
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
