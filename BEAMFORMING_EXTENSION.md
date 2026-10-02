# Beamforming extension

Second use for multiple antennas, alongside the spatial multiplexing of
`MIMO_EXTENSION.md`. Selected by `scenario.antennaMode`, which defaults to
`"multiplexing"` — every existing result and script is untouched.

| | `"multiplexing"` (default) | `"beamforming"` |
|---|---|---|
| SE curve | own MIMO curve per `(order, N_t, N_r)` | **the SISO curve, always** |
| Path loss | unaware of antenna count | `L_dB − 10·log10(N_t·N_r)` |
| Hardware power | per chain: `N_r` Rx, `N_t` Tx | **identical** |
| Gears | QAM only | QAM **and** ZXM |
| New data needed | yes, one `.mat` per config | **none** |

## The three modelling decisions

**1. Mutual information stays SISO.** The array carries one stream, so the
spectral-efficiency curve is unchanged. This is why beamforming needs no new
`SE_data` and why any `(N_t, N_r)` is admissible — 32×32 and 64×64 included,
which spatial multiplexing could never offer without 32 or 64 stream curves.

**2. The array buys path loss, ideally.** Gain `N_t·N_r`, i.e. perfectly
aligned beams with no array or taper loss. This is deliberately the limiting
case: an **upper bound** on what beamforming can deliver. A real array with
pointing error, sidelobes and taper loss lands below it.

**3. Hardware cost is unchanged.** Per-chain scaling exactly as in the
multiplexing case — ADC/LNA/Rx-mixer with `N_r`, DAC/Tx-mixer with `N_t`, LO
shared, PA per `paPowerModel`. This is what makes the comparison meaningful:
the two modes differ *only* in what the antennas are used for.

## The consequence worth knowing before you read any result

The gain acts on the **PA term alone**, and the PA is often a negligible part
of the energy. Measured at 28 GHz, `d = 50 m`, `R = 1e5`:

| term | 1×1 | 8×8 |
|---|---|---|
| PA | **0.2 %** | 0.0 % |
| LO_Rx | 74.2 % | 27.9 % |
| Mix_Rx | 23.2 % | 69.7 % |

Beamforming reduces 0.2 % of the energy while multiplying the Rx chain count
by 8. It cannot win. At `d = 50 m` the optimizer therefore picks `N_t = 1`
almost everywhere — **the correct answer for this model, not a bug.**

Distance is the knob that decides it, because path loss grows with distance
and the PA term grows with it (winning `N_t` at 28 GHz, 16-QAM):

| | R = 1e5 | R = 1e7 | R = 1e9 |
|---|---|---|---|
| d = 50 m | 1 | 1 | 2 |
| d = 500 m | 1 | 2 | 8 |
| d = 5000 m | 2 | 8 | 32 |

`run_beamforming_sweep.m` therefore sweeps `distance = [50 500 5000]` rather
than a single value. `d = 50 m` is kept because it is the only distance
directly comparable to the multiplexing run.

There is a second, weaker trade in the same direction: gain grows
**quadratically** in `N` for a square array (`N_t·N_r = N²`) while hardware
grows **linearly** (`N` chains per side). Once the PA term matters at all,
that favours large arrays — hence `N_t = 32` at 5 km.

## Where it lives

- `+physics/linkBudgetDb.m` — the one place antenna count touches the link
  budget, so the two modes cannot drift apart
- `+data/seCurveFilename.m` — forces the SISO filename in beamforming mode
- `+gears/qamGear.m`, `+gears/zxmGear.m` — candidates from
  `scenario.beamformingConfigs`; ZXM also gained the per-chain `N_t`/`N_r`
  hardware scaling that previously only QAM had (in multiplexing mode
  `N_t = N_r = 1`, so no existing ZXM result changes)
- `run_beamforming_sweep.m` — entry point, own results directories

## Verified

- Multiplexing unchanged: stored `results/qam_M16_fc28GHz.mat` reproduced to a
  max relative deviation of **1.4e-16**, same winning `N_t` at every point
- Beamforming reuses the SISO curve (`isequal` on the SE vector, 1×1 vs 8×8)
  and the path-loss delta is exactly `10·log10(64) = 18.0618 dB`, for QAM and ZXM
- End-to-end sweep writes all 11 gear/order combos; QAM and ZXM both select
  `N_t ∈ {1, 2, 8}` at `d = 500 m`

## Not addressed

Hardcoded paths in `tests/` (`/workspace/gearboxphy_framework`) are stale since
the directory rename, so `runtests` fails before reaching any assertion. With
an explicit `addpath`, `PhysicsTest` passes 9/9. Pre-existing, unrelated to
this extension.
