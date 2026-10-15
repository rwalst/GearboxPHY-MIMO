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

## Alle Studien rechnen mit den neuen Modellen (seit 2026-10-15)

Nutzerentscheidung: alle Untersuchungen rechnen ausschliesslich mit dem
neuen Satz. Die rechnenden Treiber (`run_sweep.m`, `studies/beamforming/*`,
`studies/mimo_comparison/*`, `studies/lna/*`, `studies/common/bf_arch_scenario.m`
und damit `analog_bf` und `digital_bf_dac`, `studies/dac_power_model/*`)
uebergeben keinen alten Modellsatz mehr, und ihre eigenen Rueckfaelle auf
alte Modelle sind entfernt:

- `bf_arch_scenario`: ohne `dacModel`/`lnaModel`/`adcModel` gilt der
  Standard (vorher `analytic`/`fom_bandwidth`).
- `run_dbf_dac_distance`: `P.ADC_MODEL = "quantile5"`, und die Saetze
  `analytic`/`analytic_1V`/`survey` nehmen den Standard-LNA `fom_floor`.
  `hw_new` ist dort jetzt „Standard mit LNA `envelope`“, NICHT `"new"`.
- `run_mimo_comparison_distance`: `LO_MODEL = "per_mixer"` (der gemeinsame
  LO bleibt als Option).
- LNA-Studie: der Fall `eta01` setzt `bandwidthModel="eta"` ausdruecklich,
  sonst waere er still zur Kanalbandbreite geworden.

Was eine Modellvergleichsstudie ausdruecklich variiert (LNA-Modelle in
`lna`, DAC-Modelle in `dac_power_model` und `digital_bf_dac`, ADC-Modelle in
`analog_bf`), bleibt so; alles andere ist neu.

**Alte Ergebnisse werden nicht weiterverwendet.** Bis zum 2026-10-15 hielt
`runSweep` eine Ergebnisdatei fuer fertig, wenn Raten, Distanz und
Antennenkonfigurationen passten - die Modelle zaehlten nicht, und
Checkpoints waren nur nach Index geordnet. Ein umgestellter Treiber haette
in seinem alten Ordner also alte Ergebnisse uebersprungen und halbe alte
Checkpoints weiterverwendet. Jetzt:

- `runSweep` ueberspringt nur, wenn zusaetzlich der gespeicherte
  `resultFingerprint` zum aktuellen passt (`+data/fingerprintMatches.m`).
  Dateien ohne Fingerabdruck gelten als veraltet.
- Checkpoints sind an den Fingerabdruck ihres Laufs gebunden
  (`+data/claimCheckpoints.m`); fremde werden mit Warnung verworfen.
- Die Distanz-Studien (MIMO-Vergleich, analoges BF, gemischtes BF,
  DAC-Studie) ueberspringen ebenfalls nur bei passendem Fingerabdruck.

Die alten Ergebnisse bleiben in `results/` liegen, bis der neue Lauf sie
ueberschreibt. Jede Studie muss neu gerechnet werden (HPC).

**Weiter mit dem alten Satz** (`gearboxphy.sweep.oldModelArgs()`), weil sie
den Code bitgenau gegen gespeicherte alte Ergebnisse pruefen: die
Regressionstests (Golden Master, `GearsTest`, `OperatingPointTest`,
`ResultStoreTest`) und die Regressionsteile von `validate_mimo_comparison`
und `validate_lna_comparison`. Ausserdem `studies/hardware_models/`, die alt
gegen neu vergleicht.

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

- 2026-10-15: Standards umgestellt; am selben Tag alle rechnenden Studien
  auf den neuen Satz umgestellt und die Ueberspring-Logik an den
  Fingerabdruck gebunden.
- `studies/hardware_models/` vergleicht in der SISO-Gearbox `old` gegen
  `new` und je eine Festlegung allein (`lna_only`, `adc_only`, `dac_only`,
  `bw_only`); der HPC-Lauf steht aus.
- Der Modellsatz `hw_new` in `studies/digital_bf_dac/` ist der Standard mit
  LNA `envelope` statt `fom_floor` und entspricht NICHT `"new"`.
