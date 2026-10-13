# Alte gegen neue Hardwaremodelle in der SISO-Gearbox

Vergleicht die SISO-Gearbox mit den Bauteilmodellen der Dissertation
(`hardwareModel="old"`) und mit den Survey-Modellen (`hardwareModel="new"`),
siehe `docs/HARDWARE_MODEL_SWITCH.md`. Hauptergebnisse: der gewählte Gang
über der Rate und das Leistungsbudget des gewählten Gangs.

| Variante | LNA | ADC | DAC |
|---|---|---|---|
| `old` | `fom_bandwidth` | `envelope` (0,67 fJ) | `analytic` (3 V) |
| `new` | `envelope` | `quantile5` (3,17 fJ) | `survey` |
| `lna_only`, `adc_only`, `dac_only` | je EIN Modell neu, Rest alt | | |

PA, Mischer und LO sind in allen Varianten gleich. SISO hat einen Mischer je
Seite, die LO-Verteilung (`loDistributionModel`) geht also nicht ein.

Raster (`hw_comparison_config.m`): SISO, d = 50 m, Träger 2,4 / 8 / 28 GHz,
100 Raten von 1 kbit/s bis 100 Gbit/s, alle Gänge.

## Dateien

| Datei | Zweck |
|---|---|
| `hw_comparison_config.m` | Varianten, Raster, Ergebnisort |
| `hw_comparison_case.m` | Szenario, Ordner und Stempel EINES Falls |
| `hw_comparison_prepare_dir.m` | legt den Ordner an und bindet ihn per `hw_stamp.mat` an den Fall |
| `run_hw_comparison.m` | Treiber für den HPC |
| `analyze_hw_comparison.m` | Abbildungen und Tabelle |
| `test_hw_comparison.m` | Mini-Lauf der ganzen Kette in einem Temp-Ordner (Minuten, ohne Pool) |

## Ablauf

```matlab
addpath('<repo>'); setupGearboxPath;
test_hw_comparison       % optional, prueft die Kette
run_hw_comparison        % HPC: nodes=1, cpus-per-task=100, mem=64G, time=04:00:00 (Schaetzung)
analyze_hw_comparison
```

Standard sind die Varianten `old` und `new`. Fuer die Zuordnung, welches
Modell das Ergebnis bewegt, vor dem Aufruf setzen:

```matlab
VARIANTS = ["old" "new" "lna_only" "adc_only" "dac_only"];
run_hw_comparison
```

Der Lauf ist wiederaufnehmbar; ein Ordner mit fremdem Stempel wird nie
ueberschrieben, sondern fuehrt zu einem Fehler.

## Ergebnisse

`results/hardware_models/siso_<variante>_d50/` je Fall, Abbildungen in
`results/hardware_models/figures/`:

| Datei | Inhalt |
|---|---|
| `hw_gear_d50.png` | gewaehlter Gang ueber der Rate, eine Linie je Variante, eine Spalte je Traeger |
| `hw_budget_d50.png` | Leistungsbudget des gewaehlten Gangs (Anteile an E_bit: PA, DAC, LO, Mischer, LNA, ADC, Energiedetektor), eine Zeile je Variante; weisse Linien = Gangwechsel |
| `hw_ebit_d50.png` | E_bit des gewaehlten Gangs und Verhaeltnis zur Variante `old` |
| `summary.csv` / `.mat` | Gang, E_bit, Verhaeltnis und Budgetanteile bei 1e4, 1e6, 1e8, 1e9, 1e10 bit/s |

Der gewaehlte Gang ist das Minimum ueber alle Gaenge und Ordnungen ohne die
NA-QAM-Referenz, wie in `plotOptimalGearReport`.

## Stand

2026-10-13: Treiber und Auswertung geschrieben, Kette mit `test_hw_comparison`
geprueft. Der HPC-Lauf steht aus.

Nicht enthalten: die geplante ADC-Regel b = log2(sqrt(M)) + 3 fuer QAM, eine
zweite Distanz, Beamforming/MIMO.
