# GearboxPHY Framework

A rewrite of the original `Wrapper.m`/`Sim_Init.m`/`get_min_E_bit_*.m` energy-per-bit
optimization pipeline, per `../ARCHITECTURE_PLAN.md`. Plain MATLAB functions and
struct-based dispatch throughout — no `classdef` in the framework itself (test
files use `matlab.unittest` classes, which is a testing-framework requirement,
not a framework design choice).

## Layout

```
+gearboxphy/
├── +physics/   shared hardware-power/path-loss/containment-bandwidth formulas
├── +gears/     one function per gear (QAM/NA-QAM/ZXM/Pulse-Energy/Pulse-Arbitrary),
│               each returning a struct of function handles - see +gears/validateGear.m
│               for the contract every gear must satisfy
├── +optimize/  the multistart fminsearch/fminbnd restart loop + SNR lookup
├── +data/      SE-curve loading, consolidated per-(gear,order,carrier) result store
├── +sweep/     scenario config + the parfor sweep orchestrator (no plotting here)
└── +report/    the plotting/reporting functions
run_sweep.m     top-level entry point
SE_data/        copy of the frozen SE-curve lookup tables (unchanged inputs)
tests/
├── +unit/         matlab.unittest tests for +physics and +gears
└── +goldenmaster/ compares this framework's outputs against the original codebase
```

## Running

```matlab
cd gearboxphy_framework
run_sweep
```

Requires the Signal Processing Toolbox (`obw()`, used by
`+physics/containmentBandwidth[ZXM].m`) and, for `runSweep`'s default
`useParallel=true`, the Parallel Computing Toolbox plus a `'HPCServer'` cluster
profile — both kept as dependencies per this project's architecture decision
(see `ARCHITECTURE_PLAN.md`, "Toolboxes"). Pass `'useParallel', false` to
`runSweep` to run serially without either.

## Testing

```matlab
cd gearboxphy_framework
results = runtests('tests', 'IncludeSubfolders', true);
```

`tests/+goldenmaster/GoldenMasterTest.m` needs the original codebase present at
`/workspace` (unchanged) to compare against, plus the test-only `obw()` stub in
`tests/+goldenmaster/shim/` — this sandbox has no Signal Processing Toolbox
license, so the stub lets the comparison exercise everything *around* `obw()`
(memoization, PSD construction, ZXM eigenvalue math) identically on both sides.
Never add that shim folder to a real run's path.

## What's deliberately different from the original

See `ARCHITECTURE_PLAN.md` sections 2 and 6 for the full rationale; in short:

- No hand-built filenames scattered across the pipeline the way the original
  had them - `+data/resultKey.m` is the one place a result-file name is ever
  constructed. `SE_data/*.mat` filenames are built in exactly two places:
  `+data/seCurveFilename.m` (used by `+data/loadSECurve.m`) for the per-gear
  SE-vs-SNR curves, and `+data/loadPulsePAPR.m` for the separate dk-encoded
  PAPR lookup table (structurally a filtered table, not a 2-column curve, so
  it isn't folded into the same function) - both are named here so neither is
  a hidden exception. This is what the two real case-sensitivity bugs found in
  the original codebase came from.
- Results are consolidated into one file per (gear, order, carrier) rate sweep
  instead of one file per individual point (~16,000 files → ~40).
- Each gear's `prepare()` hoists everything that doesn't depend on the rate
  `R` (not just the optimization variable `x`, which is as far as the
  original's hoisting went) - computed once per (gear, order, carrier)
  instead of once per rate point.
- The redundant duplicate `B>B_max` check is gone; the three per-family
  "sanity check" `fprintf`s are now `warning()`s, checked once in `prepare()`
  rather than on every objective-function evaluation.
- `PAPR_RRC`/`get_QAM_PAPR.m` and the Communications Toolbox dependency it
  pulled in stay out of scope (dead in the original's live pipeline; kept as
  an open TODO, not silently resolved either way — see architecture plan
  section 6, item 1).

## MIMO extension (QAM only)

See `../MIMO_EXTENSION.md` for the full scientific background, references, and
decision record. Summary of what exists in code:

- Only `qamGear.m` has a MIMO variant (`ARCHITECTURE_PLAN.md`/`MIMO_EXTENSION.md`
  decision 2) - every other gear is SISO-only and rejects a non-SISO
  `antennaConfig` with a clear `gearboxphy:mimoNotSupported` error.
- Antenna configuration is a `struct('N_t',N_t,'N_r',N_r)`, SISO = `(1,1)`.
  Configure candidates via `makeScenarioConfig('qamMimoConfigs', {...})` -
  default is SISO-only, so MIMO is opt-in and nothing changes unless you
  configure it.
- `(N_t, N_r)` is **jointly optimized with `(B, gamma)` via nested
  enumeration** (decision 4), not handed to `fminsearch` directly (they're
  integers) and not via a mixed-integer solver (would need the Global
  Optimization Toolbox - a new dependency this project otherwise avoids). For
  each rate point, every candidate's already-`prepare()`-d context is tried
  and the lowest-energy-per-bit candidate wins - see
  `+sweep/optimizeOnePointBestConfig.m`. Winning antenna counts are recorded
  in the result table as `Optimal_N_t`/`Optimal_N_r` (always `1`/`1` for every
  SISO-only gear).
- MIMO `SE_data` curves are frozen, externally-supplied inputs (decision 3),
  named `SE_<M>_QAM_<N_t>x<N_r>.mat`. A curve missing for a particular order
  is **not** a hard error - `+data/filterAvailableAntennaConfigs.m` drops that
  candidate for that order with a visible `gearboxphy:mimoCurveMissing`
  warning (partial MIMO data coverage across orders is expected, not a bug;
  contrast with a corrupted/malformed file, which still errors loudly when
  actually loaded).
- `generate_synthetic_mimo_curve.m` produces `SE_data/SE_16_QAM_2x2.mat`, a
  **synthetic, test-only** curve (SISO curve's spectral efficiency crudely
  doubled) used by `mimo_smoke_test.m` to exercise the whole pipeline
  end-to-end. **Not real MIMO capacity data** - replace before drawing any
  conclusions from an actual sweep.
- `pathLossDb` is unchanged and antenna-count-agnostic (decision 1: `D_r`/`D_t`
  still apply on top of the MIMO curve, which is treated as a pure
  channel-capacity/SNR relationship with no array gain baked in).

### Flagged for your review: `P_PA` is NOT scaled by `N_t`

Every other per-chain hardware term (`P_ADC`, `P_LNA` by `N_r`; `P_DAC`,
`P_Mix` by `N_t`) scales with antenna count - see `qamGear.m`'s
`computeCore` for the full reasoning, but in short: `P_PA` here is
`c_PA*P_t*sqrt_fc*papr`, **linear in `P_t`** (the *total* required transmit
power from the link budget). Under a strictly linear PA model with no
fixed/idle power term, splitting the same total `P_t` across `N_t`
proportionally-smaller PAs consumes the same total DC power as one PA
handling all of it - so multiplying by `N_t` would double-count under this
codebase's existing formula. A more detailed PA model with a genuine
per-PA fixed/idle power component (real Class-AB PAs have one) would change
this conclusion, but that's new physics beyond what
`e_bit_fct_QAM_v2.m` ever modeled - not introduced here without your
confirmation. Same treatment as the `PAPR_RRC`/`0.7`-LO items in
`ARCHITECTURE_PLAN.md` section 6: implemented with the defensible default,
explicitly flagged rather than silently decided either way.
