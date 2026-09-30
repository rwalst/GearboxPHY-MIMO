# LNA Power Model: Review and Proposal

**Status (2026-09-30):**

- **Wired in as a scenario switch.** The models are available via
  `makeScenarioConfig('lnaPowerModel', ...)`, with the dissertation model as
  the default. The per-carrier B_max goes through `'B_maxByCarrier'`.
- **Comparison framework ready but not run.**
  `gearboxphy_framework/HPC_RUNBOOK_LNA_VERGLEICH.md` has the steps:
  `validate_lna_comparison`, then `run_lna_comparison`, then
  `analyze_lna_comparison`.
- **Fit and plots** are in `LituratureReview/lna_survey_fit/` (§6).

Companion to `PHASE_SHIFTER_POWER_MODEL.md`: the two models interact (§4).

---

## 1. Today's model, traced to its source

Dissertation eq. (4.5), after Mezghani & Nossek [1], as coded in `lnaPower.m`:

$$
\mathrm{FOM_{LNA}} = \frac{G_\mathrm{LNA}\,B\,N_0}{(F_\mathrm{LNA}-1)\,P_\mathrm{LNA}}
\;\Rightarrow\;
P_\mathrm{LNA} = \frac{G\,B\,N_0}{(F-1)\,\mathrm{FOM}},\qquad G=32,\;F=3,\;\mathrm{FOM}=10^{-7}.
$$

This gives **0.65 mW per GHz of B**: 65 µW at 100 MHz and 6.5 µW at 10 MHz,
the same at every carrier.

What the source says ([1], checked in the PDF):

- The FoM is taken from **a single circuit**: ref. [8] of [1], Yu, Chen & Heo,
  "A 0.6-V low power UWB CMOS LNA", IEEE MWCL 2007 [2]. [1] multiplied it by N₀
  "just to make it dimensionless".
- [1] states the range 10⁻⁷ … 10⁻⁹ without further sources, and uses 10⁻⁷.
  That is the optimistic end.
- [1] targets **UWB with unconstrained bandwidth**. Its bandwidth B is the
  amplifier's own 3-dB bandwidth (2.7–9.1 GHz in [2]), not the signal
  bandwidth.
- [2]'s abstract figures are G = 10 dB, NF = 4.65 dB average, BW = 6.4 GHz and
  P = 7 mW. They give FOM ≈ **1.9·10⁻⁸**, so even the cited LNA is about 5×
  worse than the 10⁻⁷ used.
- Across the whole survey, evaluated with each LNA's *own* bandwidth, the
  FOM has a median of 5.6·10⁻⁸ and **10⁻⁷ is about the 60th percentile**
  (n = 745). As a design FoM, 10⁻⁷ is therefore fine.

**Assessment (revised after discussion).** Using the signal bandwidth is
*intended*. The Gearbox paradigm is that the hardware is designed optimally
for each operating point, so the LNA has exactly the bandwidth it needs.
That is legitimate, and it also has a physical basis. A tuned stage has a
fixed gain–bandwidth product, G·BW ∝ g_m/C, so at constant gain, halving
the bandwidth halves the g_m and therefore the current. This is the
structure of the FoM.

Two things limit the paradigm, and the survey shows both (§6):

1. **Power does not fall linearly with bandwidth.** The noise figure sets a
   minimum g_m that does not shrink with the bandwidth: noise matching needs
   transconductance, not bandwidth. Along the lower envelope of the survey,
   **P ∝ BW^0.46** (95 % CI 0.32–0.81), not BW¹.
2. **An LNA cannot be made arbitrarily narrow.** The quality factor of
   on-chip passives limits the minimum bandwidth. The narrowest 5 % of
   designs have a fractional bandwidth of about **5 %** of f₀. At 28 GHz
   that means B ≥ 1.4 GHz. No LNA in the survey is narrower than 0.5 GHz
   at 15–40 GHz, or narrower than 1.8 GHz at 40–100 GHz.

Today's model therefore gets the *direction* right but has two problems:

- It extrapolates down to B → 0 (6.5 µW at 10 MHz for a 28 GHz LNA).
- It rewards narrowing too strongly (linear instead of about √B).

This matters because the Gearbox optimizes mostly at low rates, which is
where the dissertation finds the most frequent demand.

## 2. What the circuit data say

**Survey.** Belostotski & Jagtap [3] (dissertation ref. [BJ20]) cover more than
500 LNAs from JSSC, T-MTT, MWCL, ISSCC, IMS and RFIC. Findings from the text
(PDF checked):

- **Power vs. carrier:** the CMOS trend line is **about 1.7× per decade of f₀**,
  i.e. P_dc ∝ f₀^0.23 (Fig. 3). The spread is large: some LNAs are
  ultra-low-power, some are high-linearity designs.
- **Gain:** uncorrelated with frequency, technology *and power*. Gain comes
  from extra stages, which "normally have only a marginal effect on power
  consumption".
- **The G/((F−1)P) form:** the survey tests FOM₀ = G/((F−1)·P_dc), the form
  used by [1] and by the NYU papers in §3. The data do *not* support it:
  halving F−1 by doubling P_dc is "not intuitively tenable".
- **Bandwidth:** the survey fits only the *relative* bandwidth B/f₀, with a
  weak exponent: (B/f₀)^0.32 inside FOM_new^B, eq. (4). Absolute signal
  bandwidth does not drive power.
- **Regression FoM**, eq. (2)/(3), with feature size L and cascaded noise
  temperature T_cas:

  $$f_0[\mathrm{GHz}] + 14.2 \approx 13.8\,\frac{P_{dc}[\mathrm{mW}]^{0.16}\,T_{cas}[\mathrm{K}]^{0.55}}{L[\mathrm{nm}]^{0.5}}$$

  Inverted, this gives P ∝ ((f₀+14.2)²·L/T_cas^1.1)^3.1. That is far too
  steep to use as a design law, because L itself shrinks with f₀ in the data.
  It is useful only as a sanity check.
- **Physics** for common-source LNAs (> ~14 GHz): T ∝ g_m f₀²/f_T² with
  f_T ≈ g_m/2πC_gs gives **P_dc ∝ f₀²·L^2.5/T** at fixed technology. The
  weak observed trend (f₀^0.23) exists because high-f₀ designs use finer
  nodes.
- **Noise figure** rises with f₀, with a knee just below 20 GHz (Fig. 1).
  The fixed 5 dB (F = 3) in the dissertation is optimistic at 60 GHz but fine
  at 2.4–28 GHz.

The survey spreadsheet (`lna_survey.xlsx`, version Nov 2024) is in
`LituratureReview/`. It is evaluated in §6.

## 3. What other system models use

| Paper | Model | Value per LNA | Checked |
|---|---|---|---|
| Mezghani & Nossek 2011 [1] → dissertation | G·B·N₀/((F−1)FOM), FOM 10⁻⁷ | 0.65 mW/GHz | yes |
| Dutta et al., "A case for digital BF at mmWave", TWC 2020 [4] | **G/(FoM·(F−1))**, FoM = 6.5 mW⁻¹ (30 GHz, 90 nm CMOS, Adabi et al. RFIC 2007) | 1.5 mW at G = 10 dB, NF = 3 dB | yes |
| Skrimponis et al., 6G Summit 2020 [5] | same form; 28 GHz BiCMOS FoM = 8.46 mW⁻¹, NF 3.1 dB; 140 GHz CMOS FoM = 0.87 mW⁻¹, NF 5.2 dB | 1.1 mW (28 GHz), 5.0 mW (140 GHz) at G = 10 dB | yes |
| Méndez-Rial et al. 2016 [6] | constant | 20 mW (range of cited 60 GHz designs: 4.6–86 mW) | yes |
| Abbas et al. [7] | constant | 39 mW | yes |
| Roth & Nossek [8] | constant (60 GHz WiGig parts) | 5.4 mW | yes |

Two things stand out:

1. **No carrier-dependent model exists in the system literature.** Everyone
   uses one number, or a FoM for one chip, per study.
2. **At high rates the dissertation model is not an outlier.** At 1–2 GHz of
   bandwidth it gives 0.65–1.3 mW, close to the NYU values of 1.1–1.5 mW at
   G = 10 dB. **I have to correct my earlier remark here:** "real LNAs draw
   5–40 mW" holds for chips with 15–25 dB gain, not for the 10 dB gain
   assumed in these system papers. The real problem is the **B scaling at
   low rates**, not the absolute level.

## 4. Coupling with the phase-shifter model

[4] and [5] do **not** use my Friis penalty (`phaseShifterPenalty.m`). They
compensate the passive phase shifter's loss with LNA gain, G → G·L_PS. With
their G-proportional FoM this multiplies the LNA power by L_PS:

- At 28 GHz, [5] reports LNA power of 9 mW for the digital receiver vs. 180 mW
  for the analog one (8 antennas, 2 streams, IL = 10 dB).
- **Under that assumption a passive phase shifter costs about 10 mW per
  element, not about 0.** That is the same order as an active one.

My Friis approach assumes the opposite: gain is cheap. That is backed by the
survey finding that gain is uncorrelated with power (§2). The truth is likely
in between, because an extra gain stage costs something. **This decides
whether "passive phase shifter ≈ free" holds.** Both variants should therefore
be run as a sensitivity pair.

## 5. Proposal

Keep the paradigm (LNA designed for exactly B), and take the scaling from the
**lower envelope** of the survey, as the dissertation does for the PA
(Fig. 4.2) and the ADC (Fig. 4.3). Add the bandwidth floor that technology
imposes:

$$
P_\mathrm{LNA} \gtrsim 0.78\,\mathrm{mW}\left(\frac{f_c}{1\,\mathrm{GHz}}\right)^{0.28}\left(\frac{B_\mathrm{eff}}{1\,\mathrm{GHz}}\right)^{0.46},
\qquad B_\mathrm{eff} = \max(B,\;\beta_\mathrm{min} f_c),\quad \beta_\mathrm{min}=0.05 .
$$

- 5 % quantile regression of log P on log f and log BW; 317 silicon LNAs
  with G ≥ 15 dB and NF ≤ 5 dB.
- β_min = 5 % is the 5th percentile of the fractional bandwidth in the
  survey.
- Implemented as `lnaPowerEnvelope(f_c, B)`.

At or below the floor (B ≤ β_min·f_c, i.e. the Gearbox's low-rate regime):

| f_c | 2.4 GHz | 8 GHz | 28 GHz | 60 GHz |
|---|---|---|---|---|
| B_min = 0.05·f_c | 0.12 GHz | 0.40 GHz | 1.4 GHz | 3.0 GHz |
| **proposed, at B_min** | **0.38 mW** | **0.91 mW** | **2.30 mW** | **4.04 mW** |
| proposed, at B = 1 GHz | 0.99 mW | 1.39 mW | 2.30 mW (floor) | 4.04 mW (floor) |
| `lnaPower.m`, same B_min | 0.078 mW | 0.26 mW | 0.91 mW | 1.96 mW |
| `lnaPower.m`, B = 10 MHz | 0.0065 mW | 0.0065 mW | 0.0065 mW | 0.0065 mW |
| for scale: P_Mix + P_LO (Tab. 4.1) | 7.6 mW | 21.8 mW | 35.3 mW | 77 mW |

The **minimal change** that keeps `lnaPower.m`'s form is to add only the
floor: `lnaPower(max(B, 0.05*f_c), N_0)`. That is still 2–5× below the
survey envelope.

**Variants, as a scenario switch** (like `paPowerModel`):

| Variant | Formula | Purpose |
|---|---|---|
| `"fom_bandwidth"` (default) | today's `lnaPower.m` | reproduces every existing result |
| `"envelope"` | `lnaPowerEnvelope(f_c, B)` | proposed main model |
| `"fom_floor"` | `lnaPower(max(B, 0.05 f_c), N_0)` | smallest change to the dissertation model |
| `"fom_gain"` | G/(FoM₀(f_c)·(F−1)), FoM₀ from [4,5] | comparability with the NYU papers; the only variant where passive phase shifters raise LNA power |

**Expected effect (from the table, nothing simulated):**

- **SISO receiver at low rates:** the LNA adds about 4–7 % to P_Mix + P_LO
  (0.38/7.6, 0.91/21.8, 2.30/35.3, 4.04/77). The shift in the dissertation's
  gear choices should be small.
- **Beamforming:** each extra receive antenna costs at least 2.3 mW at
  28 GHz at low rates, instead of about 0.01 mW today. In digital BF that is
  +27 % on the per-chain mixer (8.4 mW).

## 6. Survey evaluation

Script `LituratureReview/lna_survey_fit/fit_lna_envelope.py` reads
`lna_survey.xlsx` and writes `lna_survey_si.csv`. `plot_lna_envelope.m`
draws the figure (not run here).

**Data.** 827 silicon LNAs (CMOS 651, SiGe 176) with f₀ and P_dc. Of these,
**345** have G ≥ 15 dB and NF ≤ 5 dB in 1–100 GHz. These match the
dissertation's LNA assumptions (Sec. 4.2.4), so the bound applies to them.

**Fit in f only** (bandwidth not separated; superseded by the two-variable
fit below). Linear quantile regression of log P on log f:

| quantile | fit | 2.4 / 8 / 28 / 60 GHz |
|---|---|---|
| 5 % | 0.434 mW·f^0.698 | 0.80 / 1.85 / 4.44 / 7.56 mW |
| 10 % | 1.573 mW·f^0.453 | 2.34 / 4.03 / 7.11 / 10.0 mW |
| 25 % | 4.925 mW·f^0.237 | 6.06 / 8.06 / 10.9 / 13.0 mW |
| 50 % | 9.958 mW·f^0.173 | 11.6 / 14.3 / 17.7 / 20.2 mW |

- **Outliers.** The very lowest points are
  special-purpose designs, which the 5 % quantile leaves out:
  - 2.4 GHz: 0.09 mW (a 60 µW sensor-network LNA)
  - 28 GHz band: 0.99 mW (a K-band radio-astronomy LNA at 22.6 GHz)
  - 60 GHz: 3.6 mW (a duty-cycled design)
  The next-best ordinary 28 GHz design draws 3.8 mW (26–29 GHz, 21.6 dB
  gain, 2.5 dB NF), close to the f-only bound of 4.4 mW.
- **The bound rises more steeply with f (0.70) than the median (0.17).**
  The most frugal designs follow the circuit physics (§2) more closely.
  The median is dominated by designs where linearity and gain set the
  power, not f₀.
- **Bandwidth, all designs:** least squares over 756 entries gives
  P ∝ f^0.14·BW^0.15. Across average designs, bandwidth is not what sets
  the power.
- **Bandwidth, lower envelope** (the designs that come closest to "optimal
  for their B"): the 5 % quantile gives **P ∝ f^0.28·BW^0.46**, n = 317.
  Bootstrap 95 % CI: BW exponent 0.32–0.81, f exponent −0.06–0.44. The
  10 % quantile gives f^0.15·BW^0.52. **This is the basis of the proposal.**
  The efficient designs scale with bandwidth, but sublinearly.
- **How narrow LNAs get:** fractional bandwidth over all silicon LNAs:
  5th percentile 5 %, 10th percentile 8 %, median 29 %. The narrowest
  absolute bandwidths per band:

  | band | narrowest | 5th percentile |
  |---|---|---|
  | 1–4 GHz | 10 MHz | 77 MHz |
  | 15–40 GHz | 0.5 GHz | 2.0 GHz |
  | 40–100 GHz | 1.8 GHz | 3.1 GHz |

  Hence β_min = 0.05. Below it there are no data, so nothing is
  extrapolated.
- **Gain vs. power:** weakly correlated (r = 0.25 between log P and G in dB).
  This backs the Friis choice in the phase-shifter model over gain
  compensation (§4), but does not rule the latter out.
- **Noise figure** medians: 2.9 / 3.2 / 3.2 / 5.0 dB at 2.4 / 8 / 28 / 60 GHz.
  The dissertation's F = 3 (4.8 dB) is conservative up to 28 GHz and
  typical at 60 GHz.

---

## Sources

1. A. Mezghani, J. A. Nossek, "Power efficiency in communication systems from a circuit perspective", TU München. [PDF](https://mediatum.ub.tum.de/doc/1083652/1083652.pdf). Dissertation cites the companion paper: "Modeling and minimization of transceiver power consumption in wireless networks", WSA 2011.
2. Y.-H. Yu, Y.-J. E. Chen, D. Heo, "A 0.6-V low power UWB CMOS LNA", IEEE MWCL, vol. 17, no. 3, 2007. [ResearchGate](https://www.researchgate.net/publication/3429399_A_06-V_low_power_UWB_CMOS_LNA) (figures from the abstract/search summary)
3. Survey data: L. Belostotski et al., "Low-noise-amplifier (LNA) performance survey", version Nov 2024 (`LituratureReview/lna_survey.xlsx`). Paper: L. Belostotski, S. Jagtap, "Down with noise: An introduction to a low-noise amplifier survey", IEEE Solid-State Circuits Mag., vol. 12, no. 2, 2020. [PDF](https://ucalgary.scholaris.ca/server/api/core/bitstreams/cd6c5171-a40a-49b8-bb8e-696cc9152250/content). Survey: [ucalgary.ca/lbelosto](https://www.ucalgary.ca/lbelosto)
4. S. Dutta, C. N. Barati, D. Ramirez, A. Dhananjay, J. F. Buckwalter, S. Rangan, "A case for digital beamforming at mmWave", IEEE TWC, vol. 19, no. 2, 2020. [arXiv:1901.08693](https://arxiv.org/abs/1901.08693)
5. P. Skrimponis, S. Dutta, M. Mezzavilla, S. Rangan, S. H. Mirfarshbafan, C. Studer, J. Buckwalter, M. Rodwell, "Power consumption analysis for mobile mmWave and sub-THz receivers", 6G Wireless Summit 2020. [PDF](https://web.ece.ucsb.edu/Faculty/rodwell/publications_and_presentations/publications/2020_3_17_Skrimponis_6Gsummit_digest.pdf)
6. R. Méndez-Rial et al., IEEE Access 2016. [arXiv:1512.03032](https://arxiv.org/pdf/1512.03032)
7. W. bin Abbas, F. Gómez-Cuba, M. Zorzi. [arXiv:1607.03725](https://arxiv.org/abs/1607.03725)
8. K. Roth, J. A. Nossek, JSAC 2017. [arXiv:1610.02909](https://arxiv.org/pdf/1610.02909); values as in [arXiv:1709.09047](https://arxiv.org/pdf/1709.09047)
