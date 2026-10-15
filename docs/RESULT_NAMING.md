# Doppelte Rechnungen, und die Namenskonvention dagegen

Stand 2026-10-14. Alle Zahlen hier sind **gemessen**, nicht geschätzt; die
Messbefehle stehen jeweils dabei.

## 1. Die Frage

Mehrere Läufe benutzen dieselben MI-Kurven. Wo rechnen sie deshalb dasselbe
zweimal? Und wie müssen Ergebnisdateien heißen, damit ein Lauf eine fertige
Rechnung *findet*, statt sie zu wiederholen?

## 2. Was doppelt gerechnet wird

### 2.1 Die SISO-Gänge in 3a — 105 von 486 Rechnungen, 21,6 % der Laufzeit

Der Export kopiert **24 Kurven inhaltsgleich in alle 36 `SE_data*`-Ordner**
(Gasts SISO-Kurven: ZXM, Pulse, NA-QAM, QAM M = 1024) — 864 Dateikopien von
24 Originalen. Deshalb hängen sieben der elf Ergebnisschlüssel je 3a-Ordner
überhaupt nicht an der Variante:

| Schlüssel | Varianten | verschiedene Rechnungen |
|---|---|---|
| `zxm_M1`, `zxm_M2`, `zxm_M3` | 6 | **1** |
| `pulseenergy_M1`, `pulsearbitrary_M1` | 6 | **1** |
| `naqam_M1024`, `qam_M1024` | 6 | **1** |
| `qam_M4`, `qam_M16`, `qam_M64`, `qam_M256` | 6 | 6 — das ist der Vergleich |

Nachgerechnet an den **vorhandenen Ergebnissen** (`results/cmp_*_d50/`):
E_bit stimmt über alle sechs Varianten auf 2e-9 überein, γ und B auf 7e-7 —
Optimierer-Rauschen, nicht andere Physik. `qam_M4` weicht dagegen um 72 % ab.

Gewichtet mit den Antennenkonfigurationen (die Kosten eines Schlüssels sind
Konfigurationen × Ratenpunkte): **486 Konfigurations-Sweeps verlangt, 381
verschieden — 105 gespart, 21,6 % der Rechenzeit von 3a.**

### 2.2 Die analogen Varianten, in zwei Studien gerechnet — 6 Dateien

`run_dbf_dac_distance` rechnet die analogen Varianten mit, weil das
DAC-Modell auch sie trifft. Seine Vorgaben sind aber die
Framework-Vorgaben (`adcPowerModel = "envelope"`,
`dacPowerModel = "analytic"`), und sein Raster ist Zeile für Zeile das von
`run_analog_bf_distance`. Also:

```
abfdac_distance_<variante>_analytic.mat  ==  abf_distance_<variante>_envelope.mat
```

Gemessen an den sechs Paaren, die beide vorliegen: max. relative Abweichung
in E zwischen 1,9e-11 und 5,3e-3 bei identischem Raster — die Streuung des
ungeseedeten Multistart-Optimierers (der Golden Master zeigt 4,2e-3).

**Erledigt am 2026-10-14 durch die Vereinigung des Variablensatzes.** Vorher
waren die Dateien nicht austauschbar: `abf_distance` speicherte
`Eadc, Eps, adcModel`, `abfdac_distance` dagegen
`Edac, dacLevels, dacLevelsCommon, dacModel, channel` — gleiche Rechnung,
verschiedene Aufzeichnung. Jetzt schreiben beide

```
E, Etx, Erx, Epa, Eadc, Edac, Eps, SE, SNRrx_dB,
CFG, variant, v, adcModel, dacModel, hw, resultFingerprint
```

und tragen die Form `"abf_analog/v2"`. Beide Zahlen standen ohnehin im
Budget-Struct `pb`, die Vereinigung kostet also nichts an Rechenzeit.
**Nachgewiesen:** alle sechs Varianten bilden über beide Wege denselben
Schlüssel (`tests/+unit/ResultStoreTest.m`,
`analogeVariantenBeiderStudienTeilenDenSchluessel`) — und das, obwohl die
Analog-Studie `bf_arch_scenario` mit sechs Argumenten aufruft (Vorgaben für
DAC- und LNA-Modell) und die DAC-Studie mit acht.

Zwei Felder sind dabei **entfallen**, und zwar begründet:

- `channel` war irreführend. Die Kanäle `losd` und `los` haben dieselben
  `anaData`, `anaMode` und `anaPrefix` (`run_dbf_dac_distance.m:105-112`),
  erzeugen also dieselbe Datei — das Feld hätte je nach Reihenfolge `"losd"`
  oder `"los"` enthalten. Dass dabei nichts doppelt gerechnet wird, leistet
  jetzt der Fingerabdruck (er enthält den Kanalnamen nicht), nicht mehr der
  Zufall der Schleifenreihenfolge.
- `dacLevels`/`dacLevelsCommon` sind für einen analogen Sender mit **einem**
  DAC ohnehin leer.

**Dabei gefunden:** `SKIP_EXISTING` war für die analogen Varianten
wirkungslos. `localDone` verlangt die Felder `dacLevelsPer` und
`dacScaleStandard`, die eine analoge Datei nie trug — sie wurden also bei
*jedem* Lauf neu gerechnet. An ihrer Stelle steht jetzt
`gearboxphy.data.fingerprintMatches`, und das ist die schärfere Prüfung:
sie deckt Raster, Modelle und Kurveninhalt ab, wo ein CFG-Vergleich nur das
Raster sieht.

### 2.3 Die N = 1-Spalte — 153 von 486 Rechnungen, alles Doppelte sitzt dort

Bei N = 1 fällt `scaledB` = ½log₂M + log₂**1** + 3 mit `fixedB` zusammen.
Gemessen, indem der Fingerabdruck je **Antennenkonfiguration** statt je
Kombination gebildet wird (3a, 6 Varianten × 3 Distanzen):

| N | verlangt | verschieden | doppelt |
|---|---|---|---|
| **1** | 198 | **45** | **153** |
| 2 | 72 | 72 | 0 |
| 4 | 72 | 72 | 0 |
| 8 | 72 | 72 | 0 |
| 16 | 72 | 72 | 0 |
| Summe | 486 | 333 | 153 |

**Bei N ≥ 2 gibt es kein einziges Duplikat** — dort unterscheiden sich die
Array-Kurven je Variante, und das ist der Vergleich, den die Studie messen
will. Alles Doppelte sitzt bei N = 1.

Die 45 verschiedenen verteilen sich auf 15 je Distanz: sieben SISO-Gänge
plus **zwei** je Modulationsordnung — alle vier MUX/BF-Varianten teilen den
Rayleigh-SISO-Punkt, die beiden `bfideal`-Varianten den AWGN-SISO-Punkt. Von
sechs Varianten rechnen also vier dasselbe.

An den Ergebnissen gegengeprüft (3b): die N = 1-Spalte von
`cmp_distance_mux_fixedB` und `cmp_distance_mux_scaledB` stimmt auf 2,9e-11
überein, bei `bfideal_fixedB`/`_scaledB` auf 3,8e-4.

### 2.4 `run_dbf_dac_los_newhw` — schon gelöst, und zwar durch den Namen

Der Treiber ruft `run_dbf_dac_distance` mit `DAC_MODELS = ["analytic","hw_new"]`
auf; der `analytic`-Teil ist derselbe wie im Hauptlauf. Dass dabei nichts
doppelt gerechnet wird, liegt allein daran, dass **beide Läufe denselben
Dateinamen bilden** und `SKIP_EXISTING` greift. Genau dieses Prinzip
verallgemeinert die Konvention.

## 3. Die Namenskonvention

**Der Name einer Ergebnisdatei im Speicher ist der Fingerabdruck ihrer
Rechnung.** Zwei Läufe, die dasselbe rechnen würden, bilden denselben Namen
und finden damit die fertige Datei.

```
results/_store/<fingerabdruck>.mat          ein Eintrag je Rechnung, 16 Hex
results/<studienordner>/<sprechender Name>  unverändert, was die Auswertung liest
```

Die sprechenden Namen bleiben **wie sie sind** (`cmp_mux_fixedB_d50/qam_M4_fc28GHz.mat`,
`abf_distance_abf_active_envelope.mat`). Sie sind die Adresse für die
Auswertungen; 18 Stellen lesen sie. Der Fingerabdruck ist eine zweite,
parallele Adressierung — kein Ersatz.

### Woraus der Fingerabdruck gebildet wird

| Einheit | Schlüssel aus | gebaut in |
|---|---|---|
| eine `runSweep`-Kombination (Gang × Ordnung × Träger) | `ctx` jeder Antennenkonfiguration, `RVec`, Optimierer-Parameter, `x0`, Schranken | `+data/comboFingerprint.m` |
| eine Distanzstudien-Datei | `ctx` **jeder Zelle** des (Distanz, M, N)-Gitters, dazu Raster und Form | `+data/gridFingerprint.m` |

**Warum `ctx` und nicht eine Liste von Parametern:** die Gänge sind so
gebaut, dass `computeCore(x, ctx, R)` und `computeBudget(ctx, x, R)` *nichts
außer* `ctx` und `R` sehen. Die getrimmte SE-Kurve, M, N_t, N_r, die ADC- und
DAC-Auflösung, das Linkbudget (und damit die Distanz), der Träger, die
Analog-BF-Parameter, die LO-Leistungen, B_max und der ganze Hardware-Satz
stecken schon darin. Ein Fingerabdruck über `ctx` kann also keine
Abhängigkeit übersehen, während eine handgeschriebene Liste beim ersten
neuen Feld eines Gangs veraltet.

**Warum nicht die Datei hashen:** `SE_4_QAM.mat` hat in **allen 36**
`SE_data*`-Ordnern einen anderen Byte-Inhalt, während `SE_vec`, `SNR_vec`,
`sourceB`, `snrShiftDb`, `snrReference` und `sourceMode` bitgleich sind —
verschieden sind nur `generatedOn` (Zeitstempel), `source` (Herkunftspfad)
und `srcSnrStep`. Ein Datei-Hash würde **kein einziges** echtes Duplikat
finden. Gehasht wird deshalb die Nutzlast, die `loadSECurve` nach außen gibt.

**Warum die Form im Schlüssel steht:** siehe 2.2. Gleiche Rechnung heißt
nicht austauschbare Datei. Der Form-Anteil (`"abf_distance/v1"`,
`"dbfdac_distance_digital/v1"`, …) nennt den Variablensatz. **Ändert eine
Studie, was sie speichert, muss ihr Form-Anteil hochgezählt werden** — sonst
wird eine alte Datei für einen Schlüssel geliefert, der jetzt etwas anderes
bedeutet. Ein neuer Anteil verwaist alte Einträge, und das kostet
Rechenzeit, nie Richtigkeit.

### Betrieb

- Der Speicher liegt unter der Ergebniswurzel, wandert also mit
  `GEARBOXPHY_RESULTS_ROOT` in den ZIH-Workspace (`HPC_RUNBOOK_ZIH.md`).
- Er ist **nicht versioniert** (`.gitignore`): jeder Eintrag ist die Kopie
  einer versionierten Ergebnisdatei und würde die 73 MB verdoppeln.
- Nach einem frischen Clone ist er leer. `gearboxphy.data.rebuildStore()`
  baut ihn aus den vorhandenen Dateien wieder auf — jede trägt ihren
  Schlüssel im Feld `resultFingerprint`. **Die vorhandenen Ergebnisdateien
  haben das Feld noch nicht** — `rebuildStore(dryRun=true)` zählt 1102
  davon; sie tragen erst bei, wenn sie einmal neu gerechnet wurden (was die
  Kette in `MIMO_TODO.md` 3.2 ohnehin tut).
- Checkpoints bleiben **lauf-lokal**: Index-Schlüssel, nur zur
  Wiederaufnahme, bewusst nicht geteilt. Geteilt wird eine Ebene höher,
  zwischen fertigen Ergebnisdateien.

## 4. Was damit erledigt ist und was nicht

| Duplikat | Status |
|---|---|
| 2.1 SISO-Gänge in 3a (105 Rechnungen, 21,6 %) | **erledigt** — nachgewiesen: zweiter Lauf 0,1 s statt 7,1 s, Zahlen bitgleich |
| 2.4 `run_dbf_dac_los_newhw` | erledigt, jetzt zusätzlich unabhängig vom Dateinamen |
| Wiederholung eines Laufs nach Umbenennung oder in einen anderen Ordner | **erledigt** — der Schlüssel hängt nicht am Namen |
| 2.2 analoge Varianten in zwei Studien (6 Dateien, 6000 Optimierungen) | **erledigt** — vereinigter Variablensatz, Form `"abf_analog/v2"`, Schlüsselgleichheit per Test abgesichert |
| `SKIP_EXISTING` für die analogen Varianten der DAC-Studie | **erledigt** — war wirkungslos (`localDone` verlangte Felder, die diese Dateien nie trugen), jetzt Prüfung über den Schlüssel |
| Kanäle `losd`/`los` erzeugen dieselbe analoge Datei | **erledigt** — der Fingerabdruck enthält den Kanalnamen nicht, der zweite Durchlauf übernimmt statt zu rechnen |
| 2.3 N = 1-Spalte | **offen, bewusst zurückgestellt**: 105 der 153 Duplikate sind durch den Kombinations-Speicher schon weg (die SISO-Gänge haben nur eine Konfiguration). Die restlichen **48 = 12,6 %** der verbleibenden 381 sitzen in den QAM-Schlüsseln, wo N = 1 neben N = 2…16 in derselben Einheit steht. Siehe Abschnitt 4.1 |

### 4.1 Warum Fall 3 zurückgestellt ist, und wie er aussähe

**Nicht** als Punkt-Cache — das wäre die Checkpoint-Ebene, und die bleibt
lauf-lokal. Es ginge eine Stufe feiner als heute: die Einheit wäre
(Gang, Ordnung, Träger, **eine** Konfiguration) statt aller Konfigurationen
zusammen, also etwa 333 Speichereinträge für 3a statt 381 — keine
Dateiflut, damit auch nicht das Muster, das auf dem UNC-Share schon die
`isfile`-Aussetzer gebracht hat (E7 in `MIMO_TODO.md`).

Die Parallelisierungsachse müsste dafür **nicht** umgedreht werden:
`optimizeOnePointBestConfig` wählt den Gewinner als ersten strikten argmin
über `E_per_bit_all` (NaN übersprungen, Gleichstand an den kleineren Index).
Fertige Spalten vor dem `parfor` holen, nur die fehlenden rechnen und den
Gewinner danach aus den `_all`-Arrays per argmin ableiten gibt also exakt
dieselbe Auswahl.

Drei Gründe, es trotzdem erst **nach** der Laufkette zu machen:

1. Es braucht eine zweite Speicher-API (eine Spalte ist kein Dateiduplikat),
   eine Umstellung des `parfor`-Körpers und Punkt-Checkpoints in voller
   Breite — sonst passen Spaltenzahl und Checkpoint nach einem Abbruch nicht
   mehr zusammen. Das ist die Funktion, von der alle fünf Studien hängen.
2. Die Absicherung fehlt gerade. Jede Wiederverwendung verschiebt Zahlen um
   die Streuung des ungeseedeten Optimierers (0,42 %); bei einer Änderung
   *innerhalb* des Optimierungspfads müsste man „korrekter Umbau" von
   „subtiler Fehler" auf diesem Niveau unterscheiden, und genau dafür ist der
   Golden Master derzeit untauglich (E11, Mechanismus unaufgeklärt).
3. 48 von 381 sind grob 18 der 144 Stunden von 3a. Bekommt 3a die
   Variantenteilmenge (`MIMO_TODO.md` 3.2, Zeile 6), laufen die sechs
   Varianten gleichzeitig — die doppelte Arbeit kostet dann Kernstunden,
   aber keine Kalenderzeit.

## 5. Wo es im Code steht

| Datei | Aufgabe |
|---|---|
| `+gearboxphy/+data/fingerprint.m` | kanonischer SHA-256 über Zahlen/Text/Strukturen; Funktionshandles sind ein **Fehler**, nicht stillschweigend übersprungen |
| `+gearboxphy/+data/comboFingerprint.m` | Schlüssel einer `runSweep`-Kombination |
| `+gearboxphy/+data/gridFingerprint.m` | Schlüssel einer Distanzstudien-Datei |
| `+gearboxphy/+data/storeDir.m` | wo der Speicher liegt |
| `+gearboxphy/+data/fetchFromStore.m` | übernehmen statt rechnen; leerer Schlüssel = kein Speicher |
| `+gearboxphy/+data/publishToStore.m` | anbieten; scheitert nie den Lauf |
| `+gearboxphy/+data/rebuildStore.m` | Speicher aus vorhandenen Ergebnissen wiederherstellen |
| `+gearboxphy/+data/fingerprintMatches.m` | "ist schon gerechnet" über den Schlüssel statt über CFG und Zeitstempel |
| `tests/+unit/ResultStoreTest.m` | 10 Tests, darunter die zwei gemessenen Befunde aus 2.1 und 3 |
