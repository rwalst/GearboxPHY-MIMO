# Studie: digitales Beamforming mit endlicher DAC-Aufloesung

Frage: was kostet es das digitale Beamforming, dass jeder DAC ein gedrehtes und skaliertes
QAM-Symbol darstellen muss -- und wie stark haengt die Antwort am DAC-Leistungsmodell?

Die analogen Varianten laufen hier nur als Vergleich mit; die Studie dazu ist
`studies/analog_bf/`.

## Dateien

| Datei | Zweck |
|---|---|
| `export_dbf_dac_curves.m` | MI-Kurven mit DAC-Quantisierung aus QuantizedMimoMI nach `data/` |
| `run_dbf_dac_distance.m` | Distanz-Sweep: je Kanal, LO-Fall und DAC-Leistungsmodell; Minimum ueber die DAC-Stufen |
| `run_dbf_dac_los_newhw.m` | derselbe Sweep, nur Kanal `losd`, fuer zwei Modellsaetze: Dissertation (`analytic`) und survey-gestuetzt (`hw_new`: LNA `envelope`, ADC `quantile5`, DAC `survey`) |
| `../common/bf_arch_scenario.m` | Szenario einer Variante, gemeinsam mit `analog_bf` |

Im Framework: `qamGear` bezahlt `sourceBdac` (DAC-Bit der Kurve), Schalter `dacPowerModel`
(`+physics/dacConstants.m`), `+sweep/minOverDacLevels.m`, Tests `tests/+unit/DacModelTest.m`.
In QuantizedMimoMI: `qam/core/dacQuantize.m`, `runQamSweepBfLosDigitalDac`,
`runQamSweepBfIdealDac`, `runQamSweepBfRayleighDac`, `validateBfDac`.

## Dokumente

- `docs/DAC_QUANTISATION_SPEC.md` -- Modell, Entscheidungen, Ergebnisse der MI-Kurven
- `docs/dac_quantisation_math/dac_quantisation_math.pdf` -- das Vorgehen mathematisch
- `docs/DAC_POWER_MODEL.md` -- die drei DAC-Leistungsmodelle
- `docs/HPC_RUNBOOK_DAC.md` -- Ablauf auf dem HPC

## Kanaele und Datenordner

| Kanal | digitale Seite | Empfaenger |
|---|---|---|
| `losd` | `SE_data_bflosd_fixedB[_dac<k>]` | Rang 1, ein ADC je Empfangsantenne |
| `los` | `SE_data_bfideal_fixedB[_dac<k>]` | Rang 1, Kombinieren vor EINEM ADC (analoger Empfaenger) |
| `ray` | `SE_data_bf_fixedB[_dac<k>]` | Rayleigh, ein ADC je Empfangsantenne |

`_dac<k>`: DAC mit `1/2*log2(M) + k` Bit; `_common`: gemeinsame Aussteuerung aller Antennen.

## Ergebnisse

`results/dbfdac_distance_<kanal>_<lo>_<dacModell>.mat` (digital) und
`results/abfdac_distance_<variante>_<dacModell>.mat` (analog zum Vergleich).

## Stand 2026-10-12

- Alle MI-Kurven liegen vor und sind geprueft (LOS mit einem ADC, LOS mit ADC je Antenne,
  Rayleigh).
- Der Distanz-Sweep ist NICHT gelaufen.

## Offen

- [ ] **Deckeln?** Im Rayleigh-Kanal liegt die Kurve mit +0 Bit fuer M >= 64 und N >= 4 UEBER
      der mit idealem DAC (bis 0.10 bit): der Rundungsfehler traegt Information in die
      uebrigen Eigenmoden, und der Empfaenger im Modell nutzt sie. Zu entscheiden: die
      exportierten Kurven am idealen DAC deckeln oder so lassen. Vor dem Export.
- [ ] Distanz-Sweep rechnen (`run_dbf_dac_distance`).
- [ ] Auswertung fuer `dbfdac_distance_*` (gibt es noch nicht).
- [ ] Mischform "Sender digital, Empfaenger analog" im Rayleigh-Kanal mit demselben Quantisierer.
- [ ] BF/MUX-Vergleich an `minOverDacLevels` anschliessen (braucht auch `scaledB`-Kurven).
- [ ] Ob `survey` Vorgabe des DAC-Leistungsmodells wird, ist nicht entschieden.
