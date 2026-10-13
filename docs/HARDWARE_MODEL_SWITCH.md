# Sammelschalter `hardwareModel`

Ein Schalter in `makeScenarioConfig`, der die drei Bauteilmodelle mit
Survey-Variante und die LO-Verteilung gemeinsam setzt.

```matlab
s = gearboxphy.sweep.makeScenarioConfig('hardwareModel', "new");
```

| `hardwareModel` | `lnaPowerModel` | `adcPowerModel` | `dacPowerModel` | `loDistributionModel` |
|---|---|---|---|---|
| `"custom"` (Standard) | wie übergeben | wie übergeben | wie übergeben | wie übergeben |
| `"old"` | `fom_bandwidth` | `envelope` (0,67 fJ) | `analytic` (3 V, 10 µA, 0,5 pF) | `shared` (ein LO je Seite) |
| `"new"` | `envelope` | `quantile5` (3,17 fJ) | `survey` (1,2 µW je LSB, 0,25 pJ je Bit und Abtastwert) | `per_mixer` (LO-Puffer je zusätzlichem Mischer: 3 / 7 / 12,5 mW bei 2,4 / 8 / 28 GHz) |

Herleitung der Modelle: `LNA_POWER_MODEL.md`, `ADC_POWER_MODEL.md`,
`DAC_POWER_MODEL.md`, LO-Verteilung in `ANALOG_BEAMFORMING.md` und
`LO_POWER_MODEL.md`. Die Zuordnung steht in
`+gearboxphy/+physics/hardwareModelPreset.m`.

## Verhalten

- **Standard ist `"custom"`.** Ohne den Schalter ändert sich nichts: jeder
  bestehende Aufruf und jedes bestehende Ergebnis bleibt bitgleich.
- **`"old"` ist bitgleich zum Standard-Szenario**; nur das Feld
  `hardwareModel` unterscheidet sich.
- `"old"` und `"new"` **schreiben** die vier Einzelschalter. Das Szenario
  trägt danach die aufgelösten Werte; Gänge und
  `resolveScenarioForCarrier` lesen weiterhin nur die Einzelschalter.
- **Widerspruch ist ein Fehler** (`gearboxphy:hardwareModelConflict`): wer
  `"old"` oder `"new"` wählt und einen Einzelschalter auf etwas anderes
  stellt (z. B. `"new"` mit `dacPowerModel="analytic_1V"`), bekommt eine
  Fehlermeldung. Zum Mischen `"custom"` nehmen. Den Wert der Voreinstellung
  zu wiederholen ist erlaubt.
- Ein Einzelschalter, der ausdrücklich auf seinen Standardwert gesetzt
  wird, ist von „nicht gesetzt“ nicht zu unterscheiden und wird von `"new"`
  überschrieben.
- `"new"` ersetzt `c_ADC` und die drei DAC-Konstanten; von Hand gesetzte
  Werte dafür wirken dann nicht (wie bei den Einzelschaltern).
- **LO-Teil von `"new"`** (seit 2026-10-13): wirkt nur, wo eine Seite mehr
  als einen Mischer hat, also bei digitalen Arrays. SISO und analoges
  Beamforming (ein Mischer je Seite) bleiben davon unberührt. Der Pufferwert
  kommt aus `loDistPowerPerMixer`; der Schalter fasst ihn nicht an, ein
  eigener Wert (z. B. 4 oder 17 mW) bleibt also möglich. Bei 60 GHz gibt es
  keine Vorgabe: dort bricht `"new"` mit mehreren Mischern ab, solange
  `loDistPowerPerMixer` nicht gesetzt ist.
- Neue Modelle MIT gemeinsamem LO gibt es nur über `"custom"` (die drei
  Einzelschalter von Hand setzen).

## Nicht enthalten

Die LO-Leistung `P_LO` selbst, PA (`paPowerModel`), Mischer und
Phasenschieber (`psType`) haben kein Paar alt/neu und bleiben, wie der
Aufrufer sie setzt. `P_LO` wurde gegen die Literatur geprüft und nicht
geändert (`LO_POWER_MODEL.md`).

## Stand

Schalter und Test (`tests/+unit/HardwareModelTest.m`) sind vorhanden.
`studies/hardware_models/` benutzt ihn (SISO, alt gegen neu; HPC-Lauf steht
aus). Der Modellsatz `hw_new` in `studies/digital_bf_dac/` setzt nur LNA,
ADC und DAC und führt die LO-Verteilung als eigene Achse.
