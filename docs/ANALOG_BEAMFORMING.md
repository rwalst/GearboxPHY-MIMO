# Analog beamforming in the QAM gear

Status 2026-10-08. Switch: `makeScenarioConfig('beamformingArch', "digital" | "analog")`.
Default `"digital"` is byte-identical to every existing result. QAM gear only; every other
gear refuses a multi-antenna analog request (`+physics/assertDigitalArch.m`).

Background: `PHASE_SHIFTER_POWER_MODEL.md` (phase-shifter survey), `ADC_POWER_MODEL.md`.

## Architecture

    Tx:  2 x DAC -> mixer -> split 1:N_t -> [PS -> PA] -> antenna
    Rx:  antenna -> [LNA -> PS] -> combine N_r:1 -> mixer -> 2 x ADC

| Per side | digital | analog |
|---|---|---|
| DAC / ADC pairs | N | 1 |
| mixers | N | 1 |
| PAs, LNAs | N | N |
| phase shifters | 0 | N (none for N = 1) |
| LO | 1 | 1 |

Splitter and combiner are ideal. With one antenna per side both architectures are the same
link, so N = 1 is bit-identical in every variant.

## Phase-shifter variants (`psType`)

| `psType` | DC power per element | Transmit side | Receive side |
|---|---|---|---|
| `"active"` | `psPower` (28 GHz default 20 mW) | none | none |
| `"passive_penalty"` | 0 | PA term x (1 + (L-1)/G_PA) | link budget + 10 log10(1 + (L-1)/(G_LNA F_LNA)) |
| `"passive_compensated"` | 0 | as above | LNA power x L, and the small remaining Friis term with G_LNA L |

L is `psLossDb` (28 GHz default 7.5 dB). G_PA = 20 dB is an assumption; G_LNA = 32 and
F_LNA = 3 are the values of `lnaPower.m`. In `"passive_compensated"` the LNA power is taken
as proportional to its gain. That is exact for the dissertation's LNA formula and an
assumption under the survey-envelope LNA model.

`"passive_penalty"` is the optimistic bound: no measured beamformer channel reaches it.

## Phase quantisation (`psBits`)

Phase errors uniform on +-pi/2^b and independent across elements reduce the mean array power
gain from N to

    G(N, b) = 1 + (N - 1) * (sin(pi/2^b) / (pi/2^b))^2 .

The loss N/G enters the link budget once per side with more than one element. Default
`psBits = 6` makes it negligible; `Inf` switches it off.

Checked 2026-10-08:

- Derivation: with unit-modulus weights and total power 1 the gain is |sum_n e^{j phi_n}|^2 / N.
  Its mean is 1 + (N-1) |E e^{j phi}|^2, and E e^{j phi} = sin(D)/D for phi uniform on +-D,
  D = pi/2^b (half a quantisation step).
- Monte Carlo with independent uniform errors (200 000 draws, N = 2..64, b = 1..4) reproduces
  the formula to 0.003 dB.
- For large N it tends to the sinc^2 quantisation loss: 3.92 dB at 1 bit, 0.91 dB at 2 bit,
  0.22 dB at 3 bit, 0.06 dB at 4 bit.
- Against a real quantiser (ideal steering phases of a half-wavelength ULA rounded to the
  grid, mean over steering angles) the formula is slightly pessimistic, because the errors of
  a steered array are not independent: by up to 1.1 dB at 1 bit (N = 4), 0.24 dB at 2 bit,
  0.05 dB at 3 bit. The worst single direction is worse than the formula by 0.2 dB at 2 bit
  and 0.06 dB at 3 bit.
- It is the loss of the MEAN SNR over steering angles, not of one beam direction, and it is
  applied on both sides independently.

## Where the array gain comes from: two cases

**Case 1, rank-1 channel (LOS), ideal phases.** After analog combining there is a scalar AWGN
channel behind ONE ADC. The spectral efficiency is the quantised SISO curve and the array
contributes a gain of N_t N_r. Use `antennaMode = "beamforming"` with a data folder whose
1x1 curves are SISO-AWGN with the wanted ADC rule: `SE_data_bfideal_fixedB`
(b = 1/2 log2 M + 3). No new curves are needed. `validate_analog_bf` B3 shows that this route
gives exactly the energy of the existing `bfideal_fixedB` curves.

The `scaledB` rule (one more bit per doubling of N) makes no sense here: there is one ADC and
its input is already combined.

**Case 2, Rayleigh or Rice channel, phase-only weights.** The gain is random and smaller than
that of digital eigen-beamforming. The curves come from
`QuantizedMimoMI/qam/sweep/runQamSweepBfAnalog.m`:

    I(SNR_total) = E_H[ I_SISO( SNR_total * g(H) ) ],   g = |w_r^H H w_t|^2,

with unit-modulus weights from an alternating optimisation (`qam/core/analogBfGain.m`) and an
ADC whose drive level follows each realisation. The curves contain the array gain, so the gear
runs in `antennaMode = "multiplexing"` (one curve per antenna configuration) with
`analogCurvesCarryArrayGain = true`. Mean gains found in the validation (2000 draws):

| N x N | analog, phase only | digital eigen-BF, E[lambda_max] | ideal N^2 |
|---|---|---|---|
| 2 x 2 | 4.55 dB | 5.38 dB | 6.02 dB |
| 4 x 4 | 8.76 dB | 9.91 dB | 12.04 dB |
| 8 x 8 | 12.54 dB | 13.75 dB | 18.06 dB |

Phase quantisation is applied in the link budget in both cases, with the formula above. For
case 2 that is an approximation (the formula assumes a fully coherent sum).

## Study

`studies/analog_bf/`, runbook `docs/HPC_RUNBOOK_ANALOG_BF.md`.

## Limits

- QAM only. ZXM and the pulse gears have no analog variant.
- Splitter and combiner losses, phase-shifter amplitude errors and beam squint are not
  modelled.
- The alternating optimisation finds a local maximum; the case-2 curves are achievable rates,
  not an upper bound for phase-only beamforming.
- LO distribution: see the next section. By default it costs nothing, which favours the
  digital side.

## LO distribution (`loDistributionModel`)

A digital array has one mixer per antenna and each needs the LO. An analog array has one
mixer per side.

| `loDistributionModel` | LO power per side |
|---|---|
| `"shared"` (default) | P_LO, whatever the number of mixers (as in the dissertation) |
| `"per_mixer"` | P_LO + (number of mixers - 1) x `loDistPowerPerMixer` |

The first mixer is covered by P_LO, so SISO and analog arrays are unchanged. The switch acts
in the QAM, NA-QAM and ZXM gears (`+physics/loDistributionPower.m`).

Default per additional mixer: 16.6 mW at 28 GHz, the measured two-stage LO buffer per path of
Pang et al., JSSC 2019 (Table II). That is the buffer alone; the complete LO chain per path
of that LO-phase-shifting transceiver draws about 89 mW. Other carriers have no default and
need `loDistPowerPerMixer` set by hand.

Evidence collected 2026-10-08 (papers in `LituratureReview/lo_distribution/`, Khanna et al.
in `LituratureReview/ps_survey/tmp_rtps/ucla2026.txt`):

| Source | What it is | LO cost per additional downconversion chain |
|---|---|---|
| Pang et al., JSSC 2019 | 65 nm CMOS, 28 GHz, one mixer per path; measured | 16.6 mW (two-stage LO buffer per path) |
| Khanna et al., JSSC 2026; Razavi, OJ-SSCS 2025 | 28 nm CMOS, 28 GHz, central 56 GHz synthesizer feeding two I/Q downconverters over 600 um; measured | 12.5 mW (25 mW of repeater inverters for two I/Q downconverters) |
| Wang & Razavi (per Razavi 2025) | 28 nm CMOS, 28 GHz, one synthesizer PER ELEMENT instead of distribution; measured | about 4 mW (VCO stacked with the LNA 2.5 mW, rest of the PLL 1.5 mW); only the 250 MHz reference is distributed |
| Dutta et al., "A case for digital beamforming at mmWave", arXiv:1901.08693 | system-level model | 10 mW (P_LO = 10 dBm per baseband stream, N streams for digital) |
| LaCaille et al., arXiv:1911.01339 | model of LO distribution in a 128-element 75 GHz array | no per-element figure; distribution power grows with array size through routing and splitter loss, optimum is one PLL per subarray of about 32 elements |

So two measured 28 GHz designs give 12.5 and 16.6 mW per additional chain, a system-level
paper assumes 10 mW, and a per-element synthesizer reaches about 4 mW. The default of
16.6 mW is at the upper end of this range; 4 to 17 mW is the range to scan. None of the
measured designs is a fully digital array: Pang shifts the phase in the LO path, Khanna
combines four elements at RF before each downconverter.

Open points are collected in `studies/analog_bf/TODO.md`.
