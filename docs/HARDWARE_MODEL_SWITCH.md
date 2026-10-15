# Hardwaremodelle: Standards und Sammelschalter `hardwareModel`

## Entscheidungen vom 2026-10-15

Für jedes Bauteilmodell mit mehreren Optionen wurde eine als Standard
festgelegt. Die anderen Optionen bleiben wählbar.

| Modell | Schalter | Standard ab 2026-10-15 | bis dahin (Dissertation) | Herleitung |
|---|---|---|---|---|
| LNA | `lnaPowerModel` | `fom_floor`: Formel der Dissertation, Bandbreite nach unten auf 0,05·f_c begrenzt | `fom_bandwidth` | `LNA_POWER_MODEL.md` |
| ADC | `adcPowerModel` | `quantile5`: 3,17 fJ je Umsetzschritt | `envelope`: 0,67 fJ | `ADC_POWER_MODEL.md` |
| DAC | `dacPowerModel` | `survey`: 1,2 µW je LSB + 0,25 pJ je Bit und Abtastwert | `analytic`: 3 V, 10 µA, 0,5 pF | `DAC_POWER_MODEL.md` |
| LO-Verteilung | `loDistributionModel` | `per_mixer`: LO-Puffer je weiterem Mischer, 3 / 7 / 12,5 / 10 mW bei 2,4 / 8 / 28 / 60 GHz | `shared`: ein LO je Seite | `ANALOG_BEAMFORMING.md`, `LO_POWER_MODEL.md` |
| Bandbreite | `bandwidthModel` | `channel`: ein Kanal, 20 MHz / 100 MHz / 400 MHz / 2,16 GHz bei 2,4 / 8 / 28 / 60 GHz | `eta`: B_max = 0,1·f_c | `+physics/channelBandwidth.m` |
| PA | `paPowerModel` | `constant` (unverändert) | `constant` | `PA_POWER_MODEL_DECISION.md` |
| Phasenschieber | `psType` | **kein Standard**: alle drei Varianten (`active`, `passive_compensated`, `passive_penalty`) werden weiter betrachtet | – | `PHASE_SHIFTER_POWER_MODEL.md` |

`P_LO` selbst wurde gegen die Literatur geprüft und nicht geändert
(`LO_POWER_MODEL.md`). Technisch bekommt ein Aufruf ohne `psType` weiterhin
`"active"`; das ist keine Festlegung.

Hinweise zu den Festlegungen:

- **Bandbreite:** Für andere Träger als 2,4 / 8 / 28 / 60 GHz gibt es keine
  Kanalbandbreite; ein Lauf dort bricht mit `gearboxphy:channelBandwidth` ab
  (dann `bandwidthModel="eta"` oder `B_maxByCarrier` setzen). Eine
  nichtleere `B_maxByCarrier`-Tabelle hat Vorrang vor `bandwidthModel`.
- **LNA und Bandbreite zusammen:** Die Untergrenze 0,05·f_c (120 MHz /
  400 MHz / 1,4 GHz bei 2,4 / 8 / 28 GHz) liegt über den Kanalbandbreiten.
  Der LNA wird also immer für mindestens 0,05·f_c bezahlt, auch wenn das
  Signal schmaler ist.
- **LO-Verteilung:** wirkt nur, wo eine Seite mehr als einen Mischer hat
  (digitale Arrays). SISO und analoges Beamforming bleiben unberührt. Der
  Pufferwert lässt sich mit `loDistPowerPerMixer` überschreiben.

## Alte Ergebnisse und bestehende Studien

Alle Ergebnisse vor dem 2026-10-15 sind mit dem Modellsatz der Dissertation
gerechnet. Jede Studie, die es zu dem Zeitpunkt gab, baut ihr Szenario
deshalb mit dem alten Satz, damit ihre gespeicherten Ergebnisse gültig und
fortsetzbar bleiben:

```matlab
oldModels = gearboxphy.sweep.oldModelArgs();
s = gearboxphy.sweep.makeScenarioConfig(oldModels{:}, 'distance', 50, ...);
```

`oldModelArgs` steht vorne; bei doppelt übergebenen Namen gilt in
`makeScenarioConfig` der letzte, sodass die Schalter, die eine Studie selbst
setzt (z. B. `lnaPowerModel` in der LNA-Studie), weiterhin gewinnen.

Festgenagelt: `run_sweep.m`, `studies/beamforming/*`,
`studies/mimo_comparison/*`, `studies/lna/*`, `studies/common/bf_arch_scenario.m`
(damit `analog_bf` und `digital_bf_dac`), `studies/dac_power_model/*`, dazu
die Regressionstests (Golden Master, `GearsTest`, `OperatingPointTest`,
`ResultStoreTest`). Wer eine dieser Studien mit den neuen Modellen rechnen
will, entfernt dort `oldModels{:}` und braucht einen neuen Ergebnisordner.

## Sammelschalter `hardwareModel`

```matlab
s = gearboxphy.sweep.makeScenarioConfig('hardwareModel', "old");
```

| `hardwareModel` | `lnaPowerModel` | `adcPowerModel` | `dacPowerModel` | `loDistributionModel` | `bandwidthModel` |
|---|---|---|---|---|---|
| `"custom"` (Standard) | wie übergeben, sonst Standard | wie übergeben | wie übergeben | wie übergeben | wie übergeben |
| `"old"` | `fom_bandwidth` | `envelope` | `analytic` | `shared` | `eta` |
| `"new"` | `fom_floor` | `quantile5` | `survey` | `per_mixer` | `channel` |

- Die Standards **sind** der Satz `"new"`; ein Aufruf ohne Schalter ist also
  gleich `hardwareModel="new"` (`HardwareModelTest` prüft, dass beide nicht
  auseinanderlaufen).
- `"old"` und `"new"` **schreiben** die fünf Einzelschalter. Das Szenario
  trägt danach die aufgelösten Werte; Gänge und
  `resolveScenarioForCarrier` lesen nur die Einzelschalter.
- **Widerspruch ist ein Fehler** (`gearboxphy:hardwareModelConflict`): wer
  `"old"` oder `"new"` wählt und einen Einzelschalter auf etwas anderes als
  den Wert der Voreinstellung oder den Standard stellt, bekommt eine
  Fehlermeldung. Zum Mischen `"custom"` nehmen (oder `oldModelArgs` plus
  einzelne Schalter).
- Ein Einzelschalter, der ausdrücklich auf seinen Standardwert gesetzt wird,
  ist von „nicht gesetzt“ nicht zu unterscheiden und wird von `"old"`
  überschrieben.
- `quantile5` ersetzt `c_ADC`, `survey` die drei DAC-Konstanten; von Hand
  gesetzte Werte dafür brauchen `adcPowerModel="envelope"` bzw.
  `dacPowerModel="analytic"`.

## Stand

- 2026-10-15: Standards umgestellt, bestehende Studien festgenagelt.
  Unit-Suite 112/112.
- `studies/hardware_models/` vergleicht in der SISO-Gearbox `old` gegen
  `new` und je eine Festlegung allein (`lna_only`, `adc_only`, `dac_only`,
  `bw_only`); der HPC-Lauf steht aus.
- Der Modellsatz `hw_new` in `studies/digital_bf_dac/` ist älter als diese
  Entscheidungen (LNA `envelope`, ADC `quantile5`, DAC `survey`, LO als
  eigene Achse, B_max = 0,1·f_c) und entspricht NICHT `"new"`.
