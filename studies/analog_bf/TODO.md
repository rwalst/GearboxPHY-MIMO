# Analog-BF-Studie: offene Punkte

Stand 2026-10-08. Erledigt: LO-Verteilung als Schalter (`loDistributionModel`), Formel der
Phasenquantisierung nachgeprueft (beides in `docs/ANALOG_BEAMFORMING.md`).

## Vor der Auswertung zu entscheiden

- [ ] **Verstaerkungsausgleich beim passiven Phasenschieber.** `passive_compensated`
      multipliziert die LNA-Leistung mit der Daempfung (x 5.6 bei 7.5 dB). Das folgt aus der
      LNA-Formel der Dissertation (Leistung proportional zum Gewinn). Unter dem Survey-Modell
      des LNA ist es eine Annahme ohne Datenbasis. Alternative: fester Zuschlag je Element aus
      den gemessenen Kanalleistungen (handset-Klasse 42-54 mW je Empfangskanal).
- [ ] **Zahlenwerte bei 28 GHz bestaetigen.** 20 mW je aktivem Phasenschieber (Survey-Median
      24 mW, CMOS 19 mW); 7.5 dB passiv (in `phaseShifterParams.m` von 9.5 dB geaendert);
      LO-Puffer 16.6 mW je Mischer (nur der Puffer; die ganze LO-Kette bei Pang et al. liegt
      bei 89 mW je Pfad).
- [ ] **LO-Puffer je Mischer: Wert festlegen.** Belege bei 28 GHz: 16.6 mW (Pang 2019),
      12.5 mW (Khanna 2026), rund 4 mW bei einem Synthesizer je Element (Wang & Razavi),
      10 mW als Modellannahme (Dutta et al.). Die Studie rechnet 4, 12.5 und 17 mW als eigene
      Varianten; die Vorgabe des Schalters selbst bleibt 16.6 mW. Nach der Auswertung einen
      Wert waehlen. Quellen in `docs/ANALOG_BEAMFORMING.md`.
- [ ] **PA-Gewinn 20 dB** (`psGainPA`) fuer die Treiberleistung auf der Sendeseite ist eine
      Annahme ohne Quelle. Empfindlichkeit pruefen (10 dB, 30 dB).

## Modell

- [ ] **Werte fuer 2.4, 8 und 60 GHz** in `phaseShifterParams.m` sind die von vor der Survey.
      LO-Puffer je Mischer hat nur bei 28 GHz einen Wert. Vor einer Studie auf anderen
      Traegern nachziehen.
- [ ] **Phasenquantisierung in Fall 2.** Die Formel setzt eine kohaerente Summe voraus und
      wird im Rayleigh-Fall als Naeherung benutzt. Sauberer: quantisierte Phasen direkt in
      `analogBfGain` (QuantizedMimoMI) und der Gearbox rechnet dann mit `psBits = Inf`.
- [ ] **Splitter- und Kombiniererverluste** sind null. Ein Wilkinson-Baum kostet je Stufe
      einige Zehntel dB.
- [ ] **Nur QAM.** ZXM und die Puls-Gaenge haben keine analoge Variante; sie brechen bei
      Mehrantennen-Analog mit Fehler ab.
- [ ] **Hybrides Beamforming** (wenige digitale Ketten, je Kette ein analoges Teilarray) fehlt.

## Studie

- [ ] **Raster.** Zwei Raten ueber 25 Distanzen, aus dem BF/MUX-Vergleich uebernommen. Fuer
      "ab wann lohnt analog" waere ein Raster ueber die Rate bei festen Distanzen
      aussagekraeftiger.
- [ ] **Fall 2 gegen die richtige Referenz.** `analyze_analog_bf` vergleicht bisher alles
      gegen `dbf_ideal` (LOS). Fuer `abfray_*` gehoert `results/cmp_distance_bf_fixedB.mat`
      (digitales Rayleigh-BF) daneben; dort gilt auch die LO-Verteilung noch nicht.
- [ ] **Rice.** Der Kurventreiber rechnet K = 0, 3, 30, Inf, der Sweep nutzt nur K = 0.
- [ ] **`analyze_analog_bf` ist ungetestet**, solange keine Ergebnisdateien vorliegen.
- [ ] **Laufzeiten** im Runbook sind geschaetzt, nicht gemessen.

## Fall 2, Annahmen in den Kurven

- [ ] Die Wechseloptimierung in `analogBfGain` findet ein lokales Maximum. Die Kurven sind
      erreichbare Raten, keine Obergrenze fuer reine Phasengewichte.
- [ ] Die ADC-Aussteuerung folgt jeder Kanalrealisierung ideal (wie in `miGivenH`).
- [ ] Perfekte Kanalkenntnis an beiden Enden.

## Framework, bei dieser Arbeit aufgefallen

- [ ] **Golden-Master-Test haengt von der Reihenfolge ab.** Laeuft `mimo_smoke_test` davor,
      weichen QAM und ZXM um etwa 2e-4 ab (Zufallszustand der Mehrfachstarts); allein oder
      zuerst gestartet besteht er. Der Optimierer findet also je nach Zufallszustand leicht
      verschiedene Optima.
- [ ] **`tests/smoke_test.m` scheitert** schon ohne diese Aenderungen
      (`savePointCheckpoint`: Variable `Optimal_N_t` fehlt).
