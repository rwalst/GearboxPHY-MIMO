# Phase-Shifter Power Model for Analog Beamforming

**Status:** proposal (2026-09-30). The model is not wired into any gear yet.
Parameters are in `+gearboxphy/+physics/phaseShifterParams.m`, the passive
penalties in `phaseShifterPenalty.m` (both in `gearboxphy_framework/`, untested).

**Why this is needed:** Gast's dissertation (Ch. 4.2, 5.3, 6.2) models DAC, mixer,
LO, PA, LNA, ADC and the power detector. It has **no phase-shifter (PS)
model**, because the dissertation covers SISO only. Analog beamforming needs one.
`paper_beamforming/README.md` already lists `N_t · P_PS` as an open item.

---

## 1. What the literature does

### 1.1 System-level papers (hybrid/analog BF energy efficiency)

All of these use **one constant per PS** that does not depend on carrier or
bandwidth. The constants differ by a factor of 20:

| Paper | P_PS | Basis | Verified in PDF |
|---|---|---|---|
| Méndez-Rial et al., IEEE Access 2016 [1] | **30 mW** (≥4 bit) | Table II: seven 60 GHz PS designs, 15–108 mW, most include the LNA | yes (arXiv v1) |
| Abbas, Gómez-Cuba, Zorzi, arXiv 1607.03725 [2] | **19.5 mW** | Yu et al. 2010, 60 GHz | yes |
| Ribeiro et al., IEEE JSTSP 2018 [3] | **21.6 mW** active / **0** passive | active: 15–108 mW listed; passive: "negligible power, significant insertion loss" | yes |
| Ha, Nguyen, Frigon, arXiv 2001.05439 [4] | **40 mW** | – | yes |
| Roth, Pirzadeh, Swindlehurst, Nossek, IEEE JSTSP 2018 [5] | **2 mW** | model from Roth & Nossek JSAC 2017 (60 GHz WiGig parts) | yes |
| Abbas, Gómez-Cuba, Zorzi, arXiv 1811.12811 [6] | **2 mW or 0** | Kong, Berkeley PhD 2014; Lin & Wang, passive, IMS 2016 | yes |
| Chen et al. (twin-resolution), arXiv 2011.12475 [7] | 15 / 14 / 10 mW (high / mid / 1-bit) | 15 mW is attributed to [1], but [1] arXiv v1 says 30 mW | yes |
| Yan et al. (THz, fixed PS), arXiv 2203.15338 [8] | 52 / 39 / 26 mW (3/2/1 bit); fixed PS = passive delay + **16.8 mW** compensation amplifier | VO₂ sub-mm-wave PS; 324 GHz InP amplifier | yes |

Also in circulation: **P_PS = 1.5·2^(b−1) mW** (exponential in the bit count). It
appears in secondary summaries of low-resolution-PS papers. I found **no
circuit-level source** for it, and the measurements in §1.2 do not show
exponential growth with bits. Do not use it.

Two things matter for us:

1. **Where the numbers come from.** Nearly all mm-wave values trace back to
   one handful of 60 GHz CMOS chips from 2010–2013, and those often include the
   LNA. The 30 mW in [1] is therefore closer to "LNA + PS" than to a PS alone.
2. **Active vs. passive.** Only [3], [6] and [8] make this distinction. It is the
   choice that matters most. Note that [1] swaps the two labels: it calls
   reflective/loaded-line/switched-delay PS "active" and vector modulators
   "passive". The circuit literature ([9] and every paper below) uses the
   opposite labels, and so do we.

### 1.2 Circuit-level data (measured chips)

**Active: vector-modulator / vector-sum (VM).** An I/Q network splits the
signal, two VGAs weight it, and the paths are summed. The DC power is set by
the VGA bias current (gain, linearity). Gain is ≈ 0 dB.

| f_c | Design | Bits | P_DC | Source |
|---|---|---|---|---|
| 8–12 GHz | 0.13 µm SiGe, Kibaroglu et al. | 6 | **16.6 mW** | [10] (PDF checked) |
| 28 GHz | 22 nm FD-SOI vector-sum | 6 | 14.4 mW | [11] (abstract only) |
| 28 GHz | 65 nm CMOS, 256-QAM capable | – | 25.2 mW | [12] (abstract only) |
| 60 GHz | 90 nm CMOS current-reuse, Yu et al. | – | **19.8 mW** | [13] (title; cited in [9]) |
| 60 GHz | older designs incl. LNA | 3–5 | 15–108 mW | Table II of [1] |

**Passive: reflection-type (RTPS), switched-line/filter, loaded-line.** The DC
power is essentially zero: switch or varactor control only, and "zero dc power"
is stated explicitly in [9]. The cost is **insertion loss** L_PS.

| f_c | Design | Bits | L_PS (avg.) | Source |
|---|---|---|---|---|
| 1.7–2.2 GHz | pSemi PE44820, CMOS SOI, commercial | 8 | **6 dB** | [14] |
| 7.5–10.5 GHz | 0.18 µm SOI CMOS switched, Chen et al. | 6 | **8–14 dB** | [15] |
| 24 GHz | 180 nm CMOS RTPS | analog | 11.3 dB | Table I of [9] |
| 28 GHz | 65 nm CMOS RTPS | analog | 7.75 dB | Table I of [9] |
| 29 GHz | 65 nm CMOS RTPS, Basaligheh et al. | analog | **9.5 dB**, 0 mW | [9] (PDF checked) |
| 60 GHz | 130 nm BiCMOS RTPS | analog | **9.9 dB** (8.2 dB for a 200° variant) | Table I of [9] |
| 57–66 GHz | 90 nm CMOS switched | 4 | 16–19 dB | Table of [16] |
| 90–100 GHz | 130 nm SiGe switched | 6 | 12–15.5 dB | [16] |

### 1.3 What the data say about scaling

- **Carrier frequency f_c:**
  - *Active VM:* no visible trend. Designs at 10, 28 and 60 GHz all sit at
    15–25 mW. This differs from the LO and mixer, which the dissertation
    finds roughly linear in f_c (Tab. 4.1).
  - *Passive:* the loss grows mildly, from ~6 dB at 2 GHz to ~10 dB at
    28–60 GHz (RTPS) and >12 dB at W-band.
- **Bandwidth B:** not a driver. All designs cover ≥10 % fractional
  bandwidth. The limit is beam squint (a phase shifter is not a true time
  delay), which is a separate topic (`BeamfocussingGearbox/`).
- **Resolution b:**
  - *Active VM and RTPS:* continuous control. Resolution comes from the
    control DAC, and DC power does not depend on b.
  - *Switched passive:* one cascaded stage per bit, so the loss grows about
    linearly: ~0.75 dB/bit at 2 GHz, ~2–4 dB/bit at 60–100 GHz.
  - None of the data supports exponential growth in b.

---

## 2. Proposed model

### 2.1 Architecture (one stream, analog beamforming)

    Tx:  2×DAC → Mix → split 1:N_t → [PS_n → PA_n] → antenna_n
    Rx:  antenna_n → [LNA_n → PS_n] → combine N_r:1 → Mix → 2×ADC

The PS sits on the low-power side: before the PA and after the LNA. Splitter
and combiner are ideal and lossless. This matches the dissertation's
assumption of ideal passive filters and antennas (Sec. 4.2).

### 2.2 Power terms

$$
P_\mathrm{Tx}^\mathrm{ana} = 2P_\mathrm{DAC} + P_\mathrm{LO} + P_\mathrm{Mix}
      + N_t\,P_\mathrm{PS} + P_\mathrm{PA}\,\kappa_\mathrm{Tx},
\qquad
P_\mathrm{Rx}^\mathrm{ana} = N_r\,P_\mathrm{LNA} + N_r\,P_\mathrm{PS}
      + P_\mathrm{LO} + P_\mathrm{Mix} + 2P_\mathrm{ADC}
$$

The two PS types give different parameters:

| | **active (VM)** | **passive (RTPS)** |
|---|---|---|
| $P_\mathrm{PS}$ | ≈ 20 mW, independent of $f_c$, $B$, $b$ | 0 |
| $L_\mathrm{PS}$ | 1 (≈ 0 dB gain) | Table 2.4 |
| Tx penalty $\kappa_\mathrm{Tx}$ | 1 | $1 + (L_\mathrm{PS}-1)/G_\mathrm{PA}$ |
| Rx penalty (added to $L_\mathrm{dB}$) | 0 dB | $\Delta_\mathrm{Rx} = 10\log_{10}\!\left(1 + \dfrac{L_\mathrm{PS}-1}{G_\mathrm{LNA}\,F_\mathrm{LNA}}\right)$ |

### 2.3 Where the passive penalties come from

- **Tx.** The loss sits before the PA, so the PA input drive must rise by
  L_PS. A driver stage makes up the extra (L_PS−1)·P_T/G_PA of RF power at
  efficiency η. With η equal to the PA's PAE, the driver adds a fraction
  (L_PS−1)/G_PA to the PA term. This follows the dissertation's (4.3), which neglects P_in only because
  P_in ≪ P_out. **G_PA = 20 dB is an assumption.** The dissertation says only
  that the gain is "sufficiently high and relatively constant" (Sec. 4.2.3).
- **Rx.** Friis gives F = F_LNA + (L_PS−1)/G_LNA. The framework's link budget
  uses N₀ = kT without a noise figure (`qamGear.m`: `P_t = SNR·N_0·B`), so only
  the *relative* rise F/F_LNA enters, as extra path loss in dB. G_LNA = 32 and
  F_LNA = 3 are the values in `lnaPower.m`.
- **Alternative (Dutta et al. TWC 2020; Skrimponis et al. 2020):** compensate
  the loss with LNA gain, G → G·L_PS. With their P = G/(FoM·(F−1)) this
  multiplies P_LNA by L_PS, so a passive PS costs about 10 mW per element at
  28 GHz instead of about 0. See `LNA_POWER_MODEL.md` §4. Run both variants.

### 2.4 Parameters per carrier (defaults in `phaseShifterParams.m`)

| f_c | P_PS (active) | L_PS (passive) | Δ_Rx | κ_Tx |
|---|---|---|---|---|
| 2.4 GHz | 20 mW ⚠ no verified active datum at 2.4 GHz; value carried over | 6 dB [14] | 0.13 dB | 1.03 |
| 8 GHz | 16.6 mW [10] | 11 dB (mid of 8–14 dB) [15] | 0.50 dB | 1.12 |
| 28 GHz | 20 mW (14.4–25.2 mW [11,12]) | 9.5 dB [9] | 0.34 dB | 1.08 |
| 60 GHz | 19.8 mW [13] | 9.9 dB [9] | 0.38 dB | 1.09 |

### 2.5 Resolution: array-gain loss from phase quantization

With b bits, the phase error is uniform on ±π/2^b. For independent errors
across elements (the phases of a steered array are spread), the expected
array gain is

$$
G(N,b) = 1 + (N-1)\,\kappa_q(b), \qquad
\kappa_q(b) = \left(\frac{\sin(\pi/2^b)}{\pi/2^b}\right)^{2}.
$$

| b | 1 | 2 | 3 | 4 | 6 |
|---|---|---|---|---|---|
| κ_q | −3.92 dB | −0.91 dB | −0.22 dB | −0.06 dB | −0.004 dB |

In the framework, `linkBudgetDb` would then subtract
10·log10(G(N_t,b)·G(N_r,b)) instead of 10·log10(N_t·N_r). This is a
self-derived standard result, so check it against a textbook before citing.

Since P_PS does not depend on b (§1.3), **b is free**: pick b = 6 and the
quantization loss is negligible. Only switched passive PS turn b into a real
trade-off, because they add ~1–4 dB loss per bit.

---

## 3. What this means before running anything

At 28 GHz, compare the cost of **one extra antenna element** per side with the
framework's own numbers:

| | per extra Rx element | per extra Tx element |
|---|---|---|
| digital BF (today's `"beamforming"` mode) | P_Mix + P_LNA + 2P_ADC = 8.4 mW + ADC + LNA | P_Mix + 2P_DAC = 8.4 mW + DAC |
| analog, active PS | P_LNA + **20 mW** | **20 mW** |
| analog, passive PS | P_LNA + 0 (+0.34 dB loss) | 0 (+8 % on the PA term) |

- **Active PS vs. digital BF:** an active PS costs more than a mixer
  (8.4 mW) at 28 GHz. Analog BF with active PS beats digital BF only when
  the converters are expensive, i.e. at large B or high bit counts.
- **Passive PS:** almost free in this framework. The array gain is then
  close to free, so the break-even logic of the beamforming paper
  (Proposition 1) shifts clearly toward larger arrays.
- **Caveat 1:** "passive ≈ free" holds only under the Friis penalty. Under
  gain compensation (see §2.3) it costs about as much as an active PS.
- **Caveat 2:** the framework's LNA power scales with B. At high rates this
  is in line with other system papers, but at low rates it goes to about 0,
  which flatters large receive arrays (details in `LNA_POWER_MODEL.md`).

**Recommendation:** implement both PS types as a scenario switch
(`scenario.phaseShifter = "active" | "passive"`). Report both, because the
answer to "analog vs. digital" depends on it. Use 20 mW as the active
default. The system-level values of 2 mW [5,6] and 30–40 mW [1,4] bracket it
and serve as a sensitivity range.

## 3a. Which type is used in practice (research 2026-10-02)

**Neither type dominates.** Passive, active and LO-path phase shifting all
appear in published 28 GHz arrays and in products.

| Design | Phase shifting | Source | Checked |
|---|---|---|---|
| ADI ADMV4828 (24–29.5 GHz, 16 channels) and ADAR1000 (8–16 GHz, 4 channels), commercial | **active**, 6-bit vector modulator | ADI product pages | search excerpt only; the datasheets could not be downloaded |
| IBM/Ericsson, 32 elements, 130 nm SiGe (Sadhu et al., JSSC 2017) | **passive**, bidirectional RF phase shifter shared by TX and RX, followed by a phase-invariant VGA | abstract | abstract |
| Samsung, 2×4 array, 28 nm CMOS (Kim et al., JSSC 2018) | **passive**, 3-bit switched L-C, 8–9 dB loss | ResearchGate summary | search excerpt only |
| Bhatta et al., Sensors 2023, 65 nm CMOS | **passive**, 6-bit switched filter ("high linearity and lack of DC power consumption") | paper | page read |
| Park et al., JSSC 2023, 65 nm CMOS | **active**, dual-vector variable-gain phase shifter | comparison table in Bhatta et al. | table |
| Pang et al. (Tokyo Tech), JSSC 2019, 65 nm CMOS | **LO-path** phase shifting | comparison table in Bhatta et al. | table |
| Qualcomm (Dunworth et al., ISSCC 2018) and UCSD (Kibaroglu et al., JSSC 2018) | not established | – | search excerpts were contradictory or silent |

What the pattern shows:

- **Commercial beamformer ICs lean active.** A vector modulator gives phase
  and gain control in one block and needs no separate loss compensation.
  Confirmed here only for the two ADI parts.
- **Passive is common where linearity and TDD sharing matter.** A passive
  phase shifter is bidirectional, so one unit serves TX and RX. An active one
  is unidirectional and is needed twice.
- **A passive phase shifter is never used alone.** Every design above puts
  gain stages around it. The whole beamformer channel then draws
  **about 50–300 mW** per channel (Bhatta 181/181 mW TX/RX, Park 73 mW TX,
  Pang 299/148 mW, Kim about 85/50 mW; all including PA or LNA), whatever
  the phase-shifter type.

**Consequence for the model.**

- "Passive = 0 mW plus a small Friis penalty" (§2.3) is a lower bound that no
  real design reaches. The gain-compensation variant (Dutta, Skrimponis) is
  closer to practice.
- The per-channel totals suggest that the choice between active and passive
  matters less than the fixed per-channel overhead of a beamformer channel.
- Default stays **active, 20 mW per element** (matches the commercial parts
  and is the simpler model). Passive is run with gain compensation as the
  comparison case, and passive with the Friis penalty only as the optimistic
  bound.

## 4. Not covered

- LO-path and IF phase shifting. These need one mixer per element, so they
  cost N·P_Mix rather than N·P_PS (classification in Poon & Taghivand, Proc.
  IEEE 2012, cited in [1]; not read).
- True-time-delay units (relevant at large B·N, see `BeamfocussingGearbox/`).
- Splitter/combiner excess loss, and the gain and phase error of real PS.
- The phase-shifter control and calibration overhead.

---

## Sources

1. R. Méndez-Rial, C. Rusu, N. González-Prelcic, A. Alkhateeb, R. W. Heath, "Hybrid MIMO architectures for millimeter wave communications: Phase shifters or switches?", IEEE Access, vol. 4, pp. 247–267, 2016. [arXiv:1512.03032](https://arxiv.org/pdf/1512.03032)
2. W. bin Abbas, F. Gómez-Cuba, M. Zorzi, "Millimeter wave receiver efficiency: A comprehensive comparison of beamforming schemes with low resolution ADCs", [arXiv:1607.03725](https://arxiv.org/abs/1607.03725)
3. L. N. Ribeiro, S. Schwarz, M. Rupp, A. L. F. de Almeida, "Energy efficiency of mmWave massive MIMO precoding with low-resolution DACs", IEEE JSTSP, vol. 12, no. 2, 2018. [arXiv:1709.05139](https://arxiv.org/abs/1709.05139)
4. V. N. Ha, D. H. N. Nguyen, J.-F. Frigon, "System energy-efficient hybrid beamforming for mmWave multi-user systems", [arXiv:2001.05439](https://arxiv.org/html/2001.05439)
5. K. Roth, H. Pirzadeh, A. L. Swindlehurst, J. A. Nossek, "A comparison of hybrid beamforming and digital beamforming with low-resolution ADCs for multiple users and imperfect CSI", IEEE JSTSP, 2018. [arXiv:1709.09047](https://arxiv.org/pdf/1709.09047). Power model: K. Roth, J. A. Nossek, JSAC 2017, [arXiv:1610.02909](https://arxiv.org/pdf/1610.02909)
6. W. bin Abbas, F. Gómez-Cuba, M. Zorzi, "Millimeter wave receiver comparison under energy vs spectral efficiency trade-off", [arXiv:1811.12811](https://arxiv.org/pdf/1811.12811)
7. "Dynamic hybrid precoding relying on twin-resolution phase shifters in millimeter-wave communication systems", [arXiv:2011.12475](https://arxiv.org/pdf/2011.12475)
8. L. Yan, C. Han, N. Yang, J. Yuan, "Dynamic-subarray with fixed phase shifters for energy-efficient terahertz hybrid beamforming under partial CSI", [arXiv:2203.15338](https://arxiv.org/pdf/2203.15338)
9. A. Basaligheh, P. Saffari, S. Rasti Boroujeni, I. Filanovsky, K. Moez, "A 28–30 GHz CMOS reflection-type phase shifter with full 360° phase shift range", IEEE TCAS-II, 2020. [PDF](http://www.ece.ualberta.ca/~kambiz/papers/J38.pdf)
10. K. Kibaroglu, E. Ozeren, I. Kalyoncu, C. Caliskan, H. Kayahan, Y. Gurbuz, "An X-band 6-bit active phase shifter". [PDF](https://research.sabanciuniv.edu/id/eprint/28050/1/An_X-band_6-Bit_Active_Phase_Shifter.pdf)
11. "A compact vector-sum phase shifter for 5G applications in 22 nm FD-SOI CMOS". [ResearchGate](https://www.researchgate.net/publication/346251048_A_Compact_Vector-Sum_Phase_Shifter_for_5G_Applications_in_22_nm_FD-SOI_CMOS)
12. "A 28GHz CMOS phase shifter supporting 11.2Gb/s in 256QAM with an RMS gain error of 0.13dB for 5G mobile network". [ResearchGate](https://www.researchgate.net/publication/329494635_A_28GHz_CMOS_Phase_Shifter_Supporting_112Gbs_in_256QAM_with_an_RMS_Gain_Error_of_013dB_for_5G_Mobile_Network)
13. Y. Yu et al., "A 60-GHz 19.8-mW current-reuse active phase shifter with tunable current-splitting technique in 90-nm CMOS", IEEE TMTT, vol. 64, no. 5, pp. 1572–1584, 2016 (cited as [3] in [9]).
14. pSemi PE44820, 8-bit RF digital phase shifter, 1.7–2.2 GHz. [Product page](https://psemi.com/products/rf-phase-amplitude-control/phase-shifters/pe44820/)
15. L. Chen, X. Chen, Y. Zhang, Z. Li, L. Yang, "A high linearity X-band SOI CMOS digitally-controlled phase shifter", J. Semicond., vol. 36, no. 6, 2015. [Link](https://www.jos.ac.cn/article/doi/10.1088/1674-4926/36/6/065004)
16. H. Shen et al., "A 90–100 GHz SiGe BiCMOS 6-bit digital phase shifter with a coupler-based 180° unit for phased arrays", Micromachines, 2025. [PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC12471876/)
