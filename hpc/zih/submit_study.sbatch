#!/bin/bash
# Eine Gearbox-Studie als SLURM-Job auf dem ZIH-Cluster (TU Dresden).
#
#   sbatch hpc/zih/submit_study.sbatch run_analog_bf_distance
#
# Bewusst logikfrei: das Skript waehlt nichts aus und rechnet nichts. Es legt
# die Ergebniswurzel fest, startet EINEN matlab -batch-Aufruf und holt die
# Ergebnisse zurueck. Alles Fachliche steht im Treiber selbst -- so bleibt
# der Windows-Weg (dort wird der Treiber direkt aufgerufen) der gleiche Code.
#
# cpus-per-task = Worker + 1: ein Kern fuer den Client, der waehrend des
# parfor zwar wenig tut, aber eben nicht nichts. Die Workerzahl selbst deckelt
# +gearboxphy/+sweep/workerBudget.m an SLURM_CPUS_PER_TASK, es gibt also
# keinen zweiten Ort, an dem sie verstellt werden muss.
#
# Die Zahlen unten passen zu den Distanz-Studien (25 Distanzen). Fuer
# run_mimo_comparison_sweep sind es 100 Ratenpunkte -- dann
# --cpus-per-task=101 und, weil 101 > 104 nicht mehr weit weg ist, eher
# --partition=romeo mit 128 Kernen; Romeo hat allerdings nur 1972 MB je Kern
# gegen 2403 MB auf Barnard, also vorher MaxRSS aus einem kleinen Lauf kennen.
#
#SBATCH --job-name=gearbox
#SBATCH --partition=barnard
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=26
#SBATCH --mem-per-cpu=2000M
#SBATCH --time=12:00:00
#SBATCH --output=gearbox-%x-%j.out

set -euo pipefail

STUDY="${1:?Aufruf: sbatch hpc/zih/submit_study.sbatch <Treibername>}"
WS_NAME="${GEARBOX_WS:-gearbox}"

# Der Code liegt im Home (versioniert, per git aktuell gehalten), die
# Ergebnisse NICHT: das Home ist fuer Job-Ausgaben nicht gedacht.
REPO="${SLURM_SUBMIT_DIR:-$PWD}"
WS="$(ws_find "$WS_NAME")"
export GEARBOXPHY_RESULTS_ROOT="$WS/results"
mkdir -p "$GEARBOXPHY_RESULTS_ROOT"

# resultsDir lenkt LESEN UND SCHREIBEN um. Ohne diesen Hinschritt sieht der
# Lauf die schon gerechneten Ergebnisse nicht und rechnet sie neu -- oder
# ueberspringt nichts, obwohl SKIP_EXISTING an ist. -u: nur Neueres, damit ein
# zweiter Job die Ergebnisse des ersten nicht mit aelteren Repo-Dateien
# ueberschreibt.
rsync -au "$REPO/results/" "$GEARBOXPHY_RESULTS_ROOT/"

module purge
module load MATLAB

cd "$REPO"
matlab -nodisplay -batch "setupGearboxPath; $STUDY"

# Zurueck ins Repo: die Ergebnisdateien sind klein und versioniert, und der
# Workspace laeuft nach seiner Frist ab (ws_extend verlaengert, ws_list zeigt
# den Rest). Was nur im Workspace liegt, ist irgendwann weg.
rsync -au "$GEARBOXPHY_RESULTS_ROOT/" "$REPO/results/"

echo "Fertig. Ergebnisse in $REPO/results -- git add/commit nicht vergessen."
