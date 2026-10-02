# ADC power model: envelope vs. 5 % quantile

Status 2026-10-02. Switch: `makeScenarioConfig('adcPowerModel', "envelope" | "quantile5")`.
Default `"envelope"` is byte-identical to every existing result.

## What the framework computes

`+physics/adcPower.m` implements Gast, eq. (4.8), for the I/Q pair:

    P = 2 * c_ADC * 2^b * B * sqrt(1 + (B/f_b)^2),   f_b = 560 MHz

with Nyquist-rate sampling (f_s = B) and effective bits equal to nominal bits.

| Model | c_ADC | Meaning |
|---|---|---|
| `"envelope"` | 0.67 fJ (scenario `c_ADC`) | best-case envelope of the Murmann ADC survey (Gast, eq. 4.7) |
| `"quantile5"` | 3.17 fJ | 5 % quantile of the same survey in the band the Gearbox uses |

The switch only replaces the constant (`+physics/adcConstant.m`, applied in
`+sweep/resolveScenarioForCarrier.m`). `f_b` and the formula are unchanged, so the ADC power
is 4.73 times higher at every bandwidth and resolution. `"quantile5"` replaces a hand-set
`c_ADC`; do not combine the two.

## Why a second value

Checked against the Murmann survey, rev. 2026-08-01 (705 ADCs with power, Nyquist rate and
SNDR; data and script in `LituratureReview/adc_survey/`). Ratio = measured power / model
power at the ADC's own sampling rate and ENOB, for f_s = 1 MHz .. 2 GHz and designs since
2015 (n = 176):

| | measured / envelope model |
|---|---|
| best ADC | 2.1 |
| 5 % quantile | 4.7 |
| median | 26 |

- The envelope is built by the survey's author from the five best points over ALL speeds.
  Those are very slow (< 1 MS/s) and very fast (> 10 GS/s) converters. In between, no ADC
  reaches it.
- The 5 % quantile follows the method used for the LNA (`LNA_POWER_MODEL.md`): a very good
  design that exists, not the single best point.
- For 5-9 effective bits, the range QAM uses with b = log2(sqrt(M)) + 3, the best designs are
  5.4 to 8 times above the envelope (20 designs), so 4.7 is on the low side there.

## Limits

- No ADC below 5 ENOB under 2 GS/s since 2015 is in the survey. For the 1-bit gears (ZXM,
  pulse) the 2^b scaling is an extrapolation under either model.
- Oversampling for the anti-alias filter is not modelled.
- Untested on the HPC: no sweep has been run with `"quantile5"` yet.
