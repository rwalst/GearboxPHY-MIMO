# Sammelschalter `hardwareModel`

Ein Schalter in `makeScenarioConfig`, der die drei Bauteilmodelle mit
Survey-Variante gemeinsam setzt.

```matlab
s = gearboxphy.sweep.makeScenarioConfig('hardwareModel', "new");
```

| `hardwareModel` | `lnaPowerModel` | `adcPowerModel` | `dacPowerModel` |
|---|---|---|---|
| `"custom"` (Standard) | wie übergeben | wie übergeben | wie übergeben |
| `"old"` | `fom_bandwidth` | `envelope` (0,67 fJ) | `analytic` (3 V, 10 µA, 0,5 pF) |
| `"new"` | `envelope` | `quantile5` (3,17 fJ) | `survey` (1,2 µW je LSB, 0,25 pJ je Bit und Abtastwert) |

Herleitung der Modelle: `LNA_POWER_MODEL.md`, `ADC_POWER_MODEL.md`,
`DAC_POWER_MODEL.md`. Die Zuordnung steht in
`+gearboxphy/+physics/hardwareModelPreset.m`.

## Verhalten

- **Standard ist `"custom"`.** Ohne den Schalter ändert sich nichts: jeder
  bestehende Aufruf und jedes bestehende Ergebnis bleibt bitgleich.
- **`"old"` ist bitgleich zum Standard-Szenario**; nur das Feld
  `hardwareModel` unterscheidet sich.
- `"old"` und `"new"` **schreiben** die drei Einzelschalter. Das Szenario
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

## Nicht enthalten

PA (`paPowerModel`), LO-Verteilung (`loDistributionModel`), Mischer und
Phasenschieber (`psType`) haben kein Paar alt/neu und bleiben, wie der
Aufrufer sie setzt.

## Stand

Schalter und Test (`tests/+unit/HardwareModelTest.m`) sind vorhanden. Keine
Studie benutzt ihn bisher; es gibt keinen Lauf mit allen drei neuen Modellen
zugleich.
