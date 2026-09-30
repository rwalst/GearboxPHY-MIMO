# HPC Runbook: LNA power models in the Gearbox

Compares three LNA power models across the whole Gearbox (all gears, the
three carriers 2.4 / 8 / 28 GHz, two bandwidth settings, SISO and
beamforming). Background and the survey fit: `../LNA_POWER_MODEL.md`.

**None of these files has been executed yet.** Step 0 is mandatory. It
checks within minutes everything that can be checked without the expensive
sweep, and stops with an error if anything is off.

## What is compared

| LNA model (`lnaPowerModel`) | P per LNA | Source |
|---|---|---|
| `fom_bandwidth` (default) | G·B·N₀/((F−1)·FoM), FoM = 1e-7 | dissertation eq. (4.5), Mezghani & Nossek |
| `fom_floor` | same formula with B → max(B, 0.05·f_c) | dissertation + technology floor |
| `envelope` | 0.776 mW·(f_c/GHz)^0.28·(B_eff/GHz)^0.46, B_eff = max(B, 0.05·f_c) | 5 % envelope of the Belostotski LNA survey |

| Bandwidth setting | B_max at 2.4 / 8 / 28 GHz |
|---|---|
| `eta01` | 240 MHz / 800 MHz / 2.8 GHz (η = 0.1, dissertation) |
| `narrow` | 20 MHz / 100 MHz / 400 MHz |

With `narrow`, B_max is below the floor 0.05·f_c at all three carriers.
`fom_floor` and `envelope` then become one constant per carrier, and only
their level differs (`LNA_POWER_MODEL.md`).

| Study | Distances | Antennas |
|---|---|---|
| `siso` | 50 m | 1×1 |
| `beamforming` | 50 m, 5 km | N×N, N ∈ {1, 2, 4, 8, 16, 32, 64}, ideal gain N_t·N_r, **every** gear may pick an array |

Beamforming is where the per-element LNA power matters: each extra receive
antenna costs one LNA.

This gives 6 SISO and 12 beamforming cases. Each case covers all gears ×
3 carriers × 100 rates.

## What changed in the framework

- `makeScenarioConfig`: new options `lnaPowerModel` (default
  `"fom_bandwidth"`), `lnaBetaMin` (0.05) and `B_maxByCarrier` (rows
  `[f_c B_max]`, empty = η·f_c).
- `resolveScenarioForCarrier`: applies `B_maxByCarrier` as η = B_max/f_c. B_max,
  the NA-QAM bandwidth and every initial guess are derived from η·f_c, so this
  one line reaches all of them. A carrier without a row is an error.
- `+physics/lnaPowerFor.m` (dispatcher) and `lnaParams.m`. The four gears call
  it at the single place where they used to call `lnaPower`.
- **Default = previous behaviour, bit for bit.** Step 0 checks this (L2).

## Order

### Step 0: validation (minutes, no pool)

```matlab
cd /workspace/Gearbox-PHY-SpatialMultiplexing/gearboxphy_framework
validate_lna_comparison
```

The script ends with "All checks passed" or with an error. **Do not
continue if a check fails.**

| Check | What it checks |
|---|---|
| **L1** | Unit tests `tests/+unit/LnaModelTest.m` |
| **L2** | Default model reproduces stored SISO results bit for bit (QAM, NA-QAM, ZXM, Pulse-Energy) |
| **L3** | Per point, all carriers, both bandwidth settings: B_opt ≤ B_max, the LNA budget term equals the model, E_bit ordered envelope ≥ floor ≥ dissertation |
| **L4** | Mini run through the real driver helpers plus the analysis in a temp folder; a foreign results folder is refused |

Requirements are the same as for any sweep: Signal Processing Toolbox
(`obw`), and `SE_data/`.

### Step 1: sweep

```matlab
run_lna_comparison
```

Resources (header of the file): nodes=1, ntasks=1, cpus-per-task=100,
mem=64G, time=12:00:00.

- SISO first. If you want a quick first pass, set
  `STUDIES = "siso"` at the top of the file, then run again with both.
- The run can be interrupted: finished combos are skipped and point
  checkpoints are reused.
- Every results folder `results_lna/<study>_<bw>_<model>_d<d>/` carries a
  `lna_stamp.mat`. A folder belonging to a different case is refused, never
  overwritten. This is needed because runSweep's own skip check does not
  know the LNA model.

### Step 2: analysis (local or on the HPC, no pool)

```matlab
out = analyze_lna_comparison();                 % rates 1e4, 1e6, 1e8, 1e9 in the table
out = analyze_lna_comparison(rateTable=[1e5 1e7]);
```

Output goes to `results_lna/figures/`, one set per study and distance. Tiles:
bandwidth setting (rows) × carrier (columns).

| File | Content |
|---|---|
| `lna_ebit_*` | E_bit of the best gear (without the NA-QAM baseline), one line per LNA model |
| `lna_ratio_*` | E_bit / E_bit(dissertation model): how much each model costs |
| `lna_share_*` | LNA share of E_bit at the optimum |
| `lna_gear_*` | optimal gear per rate; the lines are offset slightly per model so identical choices stay visible |
| `lna_nopt_*` | optimal array size N (beamforming only) |
| `summary.csv` / `summary.mat` | one row per case × carrier × table rate: E_bit, ratio, gear, B, N, LNA share |

## Reading the results

- **Main question:** does the LNA model change the gear choices or the array
  sizes (`lna_gear_*`, `lna_nopt_*`)? Or does it only shift E_bit
  (`lna_ratio_*`)?
- If `fom_floor` and `envelope` agree on the choices, the level of the LNA
  power does not matter for the Gearbox's decisions. If they differ, the
  level matters and should be reported as a sensitivity.
- Expected: the effect is largest at low rates, where the floor is active
  and LO/mixer do not yet dominate everything. It is also largest in
  beamforming, where N_r·P_LNA grows with the array.
