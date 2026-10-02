# GearboxPHY Framework — Rewrite Architecture Plan

**Status:** draft for review — nothing in this plan has been implemented yet.
**Scope decisions locked in with you before writing this:**

| Axis | Decision |
|---|---|
| Platform | Modernized MATLAB (packages, plain functions + struct-based dispatch, `matlab.unittest`) — not a Python port, not `classdef`-based (see §4) |
| Numerical fidelity | Open to revisiting questionable formulas, not required to match bit-for-bit |
| Toolboxes | Keep both optional toolbox dependencies as-is (Signal Processing Toolbox for `obw()`, Parallel Computing Toolbox + the `'HPCServer'` cluster profile) |
| Scope | Engine + orchestration only. `SE_data/*.mat` lookup tables are frozen, opaque inputs — the offline curve-generation process is out of scope |

---

## 1. What the current system actually is

Worth stating plainly, so you can correct my understanding before I plan around it.

This is a **dissertation research tool** that answers one question for a grid of (data rate `R`, carrier frequency `f_c`): *for each of ~10 PHY-layer "gears" (modulation/coding schemes), what transmit bandwidth `B` and duty cycle `gamma` minimize energy-per-bit, and how much energy does that cost?* The gears compared are:

- **QAM** — adaptive bandwidth, 5 orders (4/16/64/256/1024)
- **NA-QAM** — non-adaptive QAM, bandwidth fixed at `eta·f_c`, only `gamma` optimized
- **ZXM** — a `(d,k)`-run-length-limited line code (Neuhaus et al.), 3 orders (`M_tx`=1/2/3)
- **Pulse/impulse-radio** — Energy-detection and Arbitrary-sign variants

For each gear/order/rate/carrier combination, a **hardware power model** (PA, DAC, ADC, LNA, local oscillator, mixer — each with published-literature or dissertation-derived constants) is combined with a **required-SNR lookup** (a precomputed spectral-efficiency-vs-SNR curve per gear, loaded from `SE_data/*.mat`) to build an energy-per-bit objective function, which `fminsearch`/`fminbnd` then minimizes over `(B, gamma)`.

**Data flow today:**

```
Wrapper.m (hardcoded hyperparameters, R_vec × f_c_vec × gear list)
   │
   ├─ parpool('HPCServer', ...)
   │
   └─ parfor r → Sim_Init(R, modulation, params)
                    │
                    ├─ if/elseif on modulation.family  (repeated 2x more in Wrapper.m itself)
                    ├─ load SE_data/*.mat (per-gear filename built by hand with strcat)
                    ├─ get_p_containment_bw[_ZXM] (obw() on a closed-form RRC/ZXM PSD, memoized)
                    ├─ get_min_E_bit_<Gear>(R, order, params)
                    │     ├─ precompute loop-invariant terms → params.inv_*
                    │     └─ run_multistart_fminsearch(objective, x0, params[, bounds])
                    │            └─ e_bit_fct_<Gear>(x, params, ...) × (numtriesPerOpt × maxiters)
                    └─ save one .mat file per (gear, order, f_c, R, distance)
   │
   └─ (after all parfor loops) Wrapper.m re-loads every saved .mat file,
      aggregates into matrices, plots 4 families of figures + a power-budget
      stacked-area chart for one specific (M=1024-QAM, 28GHz) slice.
```

`PlotSECurves.m` is a separate, standalone sanity-check script (not part of the pipeline). `get_params.m` is confirmed-dead legacy code (zero callers). `fct_genMaxEntropicRllSeq.m` is an orphaned data-generation script — not called by anything in the live pipeline — presumably used once, offline, to help produce the ZXM `SE_data` curves; `fct_maxEntropic_dk_properties.m` *is* live (called from `get_p_containment_bw_ZXM.m`).

**Toolbox footprint of the live pipeline** (confirmed by grep, not assumption):

| Toolbox | Used by | Status |
|---|---|---|
| Parallel Computing (+ `'HPCServer'` profile) | `Wrapper.m` | live, kept per your decision |
| Signal Processing (`obw`) | `get_p_containment_bw.m`, `get_p_containment_bw_ZXM.m` | live, kept per your decision |
| Communications (`qammod`) | `get_QAM_PAPR.m` | **dead** — only reachable from already-dead `get_params.m` |
| Statistics & ML (`hmmgenerate`) | `fct_genMaxEntropicRllSeq.m` | **dead** — orphaned, out of scope |
| Optimization Toolbox | — | **not used** — `fminsearch`/`fminbnd` are core MATLAB |

**If anything above is wrong, tell me now** — it's the foundation the rest of this plan stands on.

---

## 2. Why rewrite: the architectural weaknesses driving this

These aren't hypothetical — every one of them either caused a real bug found this session, or is the mechanism by which such a bug becomes likely:

1. **Filename construction is hand-rolled, per-family, in three separate places** (`Sim_Init.m`'s dispatch, and twice more in `Wrapper.m` — once to run, once to reload for plotting), each rebuilding the same `strcat(...)` string independently. This is exactly how two real, silent, case-sensitivity bugs slipped in this session (`dkEnergyRx` vs `dkEnergyRX` in `Wrapper.m`; `MUI_ZXM_MTX` vs `MUI_ZXM_Mtx` in `Sim_Init.m`) — both invisible on macOS/Windows dev machines, both fatal on the case-sensitive Linux HPC cluster this targets.
2. **Adding a gear means touching ~4 files in lockstep**: a new `if/elseif` branch in `Sim_Init.m`'s dispatch, a new `get_min_E_bit_<Gear>.m`, a new `e_bit_fct_<Gear>.m`, and two more hand-copied branches in `Wrapper.m` (run + reload). The commented-out `"dk"` family fragment still sitting in `Wrapper.m` is a fossil of exactly this friction.
3. **The hardware power formulas (`P_PA`, `P_ADC`, `P_LNA`, `P_DAC`) are copy-pasted across all four `e_bit_fct_*.m` files**, with small per-gear variations. This is the class of bug that produced the "P_LNA computed twice, first result silently overwritten" dead code fixed earlier this session — copy-paste drift is a when-not-if risk here.
4. **One mutable `params` struct carries two unrelated kinds of data**: long-lived scenario configuration (`eta`, `alpha`, `N_0`, `distance`, ...) and short-lived, per-optimization-call scratch values (`params.inv_B_max`, `params.inv_PAPR`, ...) set fresh by each `get_min_E_bit_*.m` right before use. It works today because every call site is careful, but nothing in the language enforces that — it's a latent trap for the next person (or the next gear) that reuses a `params` struct across calls without re-deriving every `inv_*` field.
5. **Results are cached as ~16,000 individual `.mat` files** (400 rates × 4 carriers × ~10 gear/order combos) named by hand-built strings, checked for existence with `exist(...)` before every one of thousands of `Sim_Init` calls. This is what made the two filename bugs *silent* — a missing/mismatched file isn't a crash, it's a skipped `if ~exist(...)` branch that quietly leaves a gap, discovered only much later when `Wrapper.m` tries to reload it.
6. **Orchestration, caching, and plotting are one 480-line script** (`Wrapper.m`) with no internal boundaries — which is why the power-budget preallocation bug (misaligned `Power(r)` entries from MATLAB's struct-array empty-backfill) lived undetected in the plotting section.

None of this is about the *physics* being wrong — the formulas are the dissertation's actual scientific contribution. It's the *scaffolding* around them (dispatch, naming, caching, orchestration) that's fragile, and that's what this rewrite targets.

---

## 3. Goals / Non-goals

**Goals**
- A gear is a self-contained unit that can be added, tested, and validated in isolation, without touching orchestration code.
- One shared hardware-power-model implementation, not four copies.
- One shared, tested filename/key-generation function — never hand-built inline again.
- A results store that fails loudly (missing/corrupt data raises an error) instead of silently skipping.
- Orchestration (sweep execution + caching), analysis (loading/aggregating), and reporting (plotting) are separable, independently testable units.
- A `matlab.unittest`-based regression suite, including golden-master comparisons against the current dissertation's saved `.mat` results, so every future change to a formula is a deliberate, visible diff — not an accident.

**Non-goals** (per your scope decision)
- Not regenerating or redesigning how `SE_data/*.mat` curves themselves are produced.
- Not removing the Signal Processing / Parallel Computing Toolbox dependencies.
- Not porting to another language.
- Not guaranteed bit-for-bit output parity — see §6 for the specific formulas flagged as open scientific questions rather than silently preserved or silently "fixed."

---

## 4. Proposed package layout

No `classdef` anywhere in this design (see the "why" at the end of §4.1) — every box below is a plain `.m` function file. A single MATLAB package namespace, using the dissertation's own name for the concept (`SE4gearboxPHY` appears in the data filenames), works the same way for plain functions as it would for classes — packages are just a folder-organization/namespacing mechanism:

```
+gearboxphy/
├── +physics/
│   ├── powerAmplifier.m           PA power, ONE copy (was duplicated 4x in e_bit_fct_*.m)
│   ├── adcPower.m
│   ├── dacPower.m
│   ├── lnaPower.m
│   ├── pathLoss.m                 free-space path-loss + antenna gain (the `L` term)
│   └── containmentBandwidth.m     obw()-based RRC / ZXM bandwidth (ports get_p_containment_bw*)
│
├── +gears/                         one file per gear, each returning a struct of function handles
│   ├── qamGear.m
│   ├── naQamGear.m
│   ├── zxmGear.m
│   ├── pulseGear.m
│   ├── gearRegistry.m             {qamGear(), naQamGear(), zxmGear(), pulseGear()} — add a
│   │                              gear by adding one file + one line here, nothing else
│   └── validateGear.m             checks a gear struct has every required field populated
│                                   (run at registry build time AND in tests — see §4.1)
│
├── +optimize/
│   └── multistartOptimize.m       ports run_multistart_fminsearch.m unchanged (fminsearch/
│                                  fminbnd choice driven by whether the gear declared bounds)
│
├── +data/
│   ├── loadSECurve.m              wraps SE_data/*.mat access — ONE place that knows the
│   │                              on-disk filenames/fields, replacing hand-rolled strcat calls
│   │                              in Sim_Init.m and PlotSECurves.m
│   └── resultStore.m              see §5.2 — replaces the ~16,000-file .mat-per-point cache;
│                                  a function using `persistent` for in-memory caching, same
│                                  pattern already used by load_mat_cached.m today
│
├── +sweep/
│   ├── makeScenarioConfig.m       replaces Wrapper.m's ~60 lines of hardcoded params —
│   │                              one validated struct (via an `arguments` block), built by
│   │                              a script OR a file, not a class
│   └── runSweep.m                 replaces Wrapper.m's parfor orchestration only —
│                                  no plotting code in this file
│
├── +report/
│   ├── plotEnergyReport.m         the 4-subplot per-carrier figure
│   ├── plotSavingsReport.m        the "best gear vs NA-QAM" savings curve
│   ├── plotOptimalGearReport.m    the argmin-gear-per-rate plot
│   └── plotPowerBudgetReport.m    the stacked-area power breakdown
│
├── run_sweep.m                    thin top-level script: build config → runSweep → reports
└── tests/
    ├── +unit/                     one test file per function/group above
    └── +goldenmaster/             see §7 — compares against frozen current-code outputs
```

### 4.1 The gear "interface" — a struct of function handles, not a class

```matlab
function gear = qamGear()
gear.name             = "QAM";
gear.initialGuess     = @(order, scenario) [log10(0.99*scenario.eta*scenario.f_c), 1];
gear.optimizerBounds  = @(order, scenario) [];              % [] = unconstrained/2-D (fminsearch)
gear.energyPerBit     = @(x, order, scenario, R) e_bit_fct_QAM_v2(x, scenario, order, R, scenario.f_c, "minimization");
gear.powerBudget      = @(x, order, scenario, R) e_bit_fct_QAM_v2(x, scenario, order, R, scenario.f_c, "budget");
gear.loadSECurve      = @(order) gearboxphy.data.loadSECurve("QAM", order);
end
```

`gearRegistry.m` returns `{qamGear(), naQamGear(), zxmGear(), pulseGear()}` — a plain cell array. `runSweep` and the report functions loop over it with a `for`, calling `gear.energyPerBit(...)` etc. — no `if modulation.family == "..."` chain anywhere, and no inheritance. Adding a gear (the commented-out `"dk"` family in `Wrapper.m` is evidence this has already been wanted once) means: one new `+gears/xGear.m` returning a struct with the same fields, one line in `gearRegistry.m`. Orchestration, caching, and plotting code do not change.

**Why not `classdef` here:** the only thing an abstract class buys over this is a load-time error if a gear forgets a required method, versus a runtime "field not found" if a struct-of-handles is missing one. `validateGear.m` recovers nearly all of that cheaply — one function, called once when the registry is built and again from a unit test, that asserts every expected field name is present and is a function handle. That's enough enforcement for four (soon maybe five or six) gears, without asking future maintainers — likely other MATLAB-using researchers extending this dissertation, not software engineers — to learn a class hierarchy for a codebase that's otherwise 100% procedural today.

### 4.2 Hardware power model, shared once

```matlab
function P = powerAmplifier(P_t, sqrt_fc, papr, c_PA)
P = c_PA * P_t * sqrt_fc * papr;
end

function P = adcPower(B, pow2_b, f_b, c_ADC)
P = 2 * c_ADC * pow2_b * B * sqrt(1 + (B/f_b)^2);
end
% dacPower.m, lnaPower.m follow the same shape
```

Each gear's `energyPerBit`/`powerBudget` function calls these with its own bit-width/PAPR/multiplicity (e.g. ZXM's `M_tx*2×` factor is just an extra multiply at the call site, not a fork of the formula). `LO`/`Mixer` power stays inline in each gear where the physics genuinely differs (Pulse's `×0.7 "single-ended"` term, ZXM/QAM's shared `P_LO`+`P_Mix`), but the generic pieces are called through these shared functions so a future correction happens once, not four times.

---

## 5. Key design decisions needing your sign-off

### 5.1 `makeScenarioConfig` replaces the hardcoded param block

`Wrapper.m`'s ~60 lines of bare assignment (`params.eta=0.1; params.alpha=0.5; ...`) become one validated struct, built by a plain function using MATLAB's `arguments` block for validation (no class needed for that — `arguments` blocks work in ordinary functions):

```matlab
function scenario = makeScenarioConfig(opts)
arguments
    opts.eta (1,1) double = 0.1
    opts.alpha (1,1) double {mustBeInRange(opts.alpha,0,1)} = 0.5
    opts.distance (1,1) double {mustBePositive} = 50
    opts.RVec (1,:) double = logspace(3,11,400)
    opts.fcVec (1,:) double = [2.4 8 28 60]*1e9
end
scenario = opts;   % struct, not an object
end
```

```matlab
scenario = gearboxphy.sweep.makeScenarioConfig('eta', 0.1, 'distance', 50);
```

This also separates the *scenario* (physical assumptions) from the *optimizer knobs* (`numtriesPerOpt`, `maxiters`, `tolerance`) and from *per-call derived quantities* (today's `params.inv_*`) — the third of which becomes a value returned fresh by each gear's functions, never stored back onto a shared mutable struct (closing the trap described in §2.4).

### 5.2 Results store: keep per-point `.mat` files, or consolidate?

**I'd recommend consolidating**, but this is a real trade-off, not an obvious call:

| | Current (per-point `.mat`) | Proposed: one table per (gear, f_c) |
|---|---|---|
| File count | ~16,000 tiny files | ~40 files (10 gears × 4 carriers) |
| Resumability (skip already-computed points) | Native — `exist()` per point | Needs a per-row "computed" flag in the table |
| Failure mode on bad filename | **Silent** (the bug class found twice this session) | Structural — the key is a column, not a filename, generated by one shared function |
| Inspection | `ls`/manual `load` of one point | `readtable`/one `load` gets the whole gear/carrier sweep |

Concretely: `resultStore.m` would hold one `table` (or `containers.Map`) per `(gear, f_c)`, keyed by `R`, saved/loaded as a single `.mat` via a `persistent` cache (same pattern as today's `load_mat_cached.m` — no object/state-holding class needed), with a shared, tested key-generation function replacing every hand-rolled `strcat`. This directly eliminates the bug class in §2.1/§2.5. **If you'd rather keep the existing per-point file layout** (e.g. because external tooling already depends on those exact filenames), that's a smaller, lower-risk version of this plan — say so and I'll adjust §4/§5.2 accordingly.

### 5.3 `runSweep` vs. `Wrapper.m`'s current parfor structure

`runSweep` iterates the cell array from `gearRegistry()` and, per gear, does the same `parfor r = 1:length(RVec)` your current code does — same parallelization granularity, same `parpool('HPCServer', ...)`, kept per your toolbox decision. The difference is purely that the loop body calls a shared key-generation function / `resultStore` instead of hand-built strings, and there's no plotting code interleaved.

---

## 6. Formulas/behaviors flagged as open questions — now decided

You said the rewrite doesn't need bit-for-bit parity and can revisit questionable formulas — here's the concrete list surfaced while reading the code, with your decisions on each:

1. **`PAPR_RRC`/`get_QAM_PAPR.m` is fully unwired.** It computes a more accurate, RRC-shaped PAPR, but nothing downstream ever reads it — `e_bit_fct_QAM_v2.m`'s actual `P_PA` term uses a simpler closed-form `PAPR_QAM_Linear` derived directly from `M`.
   **Decision: keep current behavior, flag as TODO.** The simpler formula stays exactly as-is in the port; `get_QAM_PAPR.m` stays out of the live path (Communications Toolbox/`qammod` does *not* re-enter scope). Leave a clearly marked comment/doc note that whether `PAPR_RRC` should feed `P_PA` is an unresolved dissertation-scientific question, for you to check against your notes later — not something the rewrite silently resolves either way.
2. **The redundant double `if(B>B_max)` check** in `e_bit_fct_QAM_v2.m`/`e_bit_fct_ZXM.m`/`e_bit_fct_Pulse.m` (once inside the combined `gamma<0||...` check, once again immediately after).
   **Decision: remove the redundant second check.** Pure dead-code cleanup, zero behavior change — the combined check already covers it.
3. **Pulse's `P_LO = params.P_LO*0.7 % single ended!` heuristic** — an explicit, flagged approximation in the original comments.
   **Decision: keep the 0.7 factor unchanged, flag as TODO.** Carried forward as-is in the port, with an explicit "unverified — needs re-derivation or citation" marker in the new code rather than a bare magic number, so it isn't mistaken for settled physics.
4. **The diagnostic sanity checks in `SNR_value_QAM/_ZXM/_Pulse.m`** (`max(SE_vec)>log2(M)`, `max(SE_vec>4)`, `max(SE_vec>2)`) are `fprintf`-only — easy to miss entirely under `parfor` (worker output isn't always surfaced).
   **Decision: upgrade to `warning()`/`assert()`.** A violated sanity bound becomes an actually-visible warning/error in the rewrite instead of a silently-missed print statement.
5. **`Sim_Init.m`'s 28 GHz `P_LO` (26.9 mW) vs. the now-dead `get_params.m`'s 28 GHz `P_LO` (10.8 mW)** — two different literature values for the same quantity in two files.
   **Decision: `Sim_Init.m`'s value (26.9 mW) is correct.** Confirmed as the intended value; no further action beyond dropping `get_params.m` as already planned.
6. **Pulse's `modulation.order` is hardcoded to `1`** everywhere it's constructed — the field exists (mirroring ZXM's `M_tx`) but the sweep never varies it.
   **Decision: keep fixed at 1.** Only `M_tx=1` has ever been exercised/validated for Pulse schemes — `pulseGear.m` keeps this a constant rather than adding unvalidated generality.

---

## 7. Testing & migration strategy

Because fidelity is "open to revisiting," the test suite has two tiers:

1. **Golden-master regression** (`tests/+goldenmaster/`): for every formula *not* flagged in §6, run the same sample points through old and new code (the same technique used to validate this session's hoisting changes — see the `run_compare.m` harness already built and proven this session) and assert near-equality. This is the safety net for the ~95% of the codebase that's just being restructured, not changed.
2. **Unit tests** (`tests/+unit/`): `matlab.unittest` works the same for testing plain functions as it does for classes — one test file per function/group: `+physics` power formulas, each gear (via `validateGear.m` plus its own energy/budget values at known points), `multistartOptimize`, `resultStore`, `loadSECurve` — covering both nominal points and the boundary/infeasibility behavior (`gamma` outside `[0,1]`, `B > B_max`, `P_t > Maximum_P_T`) that today only exists as inline `if` checks with no test coverage at all.

**Phased rollout** (each phase individually mergeable/verifiable, not a big-bang cutover):

| Phase | Deliverable | Validated by |
|---|---|---|
| 0 | `makeScenarioConfig`, `+physics/*`, `loadSECurve`, `resultStore` skeletons + unit tests | unit tests only, no gear logic yet |
| 1 | Gear function-struct shape (`validateGear.m`) + `qamGear` (best-understood family) | golden-master vs. current `get_min_E_bit_QAM`/`e_bit_fct_QAM_v2` |
| 2 | `naQamGear` | golden-master vs. current NA-QAM (already has the `fminbnd` swap from this session as a precedent) |
| 3 | `zxmGear`, `pulseGear` | golden-master vs. current outputs |
| 4 | `runSweep` (orchestration only) | re-run a small sweep, diff `resultStore` contents against today's `.mat` files |
| 5 | `+report/*` (plotting) | visual diff against current `Wrapper.m` figures |
| 6 | Cutover: `run_sweep.m` becomes the entry point, old files archived (not deleted, per this session's established practice of never deleting without git history to fall back on) |

---

## 8. Open questions for you before implementation starts

- **§5.2**: consolidate results into per-(gear, carrier) tables, or keep the current one-file-per-point layout (lower risk, smaller diff, keeps the existing bug class's *shape* even if each instance gets fixed)?
- Should the package namespace be `+gearboxphy` (from the `SE4gearboxPHY` data filenames), or do you have a preferred project name?
- Any existing external tooling/collaborators that read today's `.mat` output filenames directly? (Affects how much §5.2 can change without a compatibility shim.)
- Should German-language comments found throughout (`%Berechnung`, `%ACHTUNG, STARK HEURISTISCH`, `%doppelt hält besser`) be translated during the port, or preserved as-is?
