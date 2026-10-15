# `hpc/zih/` -- Einreichung auf dem ZIH-Cluster

Dieser Ordner ist die **einzige Ausnahme** von der Repo-Konvention "keine Shell-Skripte,
die Ressourcen stehen im Kopfkommentar des Treibers" (`docs/HPC_RUNBOOK_MIMO_VERGLEICH.md`).
SLURM verlangt eine Shell-Ebene; der Nutzer hat die Ausnahme fuer genau diesen Ordner
erlaubt.

Deshalb gilt hier: **das Skript waehlt nichts aus und rechnet nichts.** Es setzt die
Ergebniswurzel, startet einen `matlab -batch`-Aufruf und holt die Ergebnisse zurueck.
Jede fachliche Entscheidung bleibt im `.m`-Treiber -- sonst laufen Windows- und
ZIH-Weg auseinander.

```
sbatch hpc/zih/submit_study.sbatch run_analog_bf_distance
```

Vorher einmal: `ws_allocate --filesystem horse gearbox 90`.

**Die Anleitung steht nicht hier, sondern in `docs/HPC_RUNBOOK_ZIH.md`** -- Schritt 0
(Pflicht, eine Stunde interaktiv), Einrichtung, Ressourcen je Studie und die Fallen
(allen voran: `GEARBOXPHY_RESULTS_ROOT` lenkt Lesen *und* Schreiben um).
