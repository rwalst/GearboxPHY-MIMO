# MIMO Extension — Scientific Background & Power-Model Decision

**Status:** all five MIMO extension design questions now decided (§2 and §3) - ready for
implementation. This is a companion to `ARCHITECTURE_PLAN.md`'s MIMO extension plan, not a
replacement for it; §4 sketches how the decisions land in `qamGear.m`/`runSweep.m` concretely.

---

## 1. Scientific background

### 1.1 Why antenna configuration enters the SNR/mutual-information lookup at all

The current framework's gears each look up a required SNR for a target spectral efficiency
from a curve that depends only on the modulation family and order (`SE_data/SE_<M>_QAM.mat`,
etc.). This is a single-antenna (SISO) relationship. Once multiple antennas are introduced,
the same target spectral efficiency requires a *different* SNR depending on the number of
transmit/receive antennas and how they're used (spatial multiplexing for rate, space-time
coding for diversity, beamforming for array gain) — this is the foundational result of

> İ. E. Telatar, "Capacity of Multi-Antenna Gaussian Channels," *European Transactions on
> Telecommunications*, vol. 10, no. 6, pp. 585–595, Nov. 1999.
> [https://doi.org/10.1002/ett.4460100604](https://doi.org/10.1002/ett.4460100604)

Telatar showed that the capacity of a Gaussian MIMO channel with $N_t$ transmit and $N_r$
receive antennas scales (under favorable, i.i.d.-fading conditions) with $\min(N_t, N_r)$
relative to a SISO link at the same per-antenna SNR — i.e., the SNR-to-spectral-efficiency
relationship this framework looks up is fundamentally reshaped by antenna count, not just
shifted. This is the reason `+data/loadSECurve.m` needs a new axis (`antennaConfig`) rather
than treating antenna count as another multiplier applied to a SISO curve after the fact —
consistent with how `ARCHITECTURE_PLAN.md`'s MIMO extension plan already scopes it.

*(This paper does not resolve the still-open "does the curve already include array gain from*
*`D_r`/`D_t`" question from `ARCHITECTURE_PLAN.md` — it establishes *why* the curve itself*
*must be antenna-config-specific, not what its normalization convention should be.)*

### 1.2 Hardware/circuit power consumption model for MIMO transceivers

The question actually resolved in this document — how transmit/receive chain hardware power
(specifically the mixer and local oscillator) scales with antenna count — is answered by the
standard, widely-cited circuit power consumption model from:

> E. Björnson, L. Sanguinetti, J. Hoydis, and M. Debbah, "Optimal Design of Energy-Efficient
> Multi-User MIMO Systems: Is Massive MIMO the Answer?," *IEEE Transactions on Wireless
> Communications*, vol. 14, no. 6, pp. 3059–3075, June 2015.
> arXiv preprint: [https://arxiv.org/abs/1310.3843](https://arxiv.org/abs/1310.3843)

Section II-B-1 ("Transceiver Chains") of that paper states the model directly:

> "The typical MIMO transceivers ... have a power consumption of $M P_{\text{tx}} + K
> P_{\text{rx}} + P_{\text{syn}}$ Joule/channel use. $P_{\text{tx}}$ is the power of the BS
> components attached to **each antenna**: converters, **mixers**, and filters. **A single
> oscillator with power $P_{\text{syn}}$ is used for all BS antennas.** ... $P_{\text{rx}}$ is
> the power of all receiver components: amplifiers, mixer, oscillator, and filters."

The load-bearing fact for this project: **the mixer is bundled into the per-antenna term and
multiplied by the antenna count ($M$ transmit antennas); the local oscillator is a single
shared term, used once, not multiplied by antenna count.** This is a direct statement in one
of the most-cited papers in the massive-MIMO energy-efficiency literature (the model itself
traces to earlier work the paper cites: S. Cui, A. Goldsmith, and A. Bahai, "Energy-efficiency
of MIMO and cooperative MIMO techniques in sensor networks," *IEEE J. Sel. Areas Commun.*,
vol. 22, no. 6, pp. 1089–1098, 2004 — the same per-antenna-mixer / shared-oscillator structure
appears there too).

### 1.3 Caveat: this is the fully-digital baseline, not the only architecture

The linear-in-antenna-count mixer scaling above assumes **one full RF chain per antenna
element** — every antenna independently up/down-converts its own signal. Architectures that
deliberately use *fewer* RF chains than physical antennas (antenna selection, hybrid analog/
digital beamforming) break this linearity by design, specifically to avoid it:

> E. Nascimento Junior, G. Theis, E. L. dos Santos, A. A. Mariano, G. Brante, R. D. Souza, and
> T. Taris, "Energy Efficiency Analysis of MIMO Wideband RF Front-End Receivers," *Sensors*,
> vol. 20, no. 24, article 7070, 2020. DOI:
> [10.3390/s20247070](https://doi.org/10.3390/s20247070)

This paper's whole comparison (single antenna vs. antenna selection vs. SVD beamforming)
exists because antenna selection reduces the number of active RF chains — and therefore
active mixers — below the number of physical antenna elements, trading spectral efficiency
for hardware power savings. If a future extension of this framework covers hybrid or
antenna-selection MIMO, the mixer multiplier there is **number of active RF chains**, not
antenna count, and needs its own term.

---

## 2. Decision: assume fully digital MIMO, adopt the Björnson et al. split

For this extension, we assume **fully digital MIMO**: every antenna element has its own
complete RF chain (its own PA/DAC on transmit, its own LNA/ADC/mixer on receive). No antenna
selection, no hybrid beamforming. Under that assumption, per §1.2:

- **`P_Mix` scales linearly with antenna count** — a separate mixer per antenna, on whichever
  side (transmit or receive) is active.
- **`P_LO` does not scale with antenna count** — one shared oscillator reference, distributed
  to every chain (also physically necessary for phase-coherent MIMO combining/precoding, not
  just a cost-saving choice).
- **`P_LO` also stays shared between the transmit and receive roles**, consistent with how the
  *existing SISO code already models it* — `e_bit_fct_QAM_v2.m` (and every other gear) uses a
  single `P_LO` value in both the transmit-duty-cycle-weighted term and the receive-duty-cycle-
  weighted term, not `P_LO_Tx + P_LO_Rx`. This is the right model for a half-duplex,
  duty-cycled device that is never transmitting and receiving simultaneously — one physical
  LO block, reconfigured per active role. MIMO doesn't change this; it only adds the
  antenna-count axis on top.

### 2.1 What this changes, concretely

Today, every gear's power computation uses a single, direction-independent `P_Mix` (and
`P_LO`), read once from `ctx.hw` and applied identically in both the transmit-weighted and
receive-weighted terms of the energy-per-bit formula (see e.g. `qamGear.m`'s `objective()`).
Under the fully-digital MIMO split, `P_Mix` becomes **direction-dependent** (because `N_t` and
`N_r` can differ) while `P_LO` remains a single shared scalar exactly as today:

```matlab
% Today (SISO, ctx.hw.P_Mix used identically on both sides):
out = (1/R) * ( (gamma+hw.epsilon_trans*(1-gamma))*(core.P_PA+core.P_DAC+hw.P_LO+hw.P_Mix) ...
              + (gamma+hw.epsilon_rec*(1-gamma))*(core.P_ADC+core.P_LNA+hw.P_LO+hw.P_Mix) );

% MIMO (fully digital, N_t/N_r from antennaConfig):
core.P_Mix_Tx = antennaConfig.N_t * hw.P_Mix_unit;
core.P_Mix_Rx = antennaConfig.N_r * hw.P_Mix_unit;
out = (1/R) * ( (gamma+hw.epsilon_trans*(1-gamma))*(core.P_PA+core.P_DAC+hw.P_LO+core.P_Mix_Tx) ...
              + (gamma+hw.epsilon_rec*(1-gamma))*(core.P_ADC+core.P_LNA+hw.P_LO+core.P_Mix_Rx) );
```

`hw.P_LO` is untouched — one value, still shared across both terms, exactly as it is today.
Only `P_Mix` gains the `N_t`/`N_r` split. `P_PA`, `P_ADC`, `P_DAC`, `P_LNA` were already
flagged in `ARCHITECTURE_PLAN.md`'s MIMO extension plan as needing their own `N_t`/`N_r`
multipliers (they're per-antenna-chain components too, same as the mixer) — this document
doesn't change that, it specifically nails down the mixer/LO question that was still open.

This resolves item 3 ("RF chain-sharing assumption") from the MIMO extension's open-question
list in the prior discussion.

---

## 3. Remaining open questions — now decided

1. **Antenna-gain double counting.**
   **Decision: `D_r`/`D_t` still apply on top.** The MIMO SE curve is treated as a pure
   channel-capacity/SNR relationship (no array/antenna gain baked in); `pathLossDb`'s
   `D_r`/`D_t` remain a separate, multiplicative link-budget term exactly as in the SISO case.
   No change needed to `+physics/pathLossDb.m` itself — it applies identically to SISO and
   MIMO configs.
2. **Which gears get a MIMO variant.**
   **Decision: QAM only.** `naQamGear`/`zxmGear`/`pulseGear` stay SISO-only for this
   extension. `qamGear` is the only gear that grows an `antennaConfig` parameter.
3. **Curve provenance.**
   **Decision: supplied externally.** MIMO `SE_data` `.mat` files are a frozen, externally-
   produced input, same treatment as today's SISO curves — this plan only defines the new
   filename/lookup convention (`+data/loadSECurve.m` gains an `antennaConfig` argument),
   not how the curves themselves get generated.
4. **Optimization surface.**
   **Decision: jointly optimized, via nested enumeration.** `(N_t, N_r)` are NOT handed to
   `fminsearch`/`fminbnd` directly (they're integers; those solvers are continuous, and true
   mixed-integer optimization would require the Global Optimization Toolbox — a new toolbox
   dependency this project has otherwise avoided taking on). Instead: enumerate a small,
   caller-supplied set of candidate `(N_t, N_r)` pairs as an *outer* loop, run the existing
   continuous `fminsearch` over `(B, gamma)` for each candidate exactly as today, and keep
   whichever `(N_t, N_r)` gives the lowest energy-per-bit for that `(R, f_c)` point. The
   *result* is indistinguishable from a true joint optimization (the best antenna count is
   genuinely selected, not fixed in advance) - it's implemented as nested enumeration +
   continuous optimization rather than one flat multi-variable solver call, staying entirely
   within core MATLAB. This mirrors how Björnson et al. (§1.2) handle their own closed-form
   "optimal $M$" result: solved as if continuous, then rounded/compared over the nearest
   integers - the same real-valued-relaxation-then-discrete-comparison structure, just
   inverted here (we discretely enumerate first since the inner problem, not the outer one,
   has the closed-ish-form/numerical solver).

---

## 4. What this means concretely for `qamGear.m`

With all five decisions now made (§2's RF-chain split plus §3's four), the shape of the QAM
MIMO extension is:

- `qamGear`'s `prepare(order, carrierScenario, antennaConfig)` gains a third parameter
  (`antennaConfig` = `struct('N_t', ..., 'N_r', ...)`), loads
  `loadSECurve("QAM", order, antennaConfig, dataDir)` (new filename convention, e.g.
  `SE_16_QAM_2x2.mat`, SISO's existing `SE_16_QAM.mat` reachable as the `N_t=N_r=1` case),
  and does **not** change how `pathLossDb` is called (decision 1).
- `computeCore`'s per-antenna hardware terms (`P_PA`, `P_ADC`, `P_LNA`, `P_DAC`, and now
  `P_Mix` per §2) each gain an `N_t`-or-`N_r` multiplier depending on which side they're on;
  `P_LO` stays untouched, one shared scalar.
- `+sweep/runSweep.m`'s loop over `gear.orders` gains a nested loop over a new
  `gear.antennaConfigs` list (QAM only, per decision 2) *inside* the order loop; for each
  `(order, antennaConfig)` pair the existing `prepare` → `initialGuess` → `optimizerBounds` →
  `optimizeOnePoint` flow runs unchanged.
- The **antenna-count selection itself** (decision 4) happens one level up again: for a given
  `(R, f_c, order)`, run the above for every candidate `antennaConfig` in
  `gear.antennaConfigs`, then keep the minimum-energy-per-bit result across them before
  saving - i.e., the consolidated result table's `Optimal_B`/`Optimal_gamma` row for a QAM
  order also implicitly carries a "which antenna config won" answer, which
  `+data/resultKey.m`/`saveAllResults.m` need a new field for (`Optimal_N_t`,
  `Optimal_N_r`) alongside the existing `E_per_bit`/`Optimal_B`/`Optimal_gamma` outputs.
- `+data/resultKey.m` itself does **not** need an `antennaConfig` component in the key, since
  antenna config is now a *selected* output of the optimization for a given order, not an
  independent sweep axis the way order is (contrast with §3.3's original framing, which
  assumed antenna config would be enumerated and compared like a gear/order - decision 4
  supersedes that: it's chosen internally, once, per `(order, f_c, R)` point).
