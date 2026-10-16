# MIMO im Gearbox-PHY — Stand und offene Läufe

**Ziel.** Das Gearbox soll nicht nur Gang, Bandbreite, Tastverhältnis und
Modulationsordnung wählen, sondern auch die **Antennenarchitektur**:
Multiplexing, digitales Beamforming oder analoges Beamforming — über drei
Kanäle (LOS, Rice, Rayleigh) und die zugehörigen Wandler- und
Phasenschiebermodelle.

> # ⚠ Die wichtigste offene Frage: „LOS" heißt hier **Rang 1**, nicht Sichtverbindung
>
> **Jede Aussage dieser Studie über LOS und über den Rice-Faktor steht unter
> einer Annahme, die noch niemand geprüft hat.** `riceChannel.m` baut den
> LOS-Anteil als `H_LOS = a_r(θ_r) · a_t(θ_t)'` — ein äußeres Produkt zweier
> Steuervektoren und damit **Rang 1 bei jedem Winkel**, nicht nur bei
> Broadside. Der Rice-Faktor fährt den Kanal also nicht von „gestreut" nach
> „Sichtverbindung", sondern von **vollrangig nach rangarm**.
>
> **Ein reiner Sichtverbindungskanal ist physikalisch nicht rangarm.** Bei
> passendem Antennenabstand (LOS-MIMO, `d_t·d_r ≈ λ·R/N`) stehen die Spalten
> von H_LOS orthogonal, und Multiplexing funktioniert **ungeschmälert**. Bei
> 28 GHz und 10 m Abstand braucht N = 32 dafür 5,8 cm Elementabstand, also
> 1,85 m Apertur — groß, aber für eine Basisstation nicht absurd. **Das
> Modell kann diesen Fall gar nicht darstellen:** ein äußeres Produkt hat
> Rang 1, unabhängig vom Elementabstand.
>
> **Was daran hängt:** F2 (der ganze K-Verlauf und K\*), die Rang-1-Spalten
> von F1 und F3 — und damit die Hauptfrage selbst. „Beamforming gewinnt bei
> hohem K" ist derzeit die Aussage **„Beamforming gewinnt, wenn der Kanal
> rangarm ist"**. Die ist richtig und der Schwellwert K\* ist eine echte
> Zahl, aber sie trägt **nicht** die Empfehlung „bei Sichtverbindung
> Beamforming bauen" — und genau so würde sie gelesen.
>
> **Zu tun:** Abschnitt 3.5. **Zahlen und Herleitung:** Abschnitt 5.1.

## Die Forschungsfragen

Damit beim Lesen der Zahlen klar bleibt, **was eigentlich gegen was** steht.
Alles wird in **E_bit [J/bit]** gemessen, je Zelle als Minimum über (M, N) —
jede Architektur darf ihre beste Konfiguration wählen, denn genau das tut das
Gearbox.

**Die Hauptfrage, und alles andere ordnet sich ihr unter:**

> **Wann lohnt sich welche Antennenarchitektur — und wovon hängt die Antwort
> ab?** Multiplexing (N Ströme) gegen Beamforming (ein Strom, N Ketten) gegen
> analoges Beamforming (ein Strom, eine Kette, N Phasenschieber).

Daraus die einzelnen Vergleiche:

| # | Was gegen was | Das Maß | Daten |
|---|---|---|---|
| **F1** | **BF gegen MUX** über Distanz und Kanal | q = E_bit(BF)/E_bit(MUX); daraus **d\*** | ✅ vollständig |
| **F2** | **BF gegen MUX** über den **Rice-Faktor** | **K\***, der Schnittpunkt über K | ✅ vollständig |
| **F3** | **analoges gegen digitales BF**, letzteres **mit DAC-Auflösung** | q über die Distanz, je Kanal und Phasenschiebertyp | ⚠ **teilweise** — Rayleigh und Rice stehen, dem **Rang-1-Kanal fehlt die analoge Seite** (9 Dateien, davor 15 Waisen verschieben) |
| **F4** | **idealer gegen endlicher DAC** am digitalen Sender | q = E_bit(endlich)/E_bit(ideal), 4 Stufen | ✅ vollständig |
| **F5** | **ADC-Regel**: `scaledB` gegen `fixedB` | Differenz in Prozent | ✅ vollständig (MUX, nach E8) |
| **F6** | **SISO gegen MIMO** | Umschlagpunkt je N | ✅ vollständig |
| **F7** | **Gang- und Antennenwahl** | gewählter Gang und N | ✅ vollständig — Ratenachse aber nur für K = 0 |
| **F8** | **Hardwaremodelle alt gegen neu**, Bandbreite isoliert | Verhältnis zu `old`; `bw_only`/`bw_old` | ✅ vollständig |

**Sieben von acht sind beantwortet.** F3 ist die einzige unvollständige Frage,
und ihr fehlt genau ein Kanal.

**Zwei Fragen sind zurückgestellt — ❌ ohne Antwort**, beide weil sie auf
`bfideal` aufbauen und der Vergleich seit dem 2026-10-16 über digital-mit-DAC
gegen analog läuft:

| Frage | warum keine Antwort | was fehlt |
|---|---|---|
| *Lohnt es, nur EINE Seite analog zu bauen?* | geparkt: alle LOS-Varianten lesen die idealisierte Kurve, die Rayleigh-Mischkurven gibt es nicht | `SE_data_abftx_fixedB`, `SE_data_abfrx_fixedB` |
| *Ab welcher Distanz gewinnt analoges BF gegen ein idealisiertes digitales?* | geparkt: Fall 1 liest die idealisierte Kurve auch für die digitale Seite, das begünstigt digital zweifach | digitale Varianten auf `bflosd_fixedB` |

Die gerechneten Ergebnisse beider Läufe bleiben liegen — sie sind aus dem
aktiven Pfad, nicht gelöscht.

**Und zwei Fragen stehen unter allen anderen.** Die erste ist die
Rang-1-Annahme oben (Abschnitt 3.5, 5.1) — ❌ **noch ohne Daten**: *ist
„LOS" in dieser Studie überhaupt Sichtverbindung, oder nur Rangarmut?*
Die zweite (E13, Abschnitt 4) — ❌ **ebenfalls ohne Daten**: **wogegen wird „Ersparnis“ gemessen?** Gasts Diss vergleicht gegen ein fest
verdrahtetes Front End auf die Spitzenrate. Unter MIMO muss dessen
Antennenzahl mitwachsen, sonst steckt im Saving der Arraygewinn statt des
Schaltgewinns. Die Festlegung: NA-QAM mit festem N_peak.

Stand: 2026-10-16 (`QuantizedMimoMI 1c04e10`, `GearboxPHY-MIMO 6db3b94`).
Diese Datei ist die Übersicht. Begründungen, Messwerte und Herleitungen
stehen in den Commits und den Dokumenten aus Abschnitt 6.

> ### ⚠ Zwei Modellsätze — jede Zahl sagt, zu welchem sie gehört
>
> Am 2026-10-15 wurden die Hardwaremodelle umgestellt, am 2026-10-16 ist die
> Neurechnung durch. **Beide Sätze liegen jetzt auf demselben Raster vor**,
> und das ist Absicht — für die ganze MIMO-Matrix das, was
> `run_hw_comparison` für SISO tut.
>
> | | alt | neu (Standard seit 2026-10-15) |
> |---|---|---|
> | LNA | `fom_bandwidth` | `fom_floor` |
> | ADC | `envelope` (0,67 fJ) | `quantile5` (3,17 fJ) |
> | DAC | `analytic` (3 V) | `survey` |
> | LO-Verteilung | `shared` | `per_mixer` |
> | B_max | 0,1·f_c (240 / 800 / 2800 MHz) | ein Kanal (20 / 100 / 400 MHz) |
>
> **Verglichen werden darf nur innerhalb eines Satzes.** Wer eine alte Zahl
> neben eine neue stellt, vergleicht zwei Dinge gleichzeitig. Die Tabellen in
> Abschnitt 1 führen deshalb beide Spalten.
>
> Die alten Ergebnisse liegen in `results/_oldhw/` (101 Ordner und Dateien,
> verschoben mit `archive_oldhw_results.m`). **Eine Ausnahme von „gilt als
> Vergleichsarm“:** die MIMO-Spalten von `main{,100,200}` bei M = 4/16/64 sind
> nicht nur alter Satz, sie sind **falsch** — sie entstanden mit den je Strom
> normierten Kurven aus `data/SE_data` ohne `snrReference`, die Multiplexing
> +3,0 / +6,0 / +9,0 dB schenken. Als SISO-Spalte bleiben sie brauchbar;
> `run_sweep` rechnet seit dem 2026-10-16 nur noch SISO.
>
> Die Umstellung steckt in `hardwareModelPreset`. PR #2 (`81bd77f`) machte den
> neuen Satz zur Vorgabe, PR #4 (`a83809c`) nahm den `oldModelArgs()`-Pin aus
> allen rechnenden Studien. Seitdem überspringt `runSweep` eine fertige Datei
> nur bei passendem `resultFingerprint`, Checkpoints ebenso
> (`+data/claimCheckpoints.m`) — ein Treiber übernimmt also keine alten
> Ergebnisse mehr als „fertig“.
>
> Die MI-Kurven in `data/SE_data*` sind **nicht** betroffen — sie sind
> informationstheoretisch und kennen keine Hardware.
>
> **Eine Ausnahme von „gültig als Vergleichsarm":** die MIMO-Spalten von
> `results/main{,100,200}` bei M = 4/16/64 sind nicht nur alter Modellsatz,
> sie sind **falsch**. Sie entstanden mit den neun MIMO-Kurven aus
> `data/SE_data`, die je Strom normiert sind und kein `snrReference` tragen —
> ohne die 10·log₁₀(N_t)-Verschiebung bekam Multiplexing +3,0 / +6,0 / +9,0 dB
> geschenkt. Als SISO-Spalte bleiben die Dateien brauchbar. `run_sweep`
> rechnet seit dem 2026-10-16 nur noch SISO; die MIMO-Achse liegt allein bei
> 3a, 3b und der Analog-Studie.

---

## 1. Die Auswertungen — was am Ende dasteht

Diese Auswertungen sind der Zweck, die Läufe sind das Mittel. Die Zuordnung
ist **nicht** eins zu eins: 3a speist sechs Auswertungen, 3b vier. Seit dem
2026-10-15 hat jeder Lauf einen Abnehmer; offen ist die andere Richtung —
zwei Auswertungen warten noch auf ihre Eingangsdaten. Abschnitt 3.4 stellt
beide Richtungen gegenüber.

**Gemeinsames Maß.** Alle Auswertungen rechnen in **E_bit [J/bit]** und
bilden je Zelle das **Minimum über (M, N)** — die Hüllkurve, denn genau das
tut das Gearbox: jede Architektur darf ihre beste Konfiguration wählen. Wo
nach *einem* N gefragt wird (`analyze_siso_vs_mimo`), wird bewusst
`E_per_bit_all` gelesen statt der Hüllkurve, sonst verschweigen die Zahlen,
wie teuer SISO dort war, wo MIMO gewinnt.

| Auswertung | Die Frage | Maß / Darstellung | Quelle |
|---|---|---|---|
| `analyze_bf_vs_mux_qam` | **Wann ist BF günstiger als MUX, und wovon hängt das ab?** Die Hauptaussage der Studie | **q = E_bit(BF) / E_bit(MUX)**, q < 1 = BF günstiger; über Kanal × ADC-Regel × Distanz, dazu Schnittdistanzen als Tabelle | 3b (Hauptquelle, alle Varianten auf einem Raster) + 3a für die Ratenachse |
| `analyze_rice_comparison` | **Ab welchem Rice-Faktor gewinnt BF?** | **K\***, der Schnittpunkt von E_bit(BF) und E_bit(MUX) über K; interpoliert in log₁₀(K), ausgewiesen nur wenn er zwischen zwei *gerechneten* K liegt | 3b |
| `analyze_mimo_comparison` | Wie verlaufen E_bit, das optimale N und der ADC-Anteil über der Rate? | vier Abbildungen: `cmp_ebit`, `cmp_nopt`, `cmp_adc_share`, `cmp_distance` | 3a (+ 3b für den Distanzschnitt) |
| `analyze_adc_rule` (je Modus), `analyze_adc_rule_all` (alle drei) | **Lohnt das zusätzliche ADC-Bit je Antennenverdopplung?** | Differenz `scaledB` − `fixedB` **in Prozent** (die absoluten Kurven liegen übereinander), zweite Zeile: ADC-Anteil am Budget als Begründung | 3a |
| `analyze_adc_rule_curves` | Woher kommt dieser Effekt — und warum verschwindet er wieder? | zwei Achsen: SE über SNR (dort wirkt das Bit), E_bit über Rate (dort ist es weg) | 3a |
| `analyze_best_gear` | Welcher Gang und welche Antennenzahl gewinnen wo? | Teil A: gewähltes N über der Distanz je Kanal und Regel (aus 3b). Teil B: Gang-Familie über der Rate, QAM dreifach (SISO / MUX / BF) (aus 3a) | 3a + 3b |
| `analyze_siso_vs_mimo` | Ab welcher Rate zahlen sich mehrere Ketten aus? | Umschlagpunkt je N, **nicht** als Hüllkurve (s. o.) | `run_siso_vs_mimo_scaledB` |
| `analyze_analog_bf` | Ab welcher Distanz gewinnt analoges BF, und was kostet der Phasenschieber? | E_bit je Variante über Distanz, dazu `psShare` und `adcShare`; `abf_summary.csv` | `run_analog_bf_distance` |
| `analyze_analog_bf_mixed` | **Lohnt es, nur EINE Seite analog zu bauen — und welche?** | **q = E_bit(beste Mischform) / min(rein digital, rein analog)**, je LO-Fall getrennt; q < 1 nur gegen das *beste* Reine ist eine Aussage. Dazu r = Sender-analog / Empfänger-analog | `run_analog_bf_mixed_distance` + die reinen Referenzen aus `run_analog_bf_distance` |
| `analyze_dbf_dac` | **Was kostet die endliche DAC-Auflösung das digitale BF, und wie stark hängt die Antwort am Leistungsmodell?** | **q = E_bit(endlich) / E_bit(ideal)**, beide als Hüllkurve über (M, N); dazu gewählte Stufe `kBest`, DAC-Anteil, antennenweise gegen gemeinsame Aussteuerung (E9), digital gegen analog | `run_dbf_dac_distance` |

**Die DAC-Auswertung gab es bis zum 2026-10-15 nicht** — 36 gerechnete
Dateien ohne Abnehmer, von der Studie selbst als offener Punkt geführt.
`analyze_dbf_dac` schließt das: vier Abbildungen je Rate plus `summary.csv`
in `results/dbfdac_figures/`.

Sie **weist Dateien von vor E9 ab**, und das ist der eigentliche Punkt: dort
bedeutet `E` die antennenweise Aussteuerung, seit E9 die gemeinsame. Beide
Formen tragen `Eideal`, `Ebest` und `kBest` — eine Prüfung auf Feldnamen
allein merkt den Unterschied also nicht, und q wäre stillschweigend die
Antwort auf die andere Frage. `dacScaleStandard` ist deshalb Pflichtfeld.

**`analyze_siso_vs_mimo_gf`** ist keine eigene Auswertung, sondern baut die
drei GF-Folien (34, 36, 37) aus demselben Material neu.

**Wo die Ergebnisse landen:** `results/cmp_figures/` (MIMO-Vergleich),
`results/abf_figures/` (analoges BF), `results/dbfdac_figures/` (DAC),
`results/abfmix_figures/` (Mischformen). Alle Auswertungen sind reine
Nachbearbeitung — Sekunden, kein Pool, dürfen am Arbeitsplatz laufen.

**Was die Auswertungen ergeben haben.** Links der alte Modellsatz
(2026-10-15), rechts der neue (2026-10-16). Beide auf demselben Raster.

| | alter Satz | neuer Satz |
|---|---|---|
| **K\*** bei 56 m, 1 Gbit/s | 15,2 (11,8 dB) | **6,0 (7,8 dB)** |
| **d\*** bei 1 Gbit/s, K = 0, MUX `scaledB` ↔ BF `fixedB` | 667 m | **3534 m** |
| d\* K = 0, MUX `fixedB` (Gegenprobe) | 721 m | 3463 m |
| d\* `alphabetB` | 170 m | 277 m |
| d\* K = 3 | 66 m | 63 m |
| d\* K = 30 / Rang 1 | 51 m / 46 m | **BF gewinnt überall** (q ≤ 1,000 schon bei 10 m, fallend bis 0,165) |
| d\* bei 1 Mbit/s | keine außer Rang 1 (1008 m) | keine Zeile — q liegt bis ≈ 1 km bei 1,000 und fällt erst am Fernende auf 0,48…0,64 |
| ADC-Regel, MUX, 276 Punkte | Median +0,00 %, max +8,7 % | Median **+0,00 %**, Spanne **−17,9 … +3,7 %**, `scaledB` günstiger in 47,1 % |
| DAC, max q, Kanal `losd` | +13,4 % (`analytic`) | **+5,4 %** (`analytic`), +1,6 % (`analytic_1V`), +0,9 % (`survey`) |
| Gangwahl QAM-BF | 50 m: gar keine, 5 km: 65 von 88 | 50 m: **17** Punkte, 5 km: **49** |
| Mischformen, min q | — | 0,9916 bei 10 km, Fenster 7499…10000 m; Empfänger-analog günstiger |

**Das Bild hat sich geschärft, nicht nur verschoben.** Bei Rayleigh gewinnt
MUX jetzt bis 3,5 km statt 670 m — aber sobald ein LOS-Anteil da ist (K = 3),
gewinnt BF ab 63 m, und ab K = 30 überall. Die K-Achse ist steiler geworden,
deshalb fällt K\* trotz schlechteren Startwerts.

**Die Bandbreite erklärt den neuen Satz fast vollständig** (SISO, d = 50 m,
`run_hw_bandwidth`, Verhältnisse gegen `old`):

| f_c | R | nur B_max neu (`bw_only`) | nur B_max alt (`new`/`bw_old`) | voller neuer Satz |
|---|---|---|---|---|
| 2,4 GHz | 100 Mbit/s | 2,888 | 3,281 | 2,658 |
| 8 GHz | 100 Mbit/s | 3,525 | 4,160 | 3,380 |
| 28 GHz | 1 Gbit/s | 2,242 | 2,568 | 2,105 |

Drei Befunde daraus:

1. **Der Deckel allein wiegt schwerer als der ganze Satz.** `bw_only` ändert
   nur die Bandbreite und liegt bereits über `new`.
2. **Die Bauteilmodelle entlasten netto.** Mit alter Bandbreite ist der neue
   Satz bei mittleren und hohen Raten **günstiger** (0,71…0,90); teuer wird er
   nur unten (1,03…1,31 bei 9 kbit/s), wo die konstanten Posten dominieren.
3. **Beide Isolationen stimmen überein**, mit 10–18 % Aufschlag auf dem neuen
   Untergrund. Der Bandbreiteneffekt ist damit **einzeln zitierbar**.

**Die harte Grenze ist bauteilunabhängig:** 1 Gbit/s ist bei 2,4 und 8 GHz
nicht mehr erreichbar, 10 Gbit/s bei 28 GHz auch nicht — mit beiden
Bauteilsätzen, denn `bw_only` fällt an denselben Stellen aus. Der Deckel nimmt
Arbeitspunkte weg, nicht nur Effizienz. Für die Aussagekraft der Studie ist das
wichtiger als jedes Verhältnis.

**Ein Vorbehalt steckt in fast jeder dieser Zahlen:** bei 1 Gbit/s sitzt ab
etwa 1 km ein Modus am größten verfügbaren N. Die Auswertung markiert das
mit `[R]`; q ist dort eine **Schranke**, nicht der Wert. Das ist E6 (N > 16)
von der Ergebnisseite.

---

## 2. Was gerechnet ist

> **Alle Gearbox-Zahlen dieses Abschnitts: NEUER Modellsatz**, Stand
> 2026-10-16. Der alte Satz liegt vollständig in `results/_oldhw/`. Die
> MI-Kurven sind von der Umstellung nicht betroffen.

**MI-Kurven (QuantizedMimoMI, `qam/results/`) — 1 147 Dateien in 31
Ordnern, vollständig (seit 2026-10-15).**

| Modus | Kanal | ADC-Regel | Stand |
|---|---|---|---|
| MUX | Rayleigh K = 0 | `fixedB`, `scaledB` | 20/20, 20/20 |
| MUX | Rayleigh K = 0 | `alphabetB` | 15/15 (5 nicht rechenbar, B = 27…67) |
| MUX | Rice K = 3, 30 | `scaledB` | **20/20 je K** (die letzten zwei am 2026-10-15) |
| MUX | Rang 1 (K = ∞) | `scaledB` | 20/20 |
| digitales BF | Rayleigh K = 0 | `fixedB` (die `scaledB`-Kurven liegen noch da, E8) | 36/36 |
| digitales BF | Rice K = 3, 30 | `fixedB` | 20/20 je K |
| ideales BF | AWGN + Gewinn | `fixedB` (wie oben, E8) | 36/36 |
| analoges BF | alle vier K | `fixedB` | 20/20 je K |

**DAC-Quantisierung am Sender — alle 24 Ordner vollständig.**
4 Stufen (+0…+3 bit über ½·log₂M) × 2 Aussteuerungen (`common` als
Standard, `perAntenna` als Vergleich) × 3 Empfängerfälle (LOS mit einem
ADC hinter dem Kombinierer, LOS mit einem ADC je Antenne, Rayleigh), beim
Rayleigh-Fall zusätzlich über K = 3 und 30. Zusammen 480 Rice-Dateien in
den `bf_rayleigh_dac*`-Familien.

**Gearbox-Seite — alles neu gerechnet, ein Rest offen.** Stand 2026-10-16,
gemessen; der ganze Satz außer SISO lief in unter 5 h.

| Lauf | Dateien | Stand |
|---|---|---|
| **3b** `cmp_distance_*.mat` | **10 von 10** | ✓ neuer Satz. `per_mixer` ist jetzt Standard, die Dateien tragen **kein** Suffix; `shared` hieße `_loshared` |
| **3a** `cmp_<variante>_d<d>/` | **15 von 15** | ✓ neuer Satz (5 Varianten × 3 Distanzen) |
| `run_sweep` → `main/` | **44** | ✓ **nur SISO** seit 2026-10-16, dafür 4 Träger inkl. 60 GHz (vorher 33 Dateien, 3 Träger, und 9 davon mit falschen MIMO-Spalten) |
| `run_beamforming_*` | 5 Ordner | ✓ |
| `run_siso_vs_mimo_scaledB` | 3 Ordner | ✓ |
| LNA, DAC-Modelle, Hardware alt/neu | `lna_newhw/`, `dac_siso_*`, `hardware_models_newhw/` | ✓ eigene Wurzeln (PR #5), die alten Ordner bleiben als Referenz |
| **Bandbreitenvergleich** | `siso_bw_only_d50`, `siso_bw_old_d50` | ✓ **neu 2026-10-16**. `bw_old` kam vollständig aus dem Ergebnisspeicher — dieselbe Rechnung lag schon vor |
| **Schritt 3** `dbfdac_*` / `abfdac_*` | 24 von 24 digital, 27 von 36 analog | **offen: 9 Dateien** `abfdac_distance_abfKInf_*`. Die Kanaltabelle hat `bfideal` verloren (E13-Nachbar, s. 3.2): Kanal `los` gestrichen, `losd` vergleicht jetzt gegen `abf_fixedB_KInf`. **Vorher 15 Waisen wegräumen** — `analyze_dbf_dac` liest per Glob |
| Analog-BF, Mischformen | 19 bzw. 10 Dateien | **geparkt**, beide bauen auf `bfideal` (Kopfvermerk im Treiber) |

Alle Ergebnisse der *vorherigen* Läufe wurden am selben Tag gelöscht (333
Dateien), weil der Export jede Kurve neu geschrieben hatte — E12-Deckelung,
volles Rice-Raster, E8-Namen, die 24 K=0-DAC-Ordner. Was dabei **blieb**,
weil es Gasts unveränderte `SE_data` liest: `main`, `main100`, `main200`,
`lna/`, `beamforming_d*`, `beamforming_distance.mat` und
`hardware_models/`. Nachgeprüft: `data/SE_data` ist seit dem gemeinsamen
Stand byte-identisch, und Gasts Kurven liegen nirgends über ihrem Cap.

**Läufe über die RATE bei fester Distanz.** Zwei Bauformen stehen im Repo
nebeneinander, und die Übersicht in 3.2 betrifft nur die zweite:
`runSweep`-Treiber parallelisieren über die **Ratenpunkte** bei *einer*
Distanz je Lauf und schreiben einen Ordner `results/<name>_d<distanz>/`; die
Distanz-Treiber (3b, `analog_bf`, `dbf_dac`) parallelisieren über 25
Distanzen bei *zwei* festen Raten und schreiben eine `.mat`.

| Treiber | Distanz(en) | Ratenpunkte | Stand |
|---|---|---|---|
| `run_mimo_comparison_sweep` (3a) | 50 / 500 / 5000 m | 100 | 18 Ordner (6 Varianten × 3 Distanzen) |
| `run_siso_vs_mimo_scaledB` | 50 / 500 / 5000 m | 100 | 3 Ordner |

Die Distanz ist in dieser Bauform kein Sweep, sondern ein Parameter: 50 m ist
die Einstellung der Dissertation, 500 m und 5 km kommen beim BF/MUX-Vergleich
dazu.

Weitere `runSweep`-Treiber im Repo gehören **nicht** zu diesem Vergleich und
haben eigene Dokumente: `run_sweep.m` (SISO-Grundsweep, `results/main*`),
`run_beamforming_sweep`/`_allgears` (der Vorläufer mit Gewinn im Linkbudget,
`BEAMFORMING_EXTENSION.md`), `run_lna_comparison`
(`HPC_RUNBOOK_LNA_VERGLEICH.md`), `run_hw_comparison`
(`HARDWARE_MODEL_SWITCH.md`) und `run_dac_model_siso` (`DAC_POWER_MODEL.md`).
Deren Stand gehört dorthin, nicht hierher.

---

## 3. Was noch fehlt

### 3.1 MI-Kurven: erledigt — offen ist nur der Export

**Erledigt am 2026-10-15** (`QuantizedMimoMI 5764b14`). Die letzten zwei
Kurven — 16×16, 256-QAM, `scaledB` bei K = 3 und K = 30 — sind gerechnet und
geprüft: monoton, endlich, `lower ≤ mid ≤ upper` eingehalten, unter beiden
Schranken (max. MI 123,3 bzw. 99,6 gegen die Alphabetgrenze N_t·log₂M = 128),
dasselbe 21-Punkte-SNR-Raster wie die Nachbarkurven. Laufzeit 27,7 h und
24,2 h — die Schätzung lag bei 22,4 h.

Physikalisch plausibel: MI(K=3) ≥ MI(K=30) ≥ MI(K=∞) durchgängig, also
verliert MUX monoton, je rangärmer der Kanal wird.

**Damit ist jede Familie der Quelle vollständig**, je 5×4 über
N ∈ {1,2,4,8,16} und M ∈ {4,16,64,256}: `bHalf`, `rule_mux` (K = 0/3/30/∞),
`bf_rayleigh` (K = 0/3/30), `bf_ideal`, `bf_analog` (K = 3/30).

**Zwei Aussagen sind damit überholt** und am 2026-10-15 im Code korrigiert:

- „MUX fixedB fehlt M = 256 bei 8×8 und 16×16" (`run_mimo_comparison_sweep.m`,
  `analyze_bf_vs_mux_qam.m`) — `bHalf` trägt alle fünf N für M = 256 (B = 7).
- „die Rice-Läufe rechnen nur N ≤ 4" (`run_mimo_comparison_distance.m`,
  `analyze_bf_vs_mux_qam.m`) — sie reichen bis N = 16.

**Der Export ist aber noch nicht nachgezogen.** Auf der Gearbox-Seite stehen
heute:

| Ordner unter `data/` | N heute | N nach dem Export |
|---|---|---|
| `SE_data_mux_scaledB_K3/_K30` | 1, 2, 4 | 1, 2, 4, 8, 16 |
| `SE_data_bf_scaledB_K3/_K30` | 1, 2, 4 | wurde zu `SE_data_bf_fixedB_K3/_K30` (E8), 1…16 |
| `SE_data_abf_fixedB_K3/_K30/_KInf` | 1…16 | unverändert |

**Was das freischaltet:** `analyze_bf_vs_mux_qam` brauchte `capN = 4`, weil
die Kanalachse sonst zwei Rasterweiten mischte (K = 0 bis 16, Rice bis 4).
Nach dem Export stehen alle Kanäle auf demselben Raster — die Deckelung
entfällt, und der Kanaltrend wird auf dem vollen Gitter lesbar. Das ist die
inhaltliche Verbesserung, die die zwei Kurven bringen.

**Nebenbefund, kein Hindernis:** in `mi_Nt16_Nr16_M256_B11_KInf.mat` (alt,
`nMC = 1`) sind an den vier untersten SNR-Punkten `lower` und `upper`
vertauscht, um ≤ 0,8 % bei MI ≈ 3,2. Der Export nimmt `results.lower`, dort
wäre die exportierte SE an diesen vier Punkten also geringfügig optimistisch
statt konservativ. Ursache: bei `nMC = 1` fallen die beiden Schranken fast
zusammen, und das Schätzrauschen dreht die Reihenfolge. Die beiden **neuen**
Dateien zeigen keine solche Verletzung.

### 3.2 Die Gearbox-Läufe, in dieser Reihenfolge

| # | Schritt | Was gegen was | Umfang |
|---|---|---|---|
| 1 | `export_mimo_comparison_curves` | *vergleicht nichts* — legt die Vergleichsbasis: fünf Kurvenordner — MUX × `fixedB`/`scaledB`/`alphabetB`, BF und ideales BF nur `fixedB` (E8) — dazu fünf Rice-Ordner | **✓ gelaufen 2026-10-15** (`079372c`): 12 Ordner, keine Warnung. `SE_data_mux_scaledB_K3/_K30` von 8 auf 16 Kurven (N bis 16), `SE_data_bf_fixedB_K3/_K30` neu (= Deckelungsreferenz für Schritt 2), `SE_data_bf_scaledB_K3/_K30` gelöscht (vor E8). Alle Kurven nach E12 gedeckelt |
| 2 | `export_dbf_dac_curves` | *vergleicht nichts* — je DAC-Stufe ein Ordner, damit Schritt 3 die Stufen gegeneinander stellen kann | **✓ gelaufen 2026-10-15** (`9ca8ce9`): 41 Ordner, keine Warnung, beide Deckelungen wirksam (E12 an der Alphabetgrenze, E4 gegen die Ideal-DAC-Kurve). Dabei einen Fehler behoben, der **alle 24 K=0-Ordner** bei jedem Lauf übersprang — siehe unten |
| 3 | `run_dbf_dac_distance` | **idealer DAC gegen 4 endliche Stufen** (plus Minimum über die Stufen), dazu gemeinsame gegen antennenweise Aussteuerung, 3 DAC-Leistungsmodelle, 2 LO-Fälle — über die Distanz. Die analogen Varianten laufen als Referenz mit, weil das DAC-Modell auch sie trifft | 25 Worker; rechnet die 18 vorhandenen Dateien neu (E9) und die Kanäle `ray3`/`ray30`. **Stand 20 von 66:** `losd` und die analogen `abf_*` fertig, `los` fast, die drei Rice-Kanäle noch nicht begonnen |
| 4 | `run_analog_bf_distance` | **analoges gegen digitales BF bei gleicher Kurve**: 3 Phasenschieber-Varianten (aktiv / passiv kompensiert / passiv mit Strafe) gegen die digitale Kette mit 4 LO-Fällen (gemeinsam, 4 / 12,5 / 17 mW je Mischer), 2 ADC-Modelle | **GEPARKT seit 2026-10-16** (E13-Nachbar): Fall 1 liest `SE_data_bfideal_fixedB` — auch für die vier digitalen Varianten. Der Vergleich läuft jetzt über die DAC-Studie. Kopfvermerk im Treiber nennt, was zum Wiederbeleben nötig wäre. Der alte Lauf (38 von 38, `394989d`) liegt in `_oldhw/` |
| 5 | `run_mimo_comparison_distance` (3b) | **BF gegen MUX über die Distanz**, 12 Varianten auf *demselben* Raster: ADC-Regel (`fixedB`/`scaledB`/`alphabetB`) × Kanal (Rayleigh K = 0, Rice 3 / 30, Rang 1), bei 2 Raten und 25 Distanzen | **✓ neu gerechnet 2026-10-16**, 10 von 10 (vorher 12 — `bf_scaledB` und `bfideal_scaledB` sind mit E8 entfallen). `per_mixer` ist der Standard, die Dateien tragen kein Suffix |
| 6 | `run_mimo_comparison_sweep` (3a) | ✓ **neu gerechnet 2026-10-16**, 15 von 15 (5 Varianten × 3 Distanzen; vorher 21 mit den beiden scaledB-BF-Varianten) — **dasselbe BF/MUX-Paar über die volle Ratenachse** statt zwei Raten — 100 Ratenpunkte bei 50 / 500 / 5000 m, aber nur K = 0. Hier wird der Gangwechsel sichtbar, nicht in 3b | `mux_alphabetB` (kommt von selbst, sobald exportiert) — 100 Kerne. **Die Angabe „8 h je Lauf“ stand hier und war irreführend:** die `RESSOURCEN`-Zeile des Treibers nennt 12 h für den *ganzen* Lauf, und gemessen am 2026-10-16 war der komplette Neurechnungssatz außer SISO in unter 5 h fertig. Aus der alten Zahl × 15 Läufen entstand eine Schätzung von 120 h — Faktor zehn zu hoch. **Die 5 Rice-Varianten dagegen nicht:** `run_mimo_comparison_sweep.m:33` trägt eine feste Liste der sechs K = 0-Fälle, nur `mux_alphabetB` kommt bedingt dazu (Zeile 41). Wer 3a heute startet, bekommt keinen Rice-Lauf. Dafür müssen `mux_scaledB_K3/_K30/_KInf` und `bf_fixedB_K3/_K30` in `VARIANTS` — eine Codeänderung, kein Lauf |
| 7 | `analyze_rice_comparison`, `analyze_bf_vs_mux_qam` | **q = E_bit(BF) / E_bit(MUX)** als Hüllkurve über (M, N) — jeder Modus darf seine beste Konfiguration wählen, q < 1 heißt BF günstiger. Daraus **K\***, der Rice-Faktor, ab dem BF gewinnt | **✓ gelaufen**: K\* = 15,2 bei 56 m; d\* von 721 m (Rayleigh) bis 46 m (Rang 1); das zusätzliche ADC-Bit im Median wertlos. Alles unter `shared` — siehe Abschnitt 5 |

**Welche Achse welcher Lauf aufspannt** — das ist der Grund, warum es 3a *und*
3b gibt und keiner von beiden den anderen ersetzt:

| Lauf | Distanz | Rate | Kanal | ADC-Regel |
|---|---|---|---|---|
| 3b | 25 Punkte, 10 m…10 km | **2** (1 Mbit/s, 1 Gbit/s) | K = 0, 3, 30, ∞ | `fixedB`, `scaledB`, `alphabetB`¹ |
| 3a | **3** (50, 500, 5000 m) | 100 Punkte, 10³…10¹¹ bit/s | nur K = 0 | `fixedB`, `scaledB`, `alphabetB`¹ |

¹ `alphabetB` kommt in beiden Läufen nur dazu, wenn `SE_data_mux_alphabetB`
exportiert ist — beide prüfen den Ordner selbst. Die Regel ist MUX-only: bei
Beamforming kommt **ein** Strom an, das beobachtete Alphabet ist M unabhängig
von N_t, und `adcBitsRule` fällt dort mit `fixedB` zusammen. Ein
BF-`alphabetB`-Lauf wäre bitgleich zu `bf_fixedB`.

Schritt 1 **muss** vor 2 laufen, sonst warnt der Export mit
`export:noDacCapRef` und schreibt die Rice-DAC-Kurven ungedeckelt.

**Der K=0-Fehler in Schritt 2 (behoben 2026-10-15).** Der erste Lauf schrieb
nur 17 der 41 Ordner. Ursache war kein fehlendes Datum, sondern der Test „trägt
die Quelle dieses K überhaupt?": für K = 0 lautete er
`dir(strrep(pattern, '*.mat', '*[0-9].mat'))` und sollte „endet auf eine
Ziffer, also kein `_K`-Suffix" heißen. **MATLABs `dir` kennt keine
Zeichenklassen** — es suchte wörtlich nach `[0-9]`, fand nie etwas, und
damit wurden **alle 24 K=0-Ordner bei jedem Lauf übersprungen**. Die
vorhandenen stammten von vor dieser Prüfung.

Was das gekostet hat, über die fehlende E12-Deckelung hinaus:
`SE_data_bf_fixedB_dac{1,2,3}_common` und
`SE_data_bflosd_fixedB_dac{1,2,3}_common` waren **nie geschrieben worden**.
Die gemeinsame Aussteuerung ist seit E9 der Standardfall, und
`run_dbf_dac_distance` verweigert einen Kanal ohne diese Ordner
(`commonIncomplete`) — der Standardfall war also nur für Stufe 0 rechenbar.
Jetzt liegen alle vier Stufen für alle fünf Kanäle vor, je Antenne **und**
gemeinsam.

**Doppelte Rechnungen fallen jetzt weg (neu, 2026-10-14).** Sieben der elf
Ergebnisschlüssel je 3a-Ordner hängen nicht an der Variante — die SISO-Gänge
lesen die 24 Kurven, die in allen 36 `SE_data*`-Ordnern inhaltsgleich liegen.
Gemessen: E_bit stimmt über alle sechs Varianten auf 2e-9 überein, also
**105 von 486 Konfigurations-Sweeps = 21,6 % der Laufzeit von 3a** waren
Wiederholung. Ein Ergebnisspeicher unter `results/_store/`, adressiert über
den Fingerabdruck der Rechnung, nimmt sie jetzt heraus; die sprechenden
Ordner- und Dateinamen bleiben unverändert. Einzelheiten, Messbefehle und
was bewusst offen bleibt: `RESULT_NAMING.md`.

**Was alle Vergleiche tragen und wo sie brechen können.** Alle sechs
Grundvarianten laufen im Gearbox-Modus `multiplexing`: der Array-Effekt steckt
**in der Kurve** (MUX: N Ströme; Rayleigh-BF: E[λ_max]; ideales BF:
deterministischer Gewinn N_t·N_r als Verschiebung der SNR-Achse), das
Linkbudget bekommt nichts gutgeschrieben, und die Hardware skaliert je Kette
gleich. Der Unterschied zwischen den Verfahren liegt damit **allein in der
Kurve** — deshalb ist der Vergleich überhaupt zulässig. Zwei Stellen, an denen
er kippen würde, und beide sind abgesichert:

- **Ungleiche (M, N)-Auswahl.** Fehlt eine Kombination auf einer Seite, gewinnt
  die andere allein durch die größere Auswahl. `analyze_bf_vs_mux_qam`
  maskiert deshalb je Zelle **symmetrisch** über `E_per_bit_all` und
  `antennaConfigsUsed`, nicht über die schon gebildete Hüllkurve.
- **Ungedeckelte DAC-Kurven.** Ohne E4 liegt eine gröbere Stufe stellenweise
  über der feineren, und `minOverDacLevels` wählt sie dann genau deswegen.

**Wo diese sieben Schritte laufen (neu, 2026-10-14).** Auf dem Windows-Cluster
wie bisher — oder auf dem **ZIH-Cluster** der TU Dresden (Barnard/Romeo, Linux
+ SLURM): `sbatch hpc/zih/submit_study.sbatch <Treiber>`. Das Clusterprofil
und die Workerzahl kommen jetzt aus `+sweep/poolProfile.m` bzw.
`+sweep/workerBudget.m`, die Ergebniswurzel aus `GEARBOXPHY_RESULTS_ROOT`;
ohne gesetzte Variablen ist alles bitgleich zu vorher. **Auf dem ZIH-Cluster
ist noch nichts gelaufen** — Schritt 0 des Runbooks ist Pflicht.
Anleitung: `HPC_RUNBOOK_ZIH.md`.

Die **MI-Kurven aus 3.1 bleiben auf Windows**: ihre parallele Achse sind die
400 Kanalrealisierungen je SNR-Punkt, und 200 Worker (2 Wellen) sind dort
schneller als 104 Kerne eines Barnard-Knotens (4 Wellen) — 22,4 h gegen 45 h.
`QuantizedMimoMI` ist für den ZIH-Cluster deshalb bewusst nicht angepasst.

**K\* = 15,2 bei 56 m (11,8 dB)** — **alter Modellsatz** (Kasten oben),
gemessen am 3b-Lauf vom 2026-10-15,
`analyze_rice_comparison`. Die alte Zahl 16,5 entstand unter BF-`scaledB`
und hat sich durch E8 wie erwartet zu kleinerem K verschoben.

| d | R | K | MUX | BF | BF/MUX |
|---|---|---|---|---|---|
| 56 m | 1 Gbit/s | 0 | 6,40e-11 | 6,96e-11 | 1,087 |
| | | 3 | 6,46e-11 | 6,70e-11 | 1,037 |
| | | 30 | 6,63e-11 | 6,52e-11 | 0,984 |
| | | ∞ | 6,69e-11 | 6,50e-11 | 0,971 |

**K\* gilt nur bei 56 m.** Schon bei 562 m liegt der Schnittpunkt zwischen
K = 0 und K = 3 und ist damit nicht auflösbar (K = 10 wurde ausgelassen, und
log₁₀0 existiert nicht); bei 5623 m ist BF **bereits bei Rayleigh**
günstiger (BF/MUX = 0,412), es gibt dort also keinen Schnittpunkt mehr. Die
Zahl ist eine Aussage über eine Distanz, nicht über die Studie.

Und sie gilt unter `loDistributionModel = "shared"` — mit LO-Aufschlag
verschiebt sich das Bild deutlich, siehe Abschnitt 5.

**Analoges gegen digitales BF (Schritt 4, 2026-10-15).** **Alter
Modellsatz** (Kasten oben). d\* ist die Distanz,
ab der analog bis zum Rasterende günstiger bleibt; q = E_bit(analog) /
E_bit(digital, gemeinsamer LO), beides Hüllkurve über (M, N). ADC-Modell
`envelope`; `quantile5` weicht um höchstens 18 % ab (ein Fall), meist unter
2 %.

| Phasenschieber | Kanal | d\* bei 1 Mbit/s | d\* bei 1 Gbit/s | bestes q |
|---|---|---|---|---|
| **aktiv** | alle vier K | **keine** | **keine** | 1,00 |
| passiv + Kompensation | LOS (ideale Kurve) | 316 m | 56 m | 0,39 / 0,56 |
| passiv, nur Verlust | LOS (ideale Kurve) | 56 m | < 10 m | 0,37 / 0,39 |
| passiv + Kompensation | Rayleigh K = 0 | 316 m | — (Fenster 316 m) | 0,68 / 0,94 |
| passiv + Kompensation | Rice K = 3 / 30 / ∞ | 316 m | — (Fenster 56…316 m) | 0,53 / 0,67 |
| passiv, nur Verlust | Rice K = 3 / 30 / ∞ | 56 m | — (Fenster 10…1778 m) | 0,53 / 0,42 |

**Drei Befunde, und der erste wiegt am schwersten:**

1. **Der aktive Phasenschieber macht die analoge Kette durchweg teurer** —
   q ≥ 1,00 an jeder Distanz, bei beiden Raten, in jedem Kanal, unter beiden
   ADC-Modellen. Was die eine Kette spart, verbraucht der Phasenschieber je
   Element. Der gesamte analoge Vorteil hängt damit an **passiven**
   Phasenschiebern, also an `PHASE_SHIFTER_POWER_MODEL.md`.
2. **Bei 1 Gbit/s ist der analoge Vorteil ein Fenster, keine Halbgerade.**
   In den gerechneten Kurven (Fall 2/AP3) steigt q am Fernende wieder weit
   über 1 (bis 7,0 bei 10 km): ein Strom trägt die Rate dort nicht mehr,
   16 Ströme schon. Nur die *idealen* Kurven aus Fall 1 halten analog bis
   10 km vorn (q = 0,84…0,86).
3. **Rice verschärft den analogen Fall monoton**, aber nur bis K = 3: bei
   1 Mbit/s und „passiv, nur Verlust" fällt d\* von 316 m (K = 0) auf 56 m
   (K = 3), und K = 30 und K = ∞ ändern danach nichts mehr. Das beste q geht
   von 0,68 auf 0,53.

**Eine Konsistenzprüfung, die der Lauf gratis mitliefert:** bei 1 Mbit/s
geben Fall 1 (ideale Kurve, analytischer Gewinn N_t·N_r) und AP3 mit K = ∞
(gerechnete Kurve, Gewinn in der Kurve) **dasselbe** d\* — 316 m bzw. 56 m
je Phasenschieber. Bei 1 Gbit/s tun sie es nicht, und der Abstand ist groß:
siehe Abschnitt 5.

### 3.3 Nach jeder Änderung an Sweep oder Speichern

`tests/smoke_test.m` und `tests/mimo_smoke_test.m` ausführen, nicht nur die
Unit-Suite: nur diese zwei fahren `runSweep` und die Speicherebene. Ein
Fehler dort stand am 2026-10-13 in main, während die Suite 85/85 meldete.

### 3.4 Welcher Lauf für welchen Vergleich

Die Zuordnung in beide Richtungen: jeder Lauf hat einen Abnehmer, und jede
Auswertung aus Abschnitt 1 hat eine Quelle. Wo eine Spalte leer bleibt, ist
das ein offener Punkt und keine Auslassung.

| Lauf | Ausgabe | Beabsichtigter Vergleich | Wird gelesen von |
|---|---|---|---|
| `export_mimo_comparison_curves` | `data/SE_data_<variante>/` | — (legt die Vergleichsbasis) | 3a, 3b, Schritt 2 als Deckelungsreferenz |
| `export_dbf_dac_curves` | `data/SE_data_..._dac<k>[_common]/` | — (eine Stufe je Ordner) | `run_dbf_dac_distance` |
| **3a** `run_mimo_comparison_sweep` | `results/cmp_<variante>_d<d>/` | BF ↔ MUX **über die Rate**; ADC-Regel `fixedB` ↔ `scaledB` | `analyze_mimo_comparison`, `analyze_adc_rule`, `analyze_adc_rule_all`, `analyze_adc_rule_curves`, `analyze_best_gear` (Teil B), `analyze_bf_vs_mux_qam` (Ratenachse) |
| **3b** `run_mimo_comparison_distance` | `results/cmp_distance_<variante>.mat` | BF ↔ MUX **über Distanz und Kanal** (K = 0 / 3 / 30 / Rang 1) | `analyze_bf_vs_mux_qam` (**Hauptquelle**), `analyze_rice_comparison`, `analyze_best_gear` (Teil A), `analyze_mimo_comparison` (Distanzschnitt) |
| `run_siso_vs_mimo_scaledB` | `results/cmp_sisomimo_scaledB_d<d>/` | SISO ↔ MIMO, **aufgelöst nach N** statt als Hüllkurve | `analyze_siso_vs_mimo`, `analyze_siso_vs_mimo_gf` |
| `run_analog_bf_distance` | `results/abf_distance_<variante>_<adc>.mat` | **analoges ↔ digitales BF** bei gleicher Kurve; 3 Phasenschieber, 4 LO-Fälle, 2 ADC-Modelle | `analyze_analog_bf` — **✓ gelaufen** (38/38, Ergebnis in 3.2) |
| `run_analog_bf_mixed_distance` | `results/abfmix_distance_<variante>_<lo>.mat` | gemischte Architekturen (analoger Sender ↔ digitaler Empfänger und umgekehrt) × LO-Fälle | `analyze_analog_bf_mixed` (seit 2026-10-15) — **der Lauf fehlt noch** (0 Dateien) |
| `run_dbf_dac_distance` | `results/dbfdac_distance_*.mat`, `abfdac_distance_*.mat` | **idealer ↔ endlicher DAC** (4 Stufen), `common` ↔ `perAntenna`, 3 DAC-Leistungsmodelle | `analyze_dbf_dac` (seit 2026-10-15) |
| `run_dbf_dac_los_newhw` | dieselben Dateinamen, Satz `hw_new` | alte ↔ survey-gestützte Hardwaremodelle im LOS-Fall | `analyze_dbf_dac`, wo `hw_new` als weitere Spalte erscheint |

**Keine leere Zelle mehr.** Beide Lücken sind am 2026-10-15 geschlossen
(`analyze_dbf_dac`, `analyze_analog_bf_mixed`). Was bei den Mischformen noch
fehlt, ist der **Lauf** — und für die Rayleigh-Mischfälle die Kurven
(`SE_data_abftx_fixedB` und `SE_data_abfrx_fixedB` fehlen beide, es laufen
also nur die fünf LOS-Varianten × 2 LO-Fälle = 10 Dateien).

**Was jetzt noch offen ist, ist kein Abnehmer, sondern ein Lauf:** die
Mischformen (0 von 10 Dateien) und die drei Rice-Kanäle von Schritt 3
(0 von 45). Beide Auswertungen stehen und warten auf Eingangsdaten.

---

### 3.5 Die Rang-1-Annahme prüfen — ⚠ offen, noch kein Lauf

Der Banner oben nennt die Annahme, hier steht, was sie prüfen würde. Nichts
davon ist gerechnet, nichts davon ist angefangen.

1. **`riceChannel.m` um eine Geometrie erweitern.** Heute: `Hlos = aR * aT'`,
   Fernfeld, zwei Steuervektoren, Rang 1 per Konstruktion. Nötig ist ein
   zweiter Zweig mit **Kugelwelle** — `H_LOS(m,n) = exp(-j·2π·d_mn/λ)` aus
   den tatsächlichen Elementpositionen und dem Abstand R. Nur so kann der
   LOS-Kanal überhaupt vollrangig werden. Die Schnittstelle ist da (`los`
   als struct), der Inhalt nicht.
2. **Den Elementabstand als Entscheidung behandeln, nicht als Nebenbei.**
   λ/2 steht derzeit fest verdrahtet im Steuervektor. Unter λ/2 ist der
   LOS-Kanal ab wenigen Zentimetern rangarm, das heutige Modell ist dort
   also **richtig**:

   | | Vollrang-Abstand `√(λR/N)` | Apertur N·d | λ/2-Array: vollrangig nur bis |
   |---|---|---|---|
   | 28 GHz, R = 10 m, N = 32 | 5,8 cm | 1,85 m | R ≤ 8,6 cm |
   | 28 GHz, R = 100 m, N = 32 | 18,3 cm | 5,86 m | R ≤ 8,6 cm |
   | 28 GHz, R = 10 m, N = 4 | 16,4 cm | 0,65 m | R ≤ 1,1 cm |
   | 2,4 GHz, R = 10 m, N = 32 | 19,8 cm | 6,33 m | R ≤ 1,00 m |

   Die Frage ist deshalb nicht „ist das Modell falsch", sondern **„ist λ/2
   die richtige Wahl für eine Verbindung, die auf Energie optimiert wird"**.
3. **Die Hypothese, die das interessant macht:** eine größere Apertur kostet
   im Energiemodell **nichts** — keine zusätzliche Kette, kein zusätzlicher
   Wandler, nur Mechanik. Wenn LOS-MIMO bei kurzer Distanz praktisch gratis
   vollen Rang liefert, kippt die Empfehlung aus F1/F2 genau dort, wo
   Beamforming heute am deutlichsten gewinnt.
4. **Billigster erster Test, bevor irgendetwas Großes läuft:** MI für
   **einen** vollrangigen LOS-Kanal (28 GHz, 10 m, N = 8) gegen die
   vorhandene Rang-1-Kurve derselben Größe. Ein Punkt, eine Stunde — und er
   entscheidet, ob Punkt 1 bis 3 die Arbeit wert sind.

**Zweiter, kleinerer Punkt in derselben Spalte:** die drei Systeme rechnen
LOS derzeit **auf verschiedenen Geometrien**. Digitales BF mittelt über 32
Richtungspaare (`runQamSweepBfLosDigitalDac`), MUX und analoges BF rechnen
nur Broadside (`runQamSweep32Los`, `runQamSweepBfAnalog`). Das ist ein
Modellunterschied **innerhalb** der LOS-Spalte, kein Messergebnis, und er
gehört in jede Aussage, die die drei bei LOS nebeneinanderstellt.

## 4. Entscheidungen

**Getroffen.**

| # | Entscheidung |
|---|---|
| E1 | Rice auf dem vollen 20er-Gitter rechnen (71 h), statt bei N ≤ 4 zu bleiben |
| E2 | Rice **nur** für `scaledB` — kein zweites Rice-Raster für `fixedB` oder `alphabetB`. Die Regel kostet im Median 0,00 %, ein zweiter Satz brächte keine neue Aussage |
| E3 | DAC-Leistungsmodell als Schalter mit altem Default — war schon gebaut |
| E4 | DAC-Kurven am Ideal-DAC deckeln; Quantisierung darf nicht helfen |
| E5 | ZXM / IR / CPM kommen nicht in die MIMO-Matrix |
| E8 | ADC-Regel je Modus: MUX `scaledB`, digitales BF `fixedB` (ein Strom, kein log₂N). **`scaledB` existiert für Beamforming nicht** — seit dem 2026-10-15 ist das überall durchgezogen, nicht mehr nur bei den Rice-Zeilen (s. u.) |
| E9 | Gemeinsame Aussteuerung ist der Standard, `perAntenna` der Vergleich |
| E10 | DAC-Quantisierung auch über Rice, volles Kreuzprodukt (320 Kurven, 4,6 h) |
| E12 | MI-Kurven beim Export an der Alphabetgrenze deckeln (wie E4), nicht nur warnen — `log₂M` bei BF, `N_t·log₂M` bei MUX |
| E13 | **Die Baseline unter MIMO ist NA-QAM mit festem N_peak**, nicht SISO-1024-QAM (2026-10-16, s. u.) |

**Zu E13: die Bezugsgröße, gegen die „Ersparnis“ gemessen wird.**

Gasts Diss vergleicht durchgehend `E*_bit / E*_bit|single-gear` — **ein fest
verdrahtetes Front End, auf die Spitzenrate ausgelegt**, das sich nur noch
über den Duty Cycle anpasst. In Fig. 5.3c ist das die flache Linie
`B* = η·f_c`: volle Bandbreite, immer. NA-QAM ist nur die *Instanz* davon, und
die Diss sagt es selbst:

> „at peak data rates, no savings are possible because the high spectral
> efficiency requirement mandates the use of 1024-QAM, **which at high
> bandwidths is equivalent to the single-gear approach**."

Dazu ihr eigener Vorbehalt zu Fig. 4.5: „the relative energy efficiency gains
**strongly depend on the chosen b_fix** for comparison". Die Baseline trägt
die Kopfzahl — deshalb ist ihre Wahl unter MIMO keine Formsache.

**Warum SISO-1024-QAM nicht mehr trägt**, zwei Gründe:

1. **Oft nicht erreichbar.** Gemessen am 2026-10-16: unter dem Kanal-Deckel
   ist 1 Gbit/s bei 2,4 und 8 GHz mit SISO unmöglich (20 MHz verlangen
   SE = 50 bit/s/Hz), bei 28 GHz 10 Gbit/s. Eine Baseline, welche die Aufgabe
   nicht erfüllt, ist keine — das Verhältnis ist `NaN`, keine Ersparnis.
2. **Sie macht die Zahl unehrlich.** Hat die Baseline N = 1 und darf das
   Gearbox bis N = 16, steckt im „Saving“ der **Arraygewinn**. Das ist keine
   Ersparnis durch Schalten, sondern durch mehr Antennen — genau das
   Artefakt, vor dem die Diss warnt.

**Die Festlegung:** das Prinzip bleibt (eine feste Konfiguration, auf die
Spitzenrate ausgelegt, einzige Anpassung ist der Duty Cycle), nur ist „fest“
jetzt **(M, N)** statt M allein. N_peak ist das kleinste N, mit dem die
Spitzenrate bei voller Bandbreite erreichbar ist.

Der Vergleich wird dadurch **aussagekräftiger**, nicht schwächer: die Baseline
zahlt bei jeder Rate N_peak Ketten voller konstanter Leistung (LO, Mischer,
ADC, DAC), und genau das spart das Gearbox, indem es bei niedrigen Raten
Ströme abschaltet. Gemessen werden damit zwei Freiheitsgrade des Schaltens
statt einem.

**Was zu bauen ist, drei Schritte:**

| | |
|---|---|
| 1 | `+gears/naQamGear.m:38` gibt im Multiplexing-Modus die Konfigurationen durch, statt `{1x1}` festzunageln. Im Beamforming-Modus folgt er `beamformingConfigs` bereits |
| 2 | N_peak aus Spitzenrate des Rasters und `B_max` bestimmen — gerechnet, nicht von Hand gesetzt, sonst wandert es beim nächsten Bandbreitenwechsel wieder auseinander |
| 3 | `analyze_bf_vs_mux_qam` eine zweite Bezugsspalte geben |

**Was es kostet:** die NA-QAM-Ergebnisse in 3a (15 Ordner) und 3b (10
Varianten) werden neu gerechnet — ihre Form ändert sich
(`antennaConfigsUsed`), also auch ihr `resultFingerprint`. Die QAM-Seite
bleibt unberührt. Nach den Messungen vom 2026-10-16 ist das überschaubar.

**Der ehrliche Vorbehalt:** mit N_peak schrumpft die Kopfzahl gegenüber einer
SISO-Baseline deutlich. Das ist die Korrektur eines Artefakts, aber es ändert
die Aussage der Arbeit — und das soll bewusst passieren. Deshalb **beide
zeigen**: SISO-1024-QAM als Anschluss an die Diss, wo es erreichbar ist, und
NA-QAM/N_peak als den fairen MIMO-Vergleich. Die Diss stellt in Fig. 5.6
selbst einen anderen Ratenbereich daneben als in Fig. 5.3, zwei Bezugsgrößen
nebeneinander brechen dort also nicht mit der Darstellungsweise.

**Zu E8: nachgezogen am 2026-10-15.** Die Entscheidung stand seit dem
2026-10-12, war aber nur auf die Rice-Zeilen angewandt. `bf_scaledB` und
`bfideal_scaledB` lebten weiter in der K=0- und der Rang-1-Zeile von
`analyze_bf_vs_mux_qam`, in den Variantenlisten von 3a/3b, im Export und in
den beiden MI-Treibern. Jetzt gilt in jeder Zeile: **BF trägt `fixedB`**, und
`rule` bezeichnet durchgehend die MUX-seitige Regel.

| Stelle | vorher | jetzt |
|---|---|---|
| `analyze_bf_vs_mux_qam`, K=0/scaledB | `mux_scaledB` ↔ `bf_scaledB` | `mux_scaledB` ↔ **`bf_fixedB`** |
| `analyze_bf_vs_mux_qam`, Rang 1 | `mux_scaledB_KInf` ↔ `bfideal_scaledB` | `mux_scaledB_KInf` ↔ **`bfideal_fixedB`** |
| `analyze_adc_rule`, `_all`, `_curves` | `mode ∈ {mux, bf, bfideal}` | **nur `mux`** — die Frage stellt sich sonst nicht |
| `VARIANTS` in 3a und 3b, `analyze_mimo_comparison` | 6 Varianten | **4** |
| `export_mimo_comparison_curves` | 7 Zeilen | **5** |
| `runQamSweepBfIdeal`, `runQamSweepBfRayleigh` | `["fixedB" "scaledB"]` | **`"fixedB"`** |

**Was sich dadurch an den Zahlen ändert** — alle folgenden Werte **alter
Modellsatz** (Kasten oben); `analyze_bf_vs_mux_qam` nach der
Umstellung gelaufen, 3b-Dateien unverändert:

| Zeile | vorher | jetzt |
|---|---|---|
| K=0, MUX `scaledB` (d\* bei 1 Gbit/s) | 762 m, gegen `bf_scaledB` | **667 m**, gegen `bf_fixedB` |
| Rang 1 (d\* bei 1 Mbit/s) | 1006 m | 1008 m |
| K=0 `fixedB`, `alphabetB`, K=3, K=30, Rang 1 bei 1 Gbit/s | 721 / 170 / 66 / 51 / 46 m | **unverändert** |

Die K=0-Zeile unter MUX-`scaledB` ist die, die sich bewegt — sie ist auch die
einzige, deren BF-Seite getauscht wurde (die Rice-Zeilen trugen `bf_fixedB`
schon). Sie ist jetzt **die Hauptzeile**: jeder Modus mit seiner Regel. Die
`fixedB`-Zeile bleibt als Gegenprobe „was, wenn MUX die Bits nicht bekommt".

**Die Kopfzahl geht damit aus zwei Gründen von 721 m auf 667 m**, und beide
gehören auseinandergehalten: eine **andere Zeile** ist jetzt maßgeblich
(721 m war die `fixedB`-Gegenprobe und ist unverändert), und diese Zeile hat
sich **selbst** bewegt (762 → 667 m).

**WARUM sie sich bewegt, nachgemessen an der Zelle, die bei d\* gewinnt
(BF: M = 4, N = 8).** `scaledB` gibt dieser Zelle 3 ADC-Bit mehr:

| d | SE-Gewinn | ADC-Anteil am Budget | E_bit |
|---|---|---|---|
| 422 m | +0,7 % | 0,7 % → **5,2 %** | +4,2 % |
| 562 m | +1,1 % | 0,6 % → **4,4 %** | +3,5 % |
| 750 m | +1,1 % | 0,5 % → **3,6 %** | +2,7 % |

Die Bits heben die SE um rund ein Prozent — mehr ist nicht zu holen, es
kommt EIN Strom an. Der Wandler kostet dafür 2^b, mal N_r Stück: der
ADC-Anteil versechsfacht sich und E_bit steigt um 3 bis 4 %. Genau das
zahlte die BF-Seite vorher umsonst.

**Dass daraus 12 % in d\* werden, liegt an der Flachheit von q.** Im Band
560…750 m ist dln(q)/dln(d) ≈ −0,19: ein Prozent in q ist dort rund fünf
Prozent in der Distanz. Die (M,N)-Abdeckung ist für beide BF-Varianten
identisch (gleiches NaN-Muster), die symmetrische Maskierung spielt also
keine Rolle.

Die Rang-1-Probe bei N = 1 hält weiter, weil dort beide Regeln zusammenfallen:
beide Dateien liefern dieselbe q-Spanne auf vier Stellen und weichen
untereinander um 4,2e-4 ab — Optimierer-Rauschen, dieselbe Größenordnung, die
den 1006 → 1008-m-Versatz erklärt.

**Was dadurch verwaist** (liegt noch da, wird von nichts mehr gelesen):
`data/SE_data_bf_scaledB`, `data/SE_data_bfideal_scaledB`,
`results/cmp_distance_bf_scaledB.mat`,
`results/cmp_distance_bfideal_scaledB.mat` und die sechs 3a-Ordner
`results/cmp_bf_scaledB_d{50,500,5000}` /
`cmp_bfideal_scaledB_d{50,500,5000}`.

**Offen.**

| # | Frage | Empfehlung |
|---|---|---|
| E6 | N > 16? | nein — `alphabetB` dort nicht rechenbar, Phasenquantisierung verliert ohnehin |
| E7 | `isfile`-Aussetzer auf dem UNC-Share? | **entschärft 2026-10-15**: `filterAvailableAntennaConfigs` verwirft einen Kandidaten nur noch, wenn **beide** Prüfungen ihn nicht finden (Verzeichnisliste *und* `isfile`), und die Liste wird je Ordner gecacht — ein Share-Zugriff statt 20 je Aufruf, rund 157 000 je Vollauf von Schritt 3. Dazu `+data/findFeasibilityHoles.m`, das die Folge nachweist statt sie zu vermuten. Befund über alle 68 Ergebnisdateien: eine betroffen, 2 Zellen |
| E11 | Golden Master belastbar machen? | je Testmethode seeden **und** Toleranz auf die echte Streuung weiten (E_bit ~1e-2, γ ~1e-1) |

Zu **E11**: `qamMatchesOriginal` und `naQamMatchesOriginal` vergleichen zwei
Zufalls-Optimierer auf RelTol 1e-6 — beide Seiten ziehen ungeseedet aus dem
globalen Strom. Gemessene Streuung: 0,42 % in E_bit, 4,4 % in γ, wobei die
neue Seite das bessere Optimum findet. Grün über die Dateiform, rot über die
Ordnerform; der Mechanismus dahinter ist nicht aufgeklärt. Einen Seed zu
suchen, bei dem es grün wird, wäre Rosinenpickerei.

---

## 5. Grenzen, die in jede Aussage gehören

### 5.1 Die größte: „LOS" ist Rang 1, und Rang 1 ist eine Modellwahl

`riceChannel.m` setzt `Hlos = aR * aT'` — ein äußeres Produkt, Rang 1 bei
**jedem** Winkelpaar. Broadside ist dabei nur der Default (dort ist
`λ_max(H_LOS H_LOS') = N_t·N_r` exakt, was den Grenzübergang an die
Gewinnannahme des idealisierten Beamformings anschließt); andere Winkel
ändern die Phasenlage gegenüber dem Quantisierungsraster, nicht den Rang.

**Richtung, in die es das Ergebnis schiebt:** zugunsten von Beamforming,
und zwar genau dort, wo die Studie Beamforming empfiehlt. Mit steigendem K
verliert Multiplexing per Konstruktion seine Ströme; K\* misst deshalb, ab
welcher Rangarmut ein Strom billiger ist als N Ströme — eine richtige Zahl
zu einer anderen Frage als der, die der Name „Rice-Faktor" nahelegt.

**Wie weit die Annahme trägt:** unter λ/2-Arrays weit. Vollrang verlangt
`d_t·d_r ≈ λ·R/N`; mit `d = λ/2` heißt das `R ≤ N·λ/4`, bei 28 GHz und
N = 32 also 8,6 cm. Für jede Distanz dieser Studie ist der broadside
λ/2-LOS-Kanal damit tatsächlich Rang 1. Die Lücke ist nicht die Physik des
Modells, sondern dass λ/2 nie als Entscheidung behandelt wurde — Tabelle
und Vorgehen in Abschnitt 3.5.

**Bis das geprüft ist, gilt:** überall „Rang 1" schreiben, wo „LOS" gemeint
wäre, und keine Empfehlung der Form „bei Sichtverbindung Beamforming" aus
F1/F2/F3 ableiten.

### 5.2 Hardwaremodelle und Messannahmen

Keine davon ist ein Fehler; jede schiebt das Ergebnis in eine bekannte
Richtung. Für die ersten vier gibt es inzwischen Schalter, und
`hardwareModel = "new"` setzt sie gemeinsam auf die 5-%-Quantile der drei
Hardware-Übersichten; der Default `"custom"`/`"old"` ist bitgleich zu allen
bestehenden Ergebnissen.

- **ADC = Walden-Bestfall** (Median 26× optimistisch) und **DAC = 3 V**
  (rund 6× pessimistisch) — zusammen begünstigen sie digitale Architekturen.
  Schalter: `adcPowerModel = "quantile5"`, `dacPowerModel = "survey"`.
- **LO-Verteilung im digitalen Zweig nicht berechnet** — begünstigt digital.
  Schalter: `loDistributionModel = "per_mixer"`.

  **Gemessen am fertigen Schritt-4-Lauf (2026-10-15): der Aufschlag
  verschiebt d\* NICHT.** Hier stand vorher „mit 12,5–17 mW je Mixer gewinnt
  analog ab 180–240 m" — eine Schätzung von vor dem Lauf. Alle vier LO-Fälle
  (gemeinsam, 4 / 12,5 / 17 mW) ergeben auf dem 25-Punkte-Raster **dasselbe**
  d\*, in jedem geprüften Kanal und bei beiden Raten.

  Der Grund ist nicht, dass der Aufschlag klein wäre, sondern **wo** er
  greift: er ist (n−1)·P_buf, und bei d\* wählt die digitale Hüllkurve
  N = 1 bis 2 — dort ist er null. Teuer wird er erst, wo analog ohnehin
  schon vorn liegt:

  | d | N digital | 4 mW | 12,5 mW | 17 mW |
  |---|---|---|---|---|
  | 1 Mbit/s, 316 m (≈ d\*) | 1 | 1,000 | 1,000 | 1,000 |
  | 1 Mbit/s, 10 km | 8 | 1,204 | **1,442** | 1,566 |
  | 1 Gbit/s, 56 m (≈ d\*) | 1 | 1,000 | 1,000 | 1,000 |
  | 1 Gbit/s, 1778 m | 16 | 1,136 | **1,422** | 1,572 |

  **Für BF gegen MUX (3b) gilt das nicht** — dort haben *beide* Seiten N
  Ketten und wählen bei d\* große, aber verschiedene N. Deshalb bleibt der
  LO-Fall für 3b wirksam (nächster Absatz) und ist nur für den
  analog/digital-Vergleich neutral.

  **Der Aufschlag trifft nur die digitale Seite**, und zwar von selbst: die
  Formel ist (n_Mischer − 1)·P_buf, und eine analoge Kette hat *einen*
  Mischer. Nachgemessen (16×16, 28 GHz): digital 214,4 mW gegen 26,9 mW
  (Aufschlag 187,5 mW = 15 × 12,5 mW), analog 26,9 mW — Aufschlag **0**.

  **Für BF gegen MUX ist das nicht neutral, aber dort neutral, wo die
  Aussage am stärksten ist.** Beide Modi haben N Ketten; wo sie dasselbe N
  wählen, kürzt sich der LO-Anteil im Verhältnis q heraus. Gemessen am
  3b-Lauf vom 2026-10-15 (R = 1 Gbit/s, K = 0, `fixedB`): nur **12 von 25
  Distanzen** mit gleichem N.

  | d | N bei MUX | N bei BF | q | LO wirkt |
  |---|---|---|---|---|
  | 100 m | 4 | 2 | 1,127 | ja |
  | 316 m | 16 | 4 | 1,065 | ja |
  | 750 m | 16 | 8 | 0,991 | ja |
  | 1000 m | 16 | 16 | 0,872 | nein |
  | 10 000 m | 16 | 16 | 0,393 | nein |

  Im Fernbereich, wo BF deutlich gewinnt, wählen beide N = 16 — dort ändert
  der LO-Fall nichts. **Rund um die Schnittdistanz d\* ≈ 721 m** wählt MUX
  N = 16 und BF N = 8, dort zahlt MUX also mehr: `per_mixer` verschiebt d\*
  zu **kleineren** Distanzen.

  **Und die Größe ist nicht klein.** Gemessen am 2026-10-15 mit beiden
  LO-Fällen, K = 0, `fixedB`, R = 1 Gbit/s:

  | d | `shared` | `per_mixer` |
  |---|---|---|
  | 100 m | q = 1,127 | q = **0,977** |
  | 750 m | q = 0,991 | q = 0,932 |

  Bei 100 m kippt q von „BF 12,7 % teurer" auf „BF günstiger" — d\* fällt
  damit von ≈ 721 m auf **unter 100 m**, also um mindestens den Faktor 7.
  Die Zahlen sind an zwei Distanzen mit M = 4 gerechnet, und das ist hier
  keine Einschränkung: im vollen 3b-Lauf ist M = 4 an beiden Stellen das
  Optimum beider Modi, der `shared`-Wert 1,127 stimmt mit ihm überein.

  **Konsequenz für jede Aussage über d\*:** die Schnittdistanzen aus
  Abschnitt 1 (667 m bei Rayleigh, 46 m bei Rang 1) gelten unter
  `shared` — also ohne LO-Aufschlag. Mit Aufschlag verschieben sie sich
  deutlich nach unten.

  **`per_mixer` ist seit dem 2026-10-15 kein eigener Lauf mehr**, sondern
  der Standard: `hardwareModelPreset("new")` enthält
  `loDistributionModel = "per_mixer"`, und mit PR #4 ist der
  `oldModelArgs()`-Pin entfallen, der 3b bisher auf `shared` hielt.
  Der Schalter `LO_MODEL` im CONFIG-Block bleibt, aber mit gedrehter
  Bedeutung:

  | `LO_MODEL` | Ausgabe |
  |---|---|
  | `"per_mixer"` (Standard) | `cmp_distance_<variante>.mat` — **ohne** Suffix |
  | `"shared"` | `cmp_distance_<variante>_loshared.mat` |

  Das Suffix trägt jetzt der **abweichende** Fall. Bis zum 2026-10-15 war
  es umgekehrt (`per_mixer` bekam `_permixer`), was den Standardfall als
  Sonderfall ausgewiesen hätte.

  **Die 12 vorhandenen `cmp_distance_*.mat` werden nicht umbenannt.** Sie
  sind mit dem *ganzen* alten Modellsatz gerechnet, nicht nur mit
  gemeinsamem LO — ein Name `_loshared` würde sie als „neue Modelle,
  gemeinsamer LO" ausgeben. Ihr `resultFingerprint` passt nicht mehr, sie
  werden also neu gerechnet und überschrieben.
- **Frequenzflacher Kanal** — ein Tap, keine Verzögerungsachse. Die
  Bandbreite ist frei und liegt am oberen Ratenende zwei bis drei
  Größenordnungen über der Kohärenzbandbreite. *(Richtung unbekannt, kein
  Schalter.)*
- **i.i.d. Rayleigh ist vollrangig** — begünstigt MUX; BF verliert 0,6 bis
  6,8 dB gegen N_t·N_r.
- **MI ist bei N ≥ 4 und M ≥ 64 eine untere Schranke** (7–13 % Schlupf nahe
  der Sättigung) — wirkt gegen MUX.
- **Die Schätzung überschritt die Alphabetgrenze** am Sättigungsende: BF bis
  +0,78 %, MUX bis +0,05 %, systematisch steigend mit N (Median je N:
  0,04 / 0,05 / 0,18 / 0,29 % für N = 2/4/8/16). Das begünstigte BF entlang
  genau der Achse, die der Vergleich messen soll. **Seit E12 wird gedeckelt**
  (`QuantizedMimoMI 12213cc`); die Felder `seCapRef`, `seCapPoints` und
  `seCapMaxRel` je Kurve machen es nachlesbar. Kurven aus früheren Exporten
  tragen die Felder nicht und sind ungedeckelt.
- **Phasenquantisierung** `G = 1 + (N−1)·sinc²` ist gegenüber echter Rundung
  leicht pessimistisch (≤ 1,1 dB bei 1 bit) — wirkt gegen analog.
- **Fall 1 der Analog-Studie rechnet mit den IDEALEN Kurven**
  (`SE_data_bfideal_fixedB`, die 1×1-Dateien) — und zwar für die digitalen
  *und* die analogen Varianten. Zwei Vereinfachungen stecken darin, beide
  zugunsten der digitalen Seite: der Gewinn ist **analytisch** exakt
  N_t·N_r (für Rang 1 richtig, sonst 0,6–6,8 dB zu großzügig), und
  kombiniert wird **vor einem ADC** — das ist der *analoge* Empfänger, als
  digitale Referenz eine Vereinfachung ohne DAC-Drehungsstrafe. Dazu kommt:
  in diesem Lauf trägt keine Kurve DAC-Quantisierung (`sourceBdac = NaN`).

  **Wie groß das ist, sagt der fertige Lauf selbst**, weil AP3 mit K = ∞
  denselben Rang-1-Kanal über die *gerechneten* Kurven fährt:

  | R | Fall 1 (ideale Kurve) | AP3, K = ∞ (gerechnet) |
  |---|---|---|
  | 1 Mbit/s, d\* | 316 m / 56 m | **316 m / 56 m** — gleich |
  | 1 Gbit/s, q bei 10 km | 0,86 | **4,65** |

  Bei niedriger Rate stimmen beide Wege überein, bei hoher Rate um den
  Faktor 5,4 nicht. Jede Aussage über analoges BF bei 1 Gbit/s und großer
  Distanz muss deshalb die **gerechneten** Kurven nennen, nicht Fall 1.
  *(Richtung bekannt: Fall 1 begünstigt analog am Fernende.)*

---

## 6. Wo die Begründungen stehen

| Thema | Ort |
|---|---|
| Ablauf der Läufe, Schritt für Schritt | `HPC_RUNBOOK_MIMO_VERGLEICH.md`, `HPC_RUNBOOK_ANALOG_BF.md`, `HPC_RUNBOOK_DAC.md` |
| Zweiter Cluster (ZIH, SLURM): Einrichtung, Schritt 0, Ressourcen je Studie | `HPC_RUNBOOK_ZIH.md`, `hpc/zih/README.md` |
| Doppelt gerechnete Teilkonfigurationen, Namenskonvention der Ergebnisdateien | `RESULT_NAMING.md` |
| Wandler- und Hardwaremodelle | `ADC_POWER_MODEL.md`, `DAC_POWER_MODEL.md`, `LNA_POWER_MODEL.md`, `HARDWARE_MODEL_SWITCH.md` |
| DAC-Quantisierung, Aussteuerung | `DAC_QUANTISATION_SPEC.md` |
| Rice-Erweiterung, analoges BF | `RICE_EXTENSION_PLAN.md`, `ANALOG_BEAMFORMING.md`, `PHASE_SHIFTER_POWER_MODEL.md` |
| Code-Abgleich mit dem HPC | `codeManifest('snapshot')` im Ordner `code_manifest/` |
| Warum eine Entscheidung so fiel | die Commit-Nachricht, die sie umsetzt |
