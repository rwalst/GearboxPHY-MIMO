# Runbook: Gearbox-Studien auf dem ZIH-Cluster (TU Dresden)

Stand 2026-10-14. Der ZIH-Cluster ist eine **Alternative** zum Windows-Cluster, kein
Ersatz: beide bleiben benutzbar, und derselbe Treiber laeuft auf beiden.

> **Auf dem ZIH-Cluster ist noch nichts gelaufen.** Der Code ist dafuer vorbereitet und
> lokal geprueft (Unit-Suite 101 Tests, beide Smoke-Tests), aber kein Schritt dieses
> Runbooks ist dort ausgefuehrt worden. Schritt 0 ist deshalb Pflicht und nicht
> optional -- er klaert in einer Stunde interaktiv, was sonst nach zwoelf Stunden
> Wartezeit als abgebrochener Job sichtbar wird.

## Arbeitsteilung: welcher Cluster wofuer

| | Cluster | Warum |
|---|---|---|
| **MI-Kurven** (`QuantizedMimoMI`) | weiter Windows | Die parallele Achse ist `nMC = 400` Kanalrealisierungen je SNR-Punkt, die Laufzeit haengt an `ceil(nMC/w)`. Windows gibt 200 Worker, also 2 Wellen; ein Barnard-Knoten hat 104 Kerne, also 4. Die teuerste offene Kurve braeuchte dort **45 h statt 22,4 h**. QuantizedMimoMI ist fuer den ZIH-Cluster bewusst **nicht** angepasst. |
| **Gearbox-Studien** (dieses Repo) | Windows **oder** ZIH | Parallelisiert wird ueber 25 Distanzen bzw. 100 Ratenpunkte -- das passt auf einen Knoten. Kein Checkpoint-Umbau, keine Job-Arrays, kein `mcc`. |

Der Gewinn liegt nicht in der Geschwindigkeit eines Laufs, sondern in der **Breite**: die
Gearbox-Seite besteht aus vielen unabhaengigen Laeufen, und auf dem ZIH-Cluster koennen
mehrere davon gleichzeitig in der Warteschlange stehen, ohne den Windows-Cluster zu
blockieren, auf dem die MI-Kurven rechnen.

## Was im Code dafuer geaendert wurde

| Neu / geaendert | Wofuer |
|---|---|
| `+gearboxphy/+sweep/poolProfile.m` | Das Clusterprofil an **einer** Stelle. Reihenfolge: `GEARBOXPHY_CLUSTER_PROFILE` -> bei gesetztem `SLURM_JOB_ID` ein knotenlokales `Processes` -> `HPCServer`, wenn vorhanden -> Standardprofil. Vorher stand `"HPCServer"` als Literal an fuenf Stellen. |
| `+gearboxphy/+sweep/clusterFor.m` | Liefert das Clusterobjekt und setzt `NumThreads = 1` (abgesichert: ein Profil, das die Eigenschaft nicht annimmt, bleibt beim Vorgabewert, statt den Lauf abzubrechen). |
| `+gearboxphy/+sweep/workerBudget.m` | Deckelt die gewuenschte Workerzahl an `SLURM_CPUS_PER_TASK`, sonst am Profil, sonst an `feature('numcores')` -- **und warnt mit Zahlen**. |
| `+gearboxphy/+paths/resultsDir.m` | Liest `GEARBOXPHY_RESULTS_ROOT` und deckt damit alle 47 Aufrufstellen ab. |
| `+gearboxphy/+paths/isAbsolutePath.m` | Erkennt absolute Pfade plattformneutral; `dataDir`, `resultsDir` und `+data/absoluteDir` benutzen jetzt dieselbe Definition. |
| `hpc/zih/submit_study.sbatch` | Die Einreichung. **Ausnahme von der Repo-Konvention "keine Shell-Skripte"** (`HPC_RUNBOOK_MIMO_VERGLEICH.md`) -- vom Nutzer fuer `hpc/zih/` erlaubt, weil SLURM eine Shell-Ebene verlangt. Das Skript waehlt nichts aus und rechnet nichts. |
| `tests/+unit/ClusterPortabilityTest.m` | 11 Tests. Der wichtigste: bei **ungesetzter** Variable entstehen dieselben Pfade wie vorher. |

Ohne gesetzte Umgebungsvariablen verhaelt sich alles genau wie vorher -- das ist die
Bedingung dafuer, dass der Windows-Weg unberuehrt bleibt.

## Die zwei Umgebungsvariablen

| Variable | Wirkung | Wann |
|---|---|---|
| `GEARBOXPHY_RESULTS_ROOT` | Verlegt die Wurzel **aller** Ergebnisse. | Auf dem ZIH immer (Workspace). Das Jobskript setzt sie. |
| `GEARBOXPHY_CLUSTER_PROFILE` | Erzwingt ein Profil. | Nur als Notausgang, wenn die Automatik das falsche waehlt. |

**`GEARBOXPHY_RESULTS_ROOT` lenkt Lesen UND Schreiben um.** Das ist die eine Falle dieses
Umbaus: `analyze_mimo_comparison`, `analyze_adc_rule_curves` und die `+report`-Funktionen
lesen ueber dieselbe Funktion. Wer die Variable setzt und die vorhandenen ~73 MB unter
`results/` nicht mitkopiert, bekommt keinen Fehler -- die Auswertung sieht einen leeren
Ordner und hält jeden Lauf fuer noch nicht gerechnet. `submit_study.sbatch` kopiert
deshalb vor dem Lauf hin und danach zurueck (`rsync -au`, beide Richtungen).

---

## Schritt 0 -- eine Stunde interaktiv, vor allem anderen

```
srun --partition=barnard --nodes=1 --cpus-per-task=8 --mem-per-cpu=2000M --time=1:00:00 --pty bash
module load MATLAB
```

| | Pruefung | Erwartung |
|---|---|---|
| **T0** | `parallel.clusterProfiles()`, `license('test','Distrib_Computing_Toolbox')` | `'HPCServer'` ist **nicht** dabei, `'Processes'` ist es. Genau das begruendet `poolProfile`. |
| **T1** | `gearboxphy.sweep.clusterFor()`, dann `parpool(ans, 8)`; dazu `getenv('SLURM_CPUS_PER_TASK')` **und** `feature('numcores')` ausgeben | Pool steht. Melden die beiden Zahlen Verschiedenes, ist der Deckel ueber `SLURM_CPUS_PER_TASK` richtig -- `numcores` wuerde den ganzen Knoten melden. |
| **T2** | `ws_allocate --filesystem horse gearbox 90`, dann `gearboxphy.sweep.checkWorkersSeeDir("<ws>/results")` | "reachable and writable by all 8 workers". Diese Funktion gab es schon; sie prueft genau das. |
| **T3** | Eine kleine Studie fahren, danach `sacct -j <id> --format=JobID,MaxRSS,Elapsed` | Daraus `--mem-per-cpu`. Barnard erlaubt bis 2403 MB/Kern, Romeo nur 1972 MB -- liegt der Bedarf darueber, fällt Romeo weg. |

## Schritt 1 -- Einrichtung

```
cd ~ && git clone <remote> GearboxPHY-MIMO     # Code ins Home: versioniert, klein
ws_allocate --filesystem horse gearbox 90      # Ergebnisse in den Workspace
```

Die Kurvenordner unter `data/` sind versioniert und kommen per `git pull` mit; `dataDir`
hat **keinen** Umgebungsschalter, nur die Ergebnisse wandern.

## Schritt 2 -- erster Lauf

```
cd ~/GearboxPHY-MIMO
sbatch hpc/zih/submit_study.sbatch run_analog_bf_distance
```

`run_analog_bf_distance` ist die richtige erste Studie: 25 Worker, Stunden statt Tage, und
sie faehrt die ganze Kette durch (Profil, Pool, Workspace, Ergebnisdatei).

## Schritt 3 -- die Gegenprobe, und sie kostet nichts

Eine **vorhandene** Ergebnisdatei auf dem ZIH neu rechnen und gegen die gespeicherte
vergleichen (`SKIP_EXISTING = false` im Treiberkopf). Die Gearbox-Optimierung ist
deterministisch bis auf die Zufallsstarts in `multistartOptimize`; Abweichungen duerfen
daher nur in der Groessenordnung liegen, die der Golden Master ohnehin zeigt (0,42 % in
`E_bit`). Alles darueber heisst: etwas haengt an der Umgebung, nicht am Modell.

## Ressourcen je Studie

Die Workerzahl steht im Treiberkopf (`RESSOURCEN:`), `--cpus-per-task` ist eins mehr --
ein Kern fuer den Client.

| Studie | Worker | `--cpus-per-task` | Partition |
|---|---|---|---|
| `run_analog_bf_distance`, `run_analog_bf_mixed_distance` | 25 (Distanzen) | 26 | barnard |
| `run_mimo_comparison_distance` | 25 (Distanzen) | 26 | barnard |
| `run_dbf_dac_distance` | 25 (Distanzen) | 26 | barnard |
| `run_mimo_comparison_sweep` (3a) | 100 (Ratenpunkte) | 101 | barnard (104 Kerne, knapp) oder romeo (128) |
| `run_lna_comparison`, `run_hw_comparison`, `run_dac_model_siso` | 100 (Ratenpunkte) | 101 | barnard / romeo |

Mehr Worker als die Zahl der Punkte bringt nichts -- die Achse ist dann erschoepft, und
`workerBudget` deckelt zusaetzlich an dem, was der Knoten hergibt.

## Grenzen und was absichtlich fehlt

- **Kein `mcc` / keine Kompilierung.** Im kompilierten Programm zeigt
  `mfilename('fullpath')` in das entpackte CTF-Archiv, und darauf baut `+paths/root.m` --
  die Wurzel, von der alle Daten- und Ergebnispfade abhaengen. `matlab -batch` haelt eine
  Client-Lizenz je Job; die Worker eines `Processes`-Pools ziehen keine zusaetzliche.
- **Kein MATLAB Parallel Server, kein `configCluster.sh`.** Der Pool entsteht *innerhalb*
  des Jobs auf einem Knoten. Einen Job aus einem Job heraus einzureichen hiesse, dass der
  aeussere Job wartend seine Walltime verbraucht.
- **Keine Job-Arrays.** Die Studien laufen einzeln; `+data/checkpointFile.m` ist schon
  array-freundlich (eine Datei je Ratenpunkt, rennfrei), falls das spaeter noetig wird.
- **Der Workspace laeuft ab** (hier 90 Tage; `ws_list` zeigt den Rest, `ws_extend`
  verlaengert). Was nur dort liegt, ist danach weg -- deshalb der `rsync` zurueck ins Repo
  am Ende jedes Jobs.
- **Walltime** maximal 7 Tage, interaktiv 12 h, auf den Login-Knoten 600 s. Keine
  Gearbox-Studie kommt diesen Grenzen nahe.
