# PA Power Scaling for MIMO — Two Models, Compared

**Status:** decision needed before `qamGear.m`'s `P_PA` treatment can be considered final.
Currently implemented: Model A (no `N_t` scaling). This document lays out both options so you
can decide with the actual trade-off in front of you, per your request.

---

## The question

`qamGear.m`'s `computeCore` currently computes:

```matlab
core.P_PA = gearboxphy.physics.powerAmplifier(P_t, ctx.sqrt_fc, ctx.papr, hw.c_PA);
% i.e. P_PA = c_PA * P_t * sqrt_fc * papr — no N_t multiplier
```

where `P_t` is the *total* required transmit power from the link budget (SISO or MIMO — it's
whatever `SNR_transmitter` demands for the target spectral efficiency at that antenna
config). With `N_t` transmit antennas, that same total `P_t` gets split across `N_t`
individual PAs. The question is whether the *total* DC power drawn by those `N_t` PAs, to
jointly deliver `P_t` watts of RF output, equals `c_PA·P_t·…` (unchanged) or something larger.

---

## Model A — constant PA efficiency, independent of power level

**Assumption:** a PA's DC-to-RF conversion efficiency is a fixed constant, `1/c_PA`,
regardless of how much RF power it's actually asked to deliver. "Design an optimal PA for
this config" just means: whatever power level `P_t/N_t` each of the `N_t` PAs needs to hit,
you can always build one that achieves the *same* efficiency constant.

**Consequence — mathematically forced, not a choice:** splitting the same total `P_t` across
`N_t` equally-efficient PAs gives

$$N_t \cdot c_{PA} \cdot \frac{P_t}{N_t} \cdot \text{sqrt\_fc} \cdot \text{papr} \;=\; c_{PA} \cdot P_t \cdot \text{sqrt\_fc} \cdot \text{papr}$$

— exactly the SISO formula, unchanged by `N_t`. This isn't an extra assumption layered on top
of "constant efficiency" — it's what "constant efficiency, at any power level" *means*
algebraically. **This is what the existing dissertation formula (`e_bit_fct_QAM_v2.m`,
unchanged since before this MIMO extension) already assumes**, and it's what's currently
implemented in `qamGear.m`.

**Where this assumption is standard in the literature:** treating a PA's power draw as
strictly proportional to its RF output (a single efficiency figure, no fixed term) is a common
simplification at the system/algorithm level — for instance, S. Cui, A. Goldsmith, and A.
Bahai's foundational MIMO-sensor-network energy model (cited in `MIMO_EXTENSION.md` §1.2 as
the ancestor of the Björnson et al. transceiver-chain model) uses exactly this kind of
proportional PA term, separate from the *other* per-antenna circuit components (converters,
mixers, filters) that the Björnson paper explicitly does scale with antenna count. In other
words: **the literature itself treats "PA output power" and "per-chain circuit overhead" as
two different kinds of terms with two different scaling rules** — which is exactly the split
already implemented (`P_PA` unscaled, `P_ADC`/`P_LNA`/`P_DAC`/`P_Mix` scaled by `N_t`/`N_r`).

**When Model A is the right call:** when you want the MIMO gain to show up *only* through the
genuine mechanism this whole framework already models correctly — a smaller `P_t` from the
improved link budget (more antennas → better SNR → less required transmit power for the same
rate) — without also crediting or penalizing antenna count for PA circuit-design effects the
original dissertation formula never modeled at all.

---

## Model B — PA efficiency degrades at lower per-chain power (affine power model)

**Assumption:** a PA's efficiency isn't a fixed constant — it depends on the actual power
level it operates at. This is physically real: Class-AB PA efficiency falls roughly with
$\sqrt{P_{out}}$ as you back off from peak output (a 60%-peak-efficiency Class-AB PA can drop
to ~15% at 6 dB back-off) — smaller PAs generally can't match a bigger PA's efficiency at
proportionally the same relative load, because bias/quiescent currents and matching-network
losses don't scale down proportionally with output power.

**The standard way this is captured in the energy-efficiency literature** is the *affine*
power-consumption model:

> G. Auer, V. Giannini, C. Desset, I. Godor, P. Skillermark, M. Olsson, M. A. Imran, D.
> Sabella, M. J. Gonzalez, O. Blume, and A. Fehske, "How Much Energy is Needed to Run a
> Wireless Network?," *IEEE Wireless Communications*, vol. 18, no. 5, pp. 40–49, Oct. 2011.
> DOI: [10.1109/MWC.2011.6056691](https://doi.org/10.1109/MWC.2011.6056691)

Their base-station power model (part of the widely-used EARTH project framework):

$$P_{\text{tot}} = P_0 + \beta \cdot P_T$$

where $P_T$ is radiated transmit power, $1/\beta$ is the PA's efficiency at full load, and
$P_0$ is a **fixed, per-PA static overhead** (bias/quiescent power, present even at zero
output) — the term Model A has no equivalent for.

**Applied per-antenna to this framework's formula**, with $N_t$ transmit chains each handling
$P_t/N_t$:

$$P_{PA,\text{total}} = N_t \cdot \left( P_0 + c_{PA} \cdot \frac{P_t}{N_t} \cdot \text{sqrt\_fc} \cdot \text{papr} \right) = N_t \cdot P_0 \;+\; c_{PA} \cdot P_t \cdot \text{sqrt\_fc} \cdot \text{papr}$$

Notice the linear-in-$P_t$ term is **still scale-invariant** (matches Model A exactly) — it's
the new $N_t \cdot P_0$ term that makes total PA power grow with antenna count. This is the
mathematically precise version of "more antennas cost more, even with optimal per-config
design": the fixed overhead per chain is unavoidable and multiplies by $N_t$, while the
power-proportional part behaves exactly as Model A already assumes.

**What this needs that the codebase doesn't currently have:** a value for $P_0$ (fixed PA
overhead power, in Watts) — a new hardware constant, not derivable from anything in the
original dissertation formulas. `c_PA` alone (today's only PA parameter) isn't enough to
express this model; you'd need to supply $P_0$ from a real PA datasheet/paper or a design
assumption, the same way `c_PA`, `DAC_I0`, `c_ADC`, etc. were themselves originally sourced
from literature/datasheets for the SISO case.

---

## Side-by-side

| | Model A (current) | Model B (affine) |
|---|---|---|
| PA power formula | $c_{PA} \cdot P_t \cdot \text{sqrt\_fc} \cdot \text{papr}$ | $N_t \cdot P_0 + c_{PA} \cdot P_t \cdot \text{sqrt\_fc} \cdot \text{papr}$ |
| Depends on `N_t`? | No | Yes — grows linearly via the new $N_t \cdot P_0$ term |
| New parameter needed | None | $P_0$ (fixed per-PA overhead, Watts) |
| Physical realism | Idealized (constant efficiency at any power) | More realistic (matches known Class-AB backoff behavior) |
| Consistent with original dissertation formula | Exactly - same formula, N_t=1 special case | No - original never modeled per-chain fixed overhead |
| Effect on MIMO's apparent benefit | MIMO gain shows up purely via lower $P_t$ | MIMO gain partially offset by $N_t \cdot P_0$ penalty - more antennas need a bigger $P_t$ reduction to still win |
| Implementation effort | None (already done) | Add `P_0` to scenario config; `core.P_PA = ctx.N_t*hw.P_0 + gearboxphy.physics.powerAmplifier(...)` |

---

## What I need from you to finalize

1. **Which model** — A (current) or B?
2. **If B: a value for $P_0$.** Options, roughly in order of rigor:
   - A datasheet value for a specific PA IC at your target frequency band(s), if you have one
     in mind for this hardware profile (matches how `c_PA`/`DAC_I0`/etc. were likely sourced
     originally).
   - A value derived from the Auer et al. (2011) EARTH framework's own reference numbers for
     a comparable BS class (macro/micro/pico), scaled to this dissertation's much
     lower-power regime — would need you to confirm the scaling assumption, since EARTH's own
     numbers target macro-cell base stations, not the low-power IoT-scale hardware this
     dissertation profile otherwise targets.
   - A placeholder/order-of-magnitude estimate, explicitly flagged as unverified (consistent
     with how the `0.7`-single-ended-LO and `PAPR_RRC` items are already flagged) - lets the
     pipeline run and be examined qualitatively before a hard literature value replaces it.
