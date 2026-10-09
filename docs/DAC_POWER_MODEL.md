# DAC-Leistungsmodell: drei Varianten als Schalter

Stand 2026-10-09. Schalter: `makeScenarioConfig('dacPowerModel', ...)`, Konstanten in
`+gearboxphy/+physics/dacConstants.m`, angewandt in `resolveScenarioForCarrier` -- alle Gaenge
lesen weiter `cs.DAC_VDD`, `cs.DAC_I0`, `cs.DAC_Cp`. `dacPower.m` selbst aendert sich nicht.

    P_DAC (I/Q-Paar) = 2 * ( 1/2*V_dd*I_0*(2^b - 1) + C_p*V_dd^2*b*B )

Das ist Gl. (4.1) der Dissertation = Gl. (32) in Cui, Goldsmith, Bahai (2005) mit Abtastrate
gleich B; der Faktor 1/2 des dynamischen Terms steckt in `DAC_Cp` (0.5 pF bedeutet 1 pF).

| `dacPowerModel` | statisch je LSB | dynamisch je Bit und Abtastwert | Herkunft |
|---|---|---|---|
| `analytic` (Vorgabe) | 15 uW | 4.5 pJ | 3 V, 10 uA, 1 pF: Cuis Beispielwerte fuer 0.5 um CMOS; Dissertation Kap. 4, ISWCS 2024. Bitgleich zu allen bisherigen Ergebnissen |
| `analytic_1V` | 5 uW | 0.5 pJ | wie oben mit 1 V: Dissertation Kap. 5 und 6, WCNC 2025, TCOM-Vorabdruck 2026. Die 1 V sind dort nicht begruendet |
| `survey` | 1.2 uW | 0.25 pJ | 5-%-Quantil der DAC-Uebersicht von Caragiulo, Daigle, Murmann (96 DACs, 4-16 Bit, 10 MS/s - 224 GS/s) |

Zu `survey`:

- Angepasst sind nur die beiden PRODUKTE. Im Code stehen sie als 1 V, 2.4 uA und 0.25 pF,
  damit `dacPower.m` bleiben kann; die Einzelwerte sind keine Schaltungsgroessen.
- 6 von 96 DACs liegen unter dem Modell (bei `analytic` 68 %, bei `analytic_1V` 23 %).
  Bootstrap (95 %): 0.8-3.4 uW und 0.20-0.44 pJ.
- Die Uebersicht hat keinen DAC unter 4 Bit, unter 10 MS/s oder unter 1.9 mW. Die statische
  Konstante haengt an drei 14-Bit-DACs, die dynamische an 7-nm-Entwuerfen.
- `survey` ERSETZT alle drei Konstanten; nicht mit von Hand gesetzten kombinieren.

Daten und Anpassung: `LituratureReview/dac_survey/` (`fit_dac_model.py`), Foliensatz
`Groupmeetings/DAC_Power_Model_Proposal.pptx`. Tests: `tests/+unit/DacModelTest.m`.

Die Vorgabe ist NICHT geaendert. Ob `survey` Vorgabe wird, ist nicht entschieden.
