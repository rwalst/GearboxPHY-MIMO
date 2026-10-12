# MI-Kurven mit DAC-Quantisierung fuer digitales Beamforming

Stand 2026-10-12. Entscheidungen des Nutzers vom 2026-10-09 (zwei Runden) und 2026-10-12
(ADC je Empfangsantenne auch im LOS). Studie: `studies/digital_bf_dac/` (Uebersicht und offene
Punkte in deren `README.md`). Ablauf auf dem HPC: `docs/HPC_RUNBOOK_DAC.md`. Herleitung Schritt
fuer Schritt: `docs/dac_quantisation_math/dac_quantisation_math.pdf`.

Alle MI-Kurven liegen vor und sind geprueft; der Distanz-Sweep im Gearbox ist nicht gelaufen.

## Warum

`qamGear.m` rechnete den DAC immer mit `b_DAC = 1/2*log2(M)` ab. Das stellt ein ungedrehtes
QAM-Symbol exakt dar. Digitales Beamforming sendet je Antenne ein gedrehtes und skaliertes
Symbol; dafuer reicht die Aufloesung nicht, und die MI-Kurven nahmen einen idealen DAC an. Die
digitale Seite war damit zu guenstig gerechnet.

Entschieden: KEIN Fehlerbudget als Zwischenschritt, sondern Kurven, die die DAC-Quantisierung
enthalten -- eine Kurve je DAC-Aufloesung, so wie es beim ADC seit jeher ist. Der Gearbox
bezahlt genau die Aufloesung, mit der die Kurve gerechnet wurde, und waehlt die guenstigste.

## Entscheidungen

| Punkt | Festlegung |
|---|---|
| DAC-Stufen | `1/2*log2(M) + k`, k = 0, 1, 2, 3 Bit je I/Q-Zweig |
| Verfahren | fertig gewichtetes Signal runden (Eigenvektor-Gewichte wie bisher, danach quantisieren). Eine Praekodierung, die die quantisierten Ausgaenge direkt waehlt, ist Ausblick |
| Aussteuerung | je Antenne (und je Kanalrealisierung) WAEHLBAR aus wenigen Werten, kein Abschneiden; siehe "Modell" |
| Vergleichsfall | EINE gemeinsame Aussteuerung fuer alle Antennen (`common`): Rayleigh fuer Stufe +0, LOS fuer alle Stufen |
| Sendeleistung | nach dem Runden auf die Gesamtleistung normiert |
| Gemeinsame Phase | Konvention behalten: erstes Element des Gewichtsvektors reell und positiv, nicht optimiert |
| LOS-Referenz | wird mitgerechnet, ueber die Strahlrichtung gemittelt; sie laeuft ZUERST |
| ADC-Seite | unveraendert, Regel `fixedB` |
| analoger Sender | zahlt nie mehr als `1/2*log2(M)`: ein DAC, ungedrehtes Symbol, die Drehung macht der Phasenschieber |
| Minimum ueber die Stufen | eine Stelle: `gearboxphy.sweep.minOverDacLevels` |
| DAC-Leistungsmodell | drei Varianten als Schalter `dacPowerModel`: `analytic` (3 V), `analytic_1V`, `survey`; siehe `DAC_POWER_MODEL.md` |

## Modell, ein Strom (`QuantizedMimoMI/qam/core/dacQuantize.m`)

Je Kanalrealisierung `H` (Ziehung, Seed, `nMC` wie in `runQamSweepBfRayleigh`):

1. Gewichte `v` wie bisher: dominanter rechter Singulaervektor, erstes Element reell positiv.
2. Sollsignal der Antenne `i` fuer Symbol `x`: `u_i(x) = v_i * x`.
3. Spitzenwert je Antenne: `A_i = max_x max(|Re u_i(x)|, |Im u_i(x)|)`.
4. Quantisierer je I/Q-Zweig mit `L = 2^b_DAC` Stufen, schlichtes Runden. Die Aussteuerung
   ist waehlbar: mit Vollausschlag `F = A_i*(L-1)/(Lc-1)`, `Lc` gerade und `Lc <= L`, liegen
   die Stufen auf `A_i*(ungerade)/(Lc-1)`; das Signal nutzt genau die inneren `Lc` Stufen, und
   die bilden das Raster eines `Lc`-Stufen-DAC mit aeusserster Stufe auf dem Spitzenwert. Ein
   feinerer DAC bildet so jeden groeberen mit gerader Stufenzahl exakt nach. Je Antenne wird
   das `Lc` mit dem kleinsten quadratischen Fehler genommen (bei Gleichstand das feinere).
5. Normierung: `t(x) = alpha * Q(u(x))` mit `mean_x ||t(x)||^2 = 1`. Damit bleibt `snrDb` die
   GESAMT-SNR wie in allen vorhandenen BF-Kurven.
6. Empfaenger unveraendert: `y = H * t(x) + n`, ein B-Bit-ADC je Antenne, `I(x; Q_B(y) | H)`.

Zu jedem der M Symbole gehoert ein fester Sendevektor, den der Empfaenger kennt. Die MI-Rechnung
behaelt M Kandidaten (`ergodicMiBeamforming`, `opt.dacOffset`); die Verzerrung zaehlt als
veraendertes Alphabet, nicht als Rauschen.

Was die waehlbare Aussteuerung bewirkt:

- Der Fehler je Antenne waechst nie mit der Stufe.
- Ein ungedrehtes QAM-Symbol ist fuer JEDE Stufe exakt (`Lc = sqrt(M)`). Mit fester Aussteuerung
  auf den Spitzenwert haette 16-QAM ungedreht bei 3 Bit 8.3 % EVM (`validateBfDac` D11).
- Eine Sonderregel fuer `N_t = 1` ist nicht noetig. Der Code ueberspringt dort den Quantisierer
  trotzdem, damit die Kurve bitgleich zur vorhandenen bleibt; der DAC kostet `1/2*log2(M)`.

Das Kriterium ist der Fehler je Antenne, nicht die MI.

`common`: ein Spitzenwert (der groesste aller Antennen) und ein `Lc` fuer alle, gewaehlt nach dem
Gesamtfehler. Die Aussteuerung je Antenne setzt eine stufenlose Verstaerkung je Antenne hinter
dem DAC voraus, die niemand bezahlt; der Vergleichsfall zeigt, was sie wert ist. Auch im LOS
sind die beiden Faelle verschieden: die Betraege sind dort gleich, der Spitzenwert haengt aber
von der Drehung ab.

## LOS-Referenz mit einem ADC je Empfangsantenne (`runQamSweepBfLosDigitalDac`)

Nachtrag 2026-10-12, Einwand des Nutzers: rein digitales Beamforming hat N Empfangsketten und
damit N ADCs. Die LOS-Referenz des naechsten Abschnitts kombiniert dagegen VOR einem einzigen
ADC -- das ist der analoge Empfaenger. Fuer die digitale Seite ist das eine Vereinfachung, die
Rayleigh-Kurven rechnen schon immer mit einem ADC je Antenne.

- Derselbe Code wie fuer Rayleigh (`ergodicMiBeamforming`), nur mit dem deterministischen
  Rang-1-Kanal `H = a_r * a_t'` (`riceChannel`, K = Inf).
- Sechs Kurvensaetze: idealer DAC, vier DAC-Stufen je Antenne, Stufe +0 gemeinsam.
- Mittelung ueber 32 Richtungspaare `(u_t, u_r)`; die Empfangsrichtung zaehlt, weil sie
  bestimmt, wie die Antennensignale auf den ADC-Rastern liegen.
- Im Gearbox der Kanal `losd` (`SE_data_bflosd_fixedB[_dac<k>]`). Die Kurven mit EINEM ADC
  bleiben als Kanal `los`; sie beschreiben "Sender digital, Empfaenger analog".
- Ergebnis: die Kurve mit N ADCs liegt wenig UEBER der mit einem ADC, bei 75 % von `log2(M)`
  um 0.03-0.06 dB (2x2) bis 0.12-0.17 dB (16x16). Der Mehrbedarf durch den DAC ist in beiden
  Empfaengermodellen bis auf 0.02 dB derselbe.

## LOS-Referenz mit einem ADC hinter dem Kombinierer (`runQamSweepBfIdealDac`)

- `H = a_r * a_t'`, ULA mit halber Wellenlaenge, Gewichte `v = a_t / sqrt(N_t)` (reine Phasen).
- Quantisieren und normieren wie oben. Nach idealem Kombinieren am Empfaenger bleibt ein
  skalarer Kanal mit dem verzerrten Alphabet `c(x) = sqrt(N_r) * a_t' * t(x)` und ein
  B-Bit-ADC: `miScalarAlphabetQuant` (exakt, beliebiges Alphabet).
- Mittelung ueber die Senderichtung, gleichverteilt in `u = sin(theta)`; die MI ist in `u`
  gerade, gerechnet werden 32 Mittelpunkte auf (0, 1).
- Bei `u = 0` ist nichts gedreht: die Kurve ist die vorhandene bfideal-Kurve.
- Die Empfangsseite bleibt idealisiert wie in `bfideal`. Unkritisch: mit `1/2*log2(M) + 3`
  ADC-Bit kostet eine beliebig gedrehte Konstellation am ADC unter 0.001 bit.

Der Lauf schreibt je Kurve den SNR-Mehrbedarf gegen den idealen DAC bei 50 / 75 / 90 % von
`log2(M)` und den mittleren Gewinnverlust mit und druckt am Ende eine Tabelle. An ihr wird
entschieden, welche Stufen der teure Rayleigh-Lauf braucht.

## Erwartung (nur der Quantisierer, keine MI)

Verlust an Arraygewinn durch das Runden, Rayleigh, Aussteuerung je Antenne, in dB:

| N_t | M | +0 Bit | +1 Bit | +2 Bit | +3 Bit |
|---|---|---|---|---|---|
| 4 | 4 | -0.47 | -0.06 | -0.01 | 0.00 |
| 16 | 4 | -0.85 | -0.11 | -0.02 | 0.00 |
| 4 | 16 | -0.27 | -0.06 | -0.01 | 0.00 |
| 16 | 16 | -0.34 | -0.07 | -0.01 | 0.00 |

4-QAM bricht bei +0 Bit NICHT ein: das Empfangsalphabet bleibt exakt 4-QAM, der 1-Bit-DAC je
Zweig wirkt wie ein 2-Bit-Phasenschieber (`validateBfDac` D5). Die 48 % EVM aus Nachtrag 2 des
Praekodier-Plans sind ein Mass je Antenne, kein Mass fuer die MI. Mit gemeinsamer Aussteuerung
ist der Verlust bei 4-QAM und +0 Bit 1.2 dB (N_t = 4) bzw. 1.8 dB (N_t = 16).

## Ergebnis der MI-Kurven (Stand 2026-10-12)

SNR-Mehrbedarf gegen den idealen DAC bei 75 % von `log2(M)`, in dB, Aussteuerung je Antenne:

| Kanal | M | N | +0 Bit | +1 Bit | +2 Bit | +3 Bit | +0 gemeinsam |
|---|---|---|---|---|---|---|---|
| LOS, ADC je Antenne | 4 | 4 | 0.59 | 0.08 | 0.01 | 0.00 | 0.50 |
| LOS, ADC je Antenne | 4 | 16 | 0.82 | 0.10 | 0.01 | 0.00 | 0.72 |
| LOS, ADC je Antenne | 16 | 16 | 0.34 | 0.17 | 0.02 | 0.00 | 0.59 |
| LOS, ADC je Antenne | 256 | 16 | 0.02 | 0.01 | 0.02 | 0.00 | 0.03 |
| Rayleigh | 4 | 4 | 0.39 | 0.05 | 0.00 | 0.00 | 0.99 |
| Rayleigh | 4 | 16 | 0.61 | 0.08 | 0.01 | 0.00 | 1.26 |
| Rayleigh | 16 | 16 | -0.06 | 0.13 | 0.01 | 0.00 | 1.13 |
| Rayleigh | 64 | 16 | -0.27 | 0.00 | 0.02 | 0.00 | -0.50 |
| Rayleigh | 256 | 16 | -0.29 | -0.05 | -0.01 | 0.00 | -0.81 |

- Ab +2 Bit kostet der DAC nichts mehr; bei +0 Bit hoechstens rund 0.8 dB.
- LOS mit einem ADC hinter dem Kombinierer: dieselben Werte bis auf 0.02 dB.
- Im LOS ist die gemeinsame Aussteuerung nicht durchweg schlechter (4-QAM: besser): dort sind
  alle Betraege gleich, und die Aussteuerung je Antenne auf den Spitzenwert macht sie ungleich.
  Im Rayleigh-Kanal, wo die Betraege wirklich verschieden sind, ist sie bei 4-QAM deutlich
  schlechter.
- NEGATIVE Werte im Rayleigh-Kanal (M >= 64, N >= 4, schwach M = 16): die Kurve mit DAC liegt
  UEBER der mit idealem DAC, bis 0.10 bit. Kein Rechenfehler (unabhaengig nachgerechnet): der
  Rundungsfehler liegt auch in den uebrigen Eigenmoden und haengt vom Symbol ab; der Empfaenger
  im Modell kennt alle Sendevektoren und wertet alle Antennen gemeinsam aus. Ein Empfaenger, der
  nur auf den Hauptstrahl kombiniert, haette davon nichts. Im LOS (Rang 1) tritt es nicht auf.
  OFFEN: die exportierten Kurven am idealen DAC deckeln oder so lassen.

## Ablage und Schnittstelle zum Gearbox

- MI-Ergebnisse je Stufe in eigenen Ordnern: `qam/results/bf_ideal_dac<k>[_common]`,
  `qam/results/bf_rayleigh_dac<k>[_common]`, mit `results.Bdac`, `results.dacOffset`,
  `results.dacScale`. Der Dateiname traegt die Stufe nicht.
- Export (`studies/digital_bf_dac/export_dbf_dac_curves`) nach `data/SE_data_bfideal_fixedB_dac<k>`
  und `data/SE_data_bf_fixedB_dac<k>` (jeweils auch `_common`). Die Kurvendatei traegt
  `sourceBdac`; bei `N_t = 1` ist das `1/2*log2(M)`.
- `loadSECurve` reicht `sourceBdac` durch; `qamGear` setzt `b_DAC = sourceBdac`, wenn das Feld
  vorhanden ist UND der Sender digital ist (`~(ctx.abf.enabled && ctx.abf.txAnalog)`).
- Ohne das Feld (alle frueheren Ordner) aendert sich nichts: Golden Master bleibt bitgleich.

| Variante der Analog-Studie | neue Kurven |
|---|---|
| beide Seiten analog | keine |
| Sender analog, Empfaenger digital | keine wegen des DAC |
| beide Seiten digital (Referenz) | `SE_data_bf_fixedB_dac<k>`, `SE_data_bfideal_fixedB_dac<k>` |
| Sender digital, Empfaenger analog | LOS: `SE_data_bfideal_fixedB_dac<k>` (ein ADC hinter dem Kombinierer). Rayleigh: eigene Kurven mit demselben Quantisierer -- NOCH NICHT GEBAUT |

## Kontrollen (`QuantizedMimoMI/qam/validate/validateBfDac`)

| | Pruefung |
|---|---|
| D1 | ungedrehte QAM exakt fuer +0..+3 Bit |
| D2 | Normierung auf Gesamtleistung 1, beide Aussteuerungen |
| D3 | +8 Bit: `t(x) = v*x` bis auf einen kleinen Rest |
| D4 | `N_t = 1` mit DAC bitgleich zur Kurve ohne DAC |
| D5 | 4-QAM, +0 Bit: Alphabet bleibt 4-QAM, Gewinnverlust zwischen 0 und 1.5 dB |
| D6 | Fehler je Antenne faellt mit der Stufe, MI sinkt nicht |
| D7 | LOS, `u = 0`: die bfideal-Kurve |
| D8 | `miScalarAlphabetQuant == miGivenH(1, c)` |
| D9 | gemeinsame Aussteuerung nie besser; identisch nur bei `u = 0` |
| D10 | Ausgaenge liegen auf dem L-Stufen-Raster, `Lc` gerade |
| D11 | feste Aussteuerung waere schlechter (8.3 % EVM) |

Gearbox-Seite: `tests/+unit/DacModelTest.m`.

## Aufwand

- LOS: klein je Punkt (skalarer Kanal), mal 32 Richtungen, mal acht Kurvensaetze. Nicht gemessen.
- Rayleigh: je Stufe hoechstens die Laufzeit von `runQamSweepBfRayleigh` (eine ADC-Regel statt
  zwei), bei fuenf Kurvensaetzen. Nicht gemessen.

## Offen und Ausblick

- Mischform "Sender digital, Empfaenger analog" mit DAC-Quantisierung (eigene Kurven).
- Der BF/MUX-Vergleich nutzt die DAC-Kurven noch nicht; er soll dieselbe Funktion
  `minOverDacLevels` aufrufen. Dort wird neben `fixedB` auch `scaledB` gebraucht.
- Praekodierung, die die quantisierten Ausgaenge direkt waehlt, und eine optimierte gemeinsame
  Phase. Beide helfen bei +0 und +1 Bit; die Phase allein bringt hoechstens etwa 0.2 dB.
- Mehrere Stroeme (praekodiertes Multiplexing): derselbe Quantisierer, Alphabet `M^s`.
