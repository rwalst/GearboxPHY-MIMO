# Studie: DAC-Leistungsmodell, SISO

Frage: wie veraendern die drei DAC-Leistungsmodelle (`dacPowerModel`: `analytic` 3 V,
`analytic_1V`, `survey`; siehe `docs/DAC_POWER_MODEL.md`) das Leistungsbudget und die Gangwahl
des SISO-Gearbox?

| Datei | Zweck |
|---|---|
| `run_dac_model_siso.m` | SISO-Sweep ueber alle Gaenge, je DAC-Modell ein Ergebnisordner `results/dac_siso_<modell>/` |

Auswertung und Abbildungen (Leistungsbudget wie Abb. 5.7 der Dissertation, optimaler Gang wie
Abb. 5.5): `Groupmeetings/dac_deck/fig_siso_dac_models.py`, Folien in
`Groupmeetings/DAC_Power_Model_Proposal.pptx`.

Die DAC-AUFLOESUNG fuer digitales Beamforming ist eine eigene Studie: `studies/digital_bf_dac/`.

## Stand 2026-10-13

- Treiber gebaut und auf einem Mini-Raster geprueft; der Sweep selbst ist NICHT gelaufen.
- Fuer `analytic` gibt es die SISO-Spalte aus `results/main` (gleiches Szenario).
