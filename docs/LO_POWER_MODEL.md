# LO power model: check against published hardware

Checked 2026-10-13. Data, script and figure are outside this repository, in
`LituratureReview/lo_survey/` (`check_lo_model.py`, `lo_model_check.png`,
`pll_survey.csv`, `lo_chain_survey.csv`, `cited_sources_check.md`).
Nothing in the code was changed.

## What the framework uses

`+physics/bandHardwareParams.m`: one fixed `P_LO` per carrier and side, from
Table 4.1 of the dissertation. The dissertation defines the LO as core
oscillator + I/Q generator + driver amplifiers for I and Q, and states that
all four values are quadrature oscillators (sec. 5.3.3). Impulse radio pays
70 % of it (single-phase LO; one 60 GHz example, 20 mW against 60 mW).

| f_c | P_LO | Cited source | What the number covers | Read from |
|---|---|---|---|---|
| 2.4 GHz | 6 mW | Jin, Comput. Electr. Eng. 2014 | not found; the circuit is a free-running quadrature VCO, 0.18 um | abstract (no power figure) |
| 8 GHz | 14.9 mW | Teh, Zheng, Yeoh, ICUWB 2007 | quadrature VCO core only (8.3 mA at 1.8 V); no buffers, no PLL | abstract |
| 28 GHz | 26.9 mW | El-Halwagy et al., TMTT 2017 | complete two-stage fractional-N synthesizer with quadrature output (28 GHz QVCO alone 10.2 mW); external reference, no distribution, no mixer drivers | first author's PhD thesis |
| 60 GHz | 60 mW | Pinel et al., ISSCC 2008 | not found; the abstract only gives "below 200 mW" for the whole radio | abstract |

The four values do not measure the same thing (VCO core at 8 GHz, complete
synthesizer at 28 GHz), and none of the sources read includes the mixer
drivers of the dissertation's own definition. The 2.4 and 60 GHz values need
someone with full-text access.

## Against stand-alone PLLs and synthesizers

291 measured designs, 1.5-70 GHz, 2007-2026: 228 from the ETH Zurich EECIS
PLL Performance Survey (Davami and Jang, gitlab.ethz.ch/eecis/pll_survey,
MIT licence), 63 added by hand (44 from abstracts, 11 from comparison tables,
8 from full text).

| f_c (band) | Model | Median | 5 % quantile | n | Model / median | Designs below model |
|---|---|---|---|---|---|---|
| 2.4 GHz (2-3) | 6 mW | 4.3 mW | 0.9 mW | 44 | 1.4 | 61 % |
| 8 GHz (5-10) | 14.9 mW | 16.6 mW | 3.8 mW | 76 | 0.9 | 46 % |
| 28 GHz (20-40) | 26.9 mW | 23.7 mW | 10 mW | 45 | 1.1 | 58 % |
| 60 GHz (55-70) | 60 mW | 44 mW | 23 mW | 18 | 1.4 | 61 % |

- The model values sit in the middle of the distribution, 0.9 to 1.4 times
  the median. This is unlike the ADC (best-case envelope) and the DAC (about
  6 times too expensive).
- The frequency trend agrees: survey P = 2.9 mW (f/GHz)^0.69, the four model
  values 3.3 mW (f/GHz)^0.68. Scatter of the survey around its trend is a
  factor of 2.4 (rms).
- Caveats: reported power is almost always the PLL core without LO buffers,
  I/Q generation and reference oscillator. The dataset rows are designs
  optimised for the jitter figure of merit and were not checked against the
  papers. 60 GHz has 18 designs.

## Against LO generation inside complete transceivers

61 transceivers collected, only 20 with a complete LO total (synthesizer +
multipliers + I/Q generation + buffers). Scopes are mixed (per chip, per
element, per chain); many values are derived (current times supply, or read
from figures).

| f_c | Model | LO total: min / median / max | n | LO share of receiver power (median) |
|---|---|---|---|---|
| 2.4 GHz | 6 mW | 0.12 / 1.7 / 43 mW | 9 | 48 % |
| 8 GHz | 14.9 mW | 240 / 253 / 266 mW | 2 | (not usable) |
| 28 GHz | 26.9 mW | 9 / 38 / 130 mW | 3 | 23 % |
| 60 GHz | 60 mW | 30 / 76 / 270 mW | 5 | 51 % |

- 2.4 GHz is set by the power class, not by frequency: Bluetooth LE radios
  0.1-0.5 mW, 0.18 um ZigBee 6-6.5 mW, WLAN-class 41-43 mW. 6 mW is a
  ZigBee-class LO.
- 28 and 60 GHz: the whole LO costs about 1.3 to 1.4 times the model value in
  the median, with few data points. Distribution is half or more of the LO
  power where a split is given (79 % in Khanna/Razavi, 40-66 % at 60 GHz).
- 8 GHz: the two totals are a hopping UWB synthesizer and a 2008 array
  element; no conclusion.

## The jitter-power model of chapter 6 (not used in the framework)

`P_LO >= P_VCO + P_REF`, eq. (6.5)/(6.6) after Razavi 2021, with Q = 10,
f_REF = 54 MHz, S_REF = S_CP = -160 dBc/Hz: 92 / 6.0 / 0.56 mW at 50 / 100 /
200 fs.

- It is not a lower bound for measured PLLs: 82 of 110 designs below 100 fs
  need less power than the model. With each design's own reference frequency
  (median 100 MHz; the model scales with 1/f_REF^2) 30 of 109 still do.
- Above 100 fs it is far below the measurements (median factor 13, above
  300 fs factor 30).
- Model slope sigma^-4, survey about sigma^-0.4. Reported jitter is
  integrated over different bands, so this comparison is coarse.

## Conclusion

- The fixed `P_LO` values are typical published PLL cores and need no
  correction of the kind the ADC and DAC did. Measured against the
  dissertation's own definition (including I/Q generation and mixer drivers)
  they are low by roughly a factor of 1.3 to 1.4 at 28 and 60 GHz; the
  evidence for that is 3 and 5 designs.
- Possible change, not built: replace the four single-source values by the
  survey trend 2.9 mW (f/GHz)^0.69 (differences: -12 % / -19 % / +6 % / -19 %
  at 2.4 / 8 / 28 / 60 GHz), which removes the mixed definitions but changes
  results little.
- The larger open item is the LO distribution to several mixers
  (`loDistributionModel`, docs/ANALOG_BEAMFORMING.md), not `P_LO` itself.
- The 70 % rule for impulse radio rests on one example and was not checked
  here.
