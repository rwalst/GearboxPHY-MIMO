# Neurechnung mit den neuen Hardwaremodellen — vier Wrapper, 500 Kerne

Nach PR #2 (`81bd77f`, neue Vorgaben) und PR #4 (`a83809c`, `oldModelArgs()`-Pin
entfernt) rechnet jeder Treiber mit dem neuen Modellsatz. **Alle vorhandenen
Gearbox-Ergebnisse sind damit ungültig** und werden neu gerechnet; ihr
`resultFingerprint` passt nicht mehr, sie werden also nicht als „fertig"
übersprungen.

Die MI-Kurven in `data/SE_data*` sind **nicht** betroffen — sie sind
informationstheoretisch und kennen keine Hardware. Es ist **kein Export
nötig.**

| | alt | neu (Standard) |
|---|---|---|
| LNA | `fom_bandwidth` | `fom_floor` |
| ADC | `envelope` (0,67 fJ) | `quantile5` (3,17 fJ) |
| DAC | `analytic` (3 V) | `survey` |
| LO-Verteilung | `shared` | `per_mixer` |
| B_max | 0,1·f_c | ein Kanal (20 / 100 / 400 MHz) |

---

## Aufteilung der 500 Kerne

Vier MATLAB-Sitzungen, gleichzeitig. Jede setzt ihren Anteil selbst über
`GEARBOXPHY_WORKERS`; `+sweep/workerBudget.m` liest die Variable als erste
Quelle.

| Wrapper | Kerne | Läufe |
|---|---|---|
| `run_newhw_w1` | **100** | 3a `mux_fixedB` + `mux_scaledB` (6 Läufe) → `run_analog_bf_distance` |
| `run_newhw_w2` | **100** | 3a `bf_fixedB` + `bfideal_fixedB` (6 Läufe) → `run_dbf_dac_distance` |
| `run_newhw_w3` | **100** | 3b → `run_analog_bf_mixed_distance` → 3a `mux_alphabetB` (3 Läufe) |
| `run_newhw_w4` | **200** | `run_sweep` (SISO) → 3× `run_beamforming_*` → `run_siso_vs_mimo_scaledB` → `run_dac_model_siso` → `run_lna_comparison` → `run_hw_comparison` |

`run_sweep` rechnet seit dem 2026-10-16 **nur noch SISO**. Er forderte vorher
1×1 bis 8×8 gegen den Basisordner `data/SE_data`, dessen neun MIMO-Kurven aus
einem Export **vor** der Einführung von `snrReference` stammen — je Strom
normiert, während das Gearbox die Gesamtleistung budgetiert. `loadSECurve`
weist sie ab, und genau daran brach W4 am 2026-10-16 ab. Der Abbruch war
richtig: `results/main` trug diese Spalten für M = 4/16/64 und schenkte
Multiplexing dadurch +3,0 / +6,0 / +9,0 dB. Die MIMO-Achse liegt jetzt allein
bei 3a, 3b und der Analog-Studie, die regelgetaggte Kurvenordner lesen.

**Warum diese Zahlen und nicht 125 × 4.** Die Kernzahl, die ein Lauf nutzen
kann, ist nicht wählbar — sie steckt in seiner parallelen Achse:

| Lauf | parallele Achse | nützliche Worker |
|---|---|---|
| `run_sweep` | 400 Ratenpunkte, `maxCores` = 200 | **200** |
| 3a, `run_siso_vs_mimo_scaledB`, `run_lna_comparison`, `run_dac_model_siso`, `run_hw_comparison` | 100 Ratenpunkte | **100** |
| 3b, `run_analog_bf_distance`, `run_analog_bf_mixed_distance`, `run_dbf_dac_distance` | 25 Distanzen | **25** |

`run_sweep` ist der einzige Lauf, der über 100 hinaus schneller wird — deshalb
bekommt W4 die 200. Für W1–W3 wären mehr als 100 wirkungslos.

**Die vier Distanzstudien deckeln bei 25.** Während ein Wrapper eine davon
rechnet, liegen 75 seiner 100 Kerne brach. Das ist die Achse, keine
Einstellung: `parfor` läuft über die 25 Distanzen. Deshalb stehen die
Distanzstudien in W1 und W2 **hinter** dem 3a-Teil, der die 100 füllt.

**Spitzenauslastung ≈ 425 von 500**, solange alle vier auf ihren Ratensweeps
sind. Mehr ist mit vier Sitzungen nicht zu holen. Wer die restlichen 75 nutzen
will, braucht eine fünfte Sitzung für eine der Distanzstudien.

---

## Schritt 0 — Validierung, Minuten, kein Pool

```matlab
addpath('<repo>'); setupGearboxPath;
validate_mimo_comparison      % bitgenaue Regression, bleibt absichtlich ALT
validate_analog_bf
smoke_test                    % setupGearboxPath legt tests/ auf den Pfad
mimo_smoke_test
```

Die beiden `validate_*` prüfen gegen gespeicherte **alte** Ergebnisse und
bleiben deshalb auf dem alten Satz gepinnt — sie müssen weiter grün sein.

---

## Schritt 1 — die vier Wrapper starten

**Nach einem `git pull` zuerst `clear functions`.** MATLAB behält eine schon
geladene `.m`-Datei im Cache, auch wenn der Pull sie geändert hat — die
Sitzung rechnet dann mit dem alten Code weiter. Am 2026-10-16 hat das einen
Lauf gekostet: `run_hw_bandwidth` führte **zwei** statt vier Varianten aus,
weil die Variantenliste noch die alte war. Es gibt dabei keine Fehlermeldung,
nur ein unvollständiges Ergebnis — und genau deshalb steht es hier.

```matlab
clear functions          % nach jedem Pull, VOR dem Lauf
rehash                   % falls Dateien neu hinzugekommen sind
```

Vier MATLAB-Sitzungen, je eine Zeile:

```matlab
addpath('<repo>'); setupGearboxPath; run_newhw_w1
addpath('<repo>'); setupGearboxPath; run_newhw_w2
addpath('<repo>'); setupGearboxPath; run_newhw_w3
addpath('<repo>'); setupGearboxPath; run_newhw_w4
```

Mehrere Sitzungen gleichzeitig sind erlaubt: `startPool` legt je Prozess einen
eigenen `JobStorageLocation` an, und die Wrapper schreiben in getrennte
Ergebnisordner.

**Jeder Lauf läuft in try/catch.** Ein Fehler nimmt die übrigen Läufe des
Wrappers nicht mit; am Ende steht eine Tabelle mit Dauer und Fehlerkennung je
Lauf. Nach einem Abbruch den Wrapper einfach erneut starten — Fertiges wird
übersprungen, aber nur bei passendem `resultFingerprint`.

---

## Vorher: den alten Satz beiseite legen

**Alle Ergebnisse werden an derselben Stelle neu geschrieben.** `runSweep` und
die vier Distanzstudien überspringen eine fertige Datei nur bei passendem
`resultFingerprint` — sonst rechnen sie neu und **überschreiben**. Der alte
Satz ist danach weg, es sei denn, er liegt vorher woanders.

```matlab
archive_oldhw_results              % Probe: zeigt nur, was in die Liste fällt
archive_oldhw_results("move")      % verschiebt nach results/_oldhw/
```

Es wird **nichts gelöscht**. Der Probelauf ist die Vorgabe; `"move"` muss man
ausdrücklich übergeben. Betroffen sind rund 100 Ordner und Dateien: 3b (12),
3a (21), Analog-BF (38), DAC (20), SISO-Grundsweep und Beamforming (9), dazu
die zwei Abbildungsordner.

**Danach committen** — die Ergebnisse sind versioniert, git sieht
Umbenennungen, und der alte Satz bleibt als Vergleichsarm in der Geschichte.

**Eine Ausnahme vom „gültigen Vergleichsarm":** die MIMO-Spalten von
`main`, `main100` und `main200` bei M = 4/16/64 sind **nicht** nur
alter Modellsatz, sie sind falsch — sie entstanden mit den je Strom
normierten Kurven (s. o.). Als SISO-Spalte bleiben die Dateien brauchbar,
als MIMO-Vergleich nicht.
Das ist, was der Kasten am Anfang von `MIMO_TODO.md` mit „zwei vollständige
Sätze auf demselben Raster" verspricht.

**Der Zielname ist fest (`_oldhw`), nicht datiert**, und das hat einen Grund:
`validate_mimo_comparison` sucht seine Referenzdateien unter
`results/_oldhw/<pfad>` — **Archiv zuerst**, dann der lebende Ordner. Ohne
vorhersagbaren Pfad wäre die bitgenaue Regression nach dem Archivieren blind.
Ein vorhandenes, nicht leeres Archiv wird deshalb abgelehnt statt erweitert.

### Nicht mitarchiviert: LNA und Hardwaremodelle

`results/lna/` und `results/hardware_models/` bleiben, wo sie sind. Beide
Studien binden jeden Ordner per Stempeldatei an seinen Fall und verweigern
einen Ordner mit abweichendem Stempel (`lna:stampMismatch`,
`hw:stampMismatch`) — absichtlich, damit nie ein Ordner zwei Modellsätze
vermischt. PR #4 hat die Stempel um `adc`, `dac`, `lo` und `bandwidth`
erweitert, die 22 vorhandenen Ordner tragen also den alten.

Verschieben wäre **ein** Weg gewesen. Der bessere liegt auf Branch
`newhw-result-roots`: der neue Satz bekommt eigene Wurzeln
(`results/lna_newhw/`, `results/hardware_models_newhw/`), die alten Ordner
bleiben als Referenz liegen. **Solange dieser Branch nicht gemergt ist,
brechen W4s Läufe 7 und 8 ab.** Sie stehen deshalb am Ende von W4 — wer nicht
aufgeräumt hat, verliert keine Rechenzeit. Die Vorabprüfung in W4 liest die
Wurzel aus der Config, die Warnung verstummt nach dem Merge von selbst.

### Ein Fund am Rande, der nichts mit dem Archivieren zu tun hat

`validate_mimo_comparison` G1 prüfte **gar nichts** und meldete trotzdem
Erfolg: zwei Referenzdateien gibt es in dieser Ordnerstruktur nicht mehr (die
Namen stammen von vor dem Aufräumen am 2026-10-02), bei den anderen zwei
fehlte `results/` im Pfad. Behoben: Pfade über `paths.resultsDir`, Archiv
zuerst, und **null geprüfte Fälle sind jetzt ein FAIL**. Eine Regression, die
nichts vergleicht, ist schlimmer als keine.

`validate_lna_comparison` L2 hat dasselbe Muster und alle vier Referenzen
fehlen — liegt bei der Hardware-Session.

---

## Laufzeit: gemessen, nicht geschätzt

**Am 2026-10-16 war der komplette Satz ausser den SISO-Laeufen in unter 5 h
fertig** — 3a, 3b, Analog-BF, Mischformen und die DAC-Studie zusammen, auf
vier Sitzungen. Offen sind nur noch die SISO-Läufe aus W4.

Damit ist die Aufteilung auf vier Wrapper nicht die Engstelle und eine
Umverteilung der 3a-Varianten (6/6/3 gegen 5/5/5) erübrigt sich.

**Eine Schätzung, die hier stand, war um den Faktor zehn zu hoch.** Sie
entstand aus „8 h je Lauf" × 15 Läufen = 120 h für 3a — die erste Zahl kam
aus einer `MIMO_TODO`-Zelle über einen älteren Stand, während die
`RESSOURCEN`-Zeile des Treibers 12 h für den **ganzen** Treiber nennt. Die
beiden widersprachen sich, und der Widerspruch blieb unbemerkt. Festgehalten,
weil die Lehre allgemein ist: zwei Angaben zur selben Sache sind erst eine
Schätzung, wenn sie zusammenpassen.

Der **gemessene Faktor** des neuen Modellsatzes gegen den alten bleibt
dagegen gültig, er war nicht das Problem:

| Form | zulässige Punkte | Faktor neu/alt |
|---|---|---|
| Ratensweep (1e3…1e11) | 23 → 20 von 25 | **1,60×** langsamer |
| Distanzstudie (2 feste Raten) | 10 → 10 von 10 | **0,57×** schneller |

Der Mechanismus: ein **unzulässiger** Punkt kostet 1,344 s, ein zulässiger
0,128 s — Faktor 10,5, weil der Optimierer sein ganzes Multistart-Budget
verbraucht, um die Unzulässigkeit zu beweisen. Das kleinere `B_max` (ein
Kanal statt 0,1·f_c) schiebt bei den Ratensweeps Punkte über die Kante; die
Distanzstudien rechnen nur 1 Mbit/s und 1 Gbit/s, beide bleiben zulässig.

Jeder Lauf druckt seine Dauer, und der Runner fasst sie am Ende zusammen.

---

## Danach: die Auswertungen

Reine Nachbearbeitung, Sekunden, kein Pool, darf am Arbeitsplatz laufen.

```matlab
analyze_bf_vs_mux_qam         % d*, die Hauptaussage
analyze_rice_comparison       % K*
analyze_mimo_comparison
analyze_adc_rule              % nur mode="mux", s. E8
analyze_adc_rule_all, analyze_adc_rule_curves
analyze_best_gear
analyze_analog_bf, analyze_analog_bf_mixed
analyze_dbf_dac
analyze_hw_comparison, analyze_lna_comparison
analyze_siso_vs_mimo, analyze_siso_vs_mimo_gf
```

**Erst danach `docs/MIMO_TODO.md` fortschreiben.** Dort steht heute ein Kasten
„alle Messwerte gehören zum alten Modellsatz" — sobald die neuen Zahlen da
sind, gehören beide Sätze nebeneinander, und der Kasten wird zur Legende des
alten Arms.

---

## Wo was steht

| Thema | Ort |
|---|---|
| Entscheidung je Komponente, alt/neu | `HARDWARE_MODEL_SWITCH.md` |
| Kernbudget je Sitzung | `+gearboxphy/+sweep/workerBudget.m` |
| Was welcher Lauf vergleicht | `MIMO_TODO.md` Abschnitt 3.4 |
| Stand und Grenzen der Aussagen | `MIMO_TODO.md` Abschnitte 1, 2, 5 |
| ZIH-Cluster statt Windows | `HPC_RUNBOOK_ZIH.md` |
