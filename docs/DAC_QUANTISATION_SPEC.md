# Spezifikation: MI-Kurven mit DAC-Quantisierung fuer digitales Beamforming

Stand 2026-10-09. Festlegungen des Nutzers vom selben Tag, aufgeschrieben fuer die Sitzung, die
das praekodierte Multiplexing baut (`PRECODED_MUX_EXTENSION_PLAN.md`, Nachtrag 2). Nichts davon
ist gebaut.

## Warum

`qamGear.m` rechnet den DAC mit `b_DAC = 1/2*log2(M)` ab. Das stellt ein ungedrehtes QAM-Symbol
exakt dar. Digitales Beamforming sendet je Antenne ein gedrehtes und skaliertes Symbol; dafuer
reicht die Aufloesung nicht, und die MI-Kurven nehmen bisher einen idealen DAC an. Die digitale
Seite ist damit zu guenstig gerechnet. Stichprobe in der Analog-BF-Studie
(`Groupmeetings/abf_results/dac_spotcheck.m`, acht Punkte, Fehlerbudget 20 dB): bei 1 Mbit/s
keine Aenderung, bei 1 Gbit/s wird die digitale Referenz 20 bis 25 % teurer.

Entschieden: KEIN Fehlerbudget als Zwischenschritt, sondern Kurven, die die DAC-Quantisierung
enthalten -- eine Kurve je DAC-Aufloesung, so wie es beim ADC seit jeher ist. Der Gearbox
bezahlt dann genau die Aufloesung, mit der die Kurve gerechnet wurde, und waehlt die guenstigste.

## Entscheidungen

| Punkt | Festlegung |
|---|---|
| Wer baut | die Sitzung des praekodierten Multiplexings; die Analog-BF-Sitzung uebernimmt danach Treiber und Auswertung ihrer Studie |
| DAC-Stufen | `1/2*log2(M) + k`, k = 0, 1, 2, 3 Bit je Achse |
| Verfahren | fertig gewichtetes Signal runden (Eigenvektor-Gewichte wie bisher, danach quantisieren). Eine Praekodierung, die die quantisierten Ausgaenge direkt waehlt, ist Ausblick |
| Aussteuerung | je Antenne (und je Kanalrealisierung) auf den Spitzenwert ihres Signals, kein Abschneiden |
| Sendeleistung | nach dem Runden auf die Gesamtleistung normiert |
| LOS-Referenz | wird mitgerechnet, ueber die Strahlrichtung gemittelt |
| ADC-Seite | unveraendert; fuer die Analog-Studie Regel `fixedB` |

## Modell, ein Strom

Je Kanalrealisierung `H` (Ziehung, Seed, `nMC` wie in `runQamSweepBfRayleigh`):

1. Gewichte `v` wie bisher: dominanter rechter Singulaervektor, erstes Element reell positiv.
2. Sollsignal der Antenne `i` fuer Symbol `x`: `u_i(x) = v_i * x`.
3. Aussteuerung je Antenne: `A_i = max_x max(|Re u_i(x)|, |Im u_i(x)|)`.
4. Quantisierer je Achse, `L = 2^b_DAC` Stufen, **aeusserste Stufe gleich dem Spitzenwert**:
   Stufen `A_i * (-(L-1):2:(L-1)) / (L-1)`, Rundung auf die naechste Stufe, I und Q getrennt.
   Mit dieser Lage ist ein ungedrehtes QAM-Symbol bei `L = sqrt(M)` exakt darstellbar -- die
   Bedingung, unter der der heutige Wert `1/2*log2(M)` stimmt.
5. Normierung: `t(x) = alpha * Q(u(x))` mit `alpha` so, dass `mean_x ||t(x)||^2 = 1`.
   Damit bleibt `snrDb` die GESAMT-SNR wie in allen vorhandenen BF-Kurven.
6. Empfaenger unveraendert: `y = H * t(x) + n`, ein B-Bit-ADC je Antenne, `I(x; Q_B(y) | H)`.

Zu jedem der M Symbole gehoert ein fester Sendevektor. Die MI-Rechnung behaelt M Kandidaten;
in `ergodicMiBeamforming` aendert sich nur die Kandidatenmenge (`H*T` statt `Heff*x`). Die
Kosten je Kurve bleiben, die Zahl der Kurven vervierfacht sich.

**Der Quantisierer als eigene Funktion** (`qam/core/dacQuantize.m` oder aehnlich), weil ihn
auch die Mischform "Sender digital, Empfaenger analog" der Analog-Studie und der
Mehrstrom-Fall brauchen.

**N_t = 1:** keine Praekodierung, nichts ist gedreht. Dort gilt fuer JEDE Stufe die vorhandene
Kurve, und der DAC kostet `1/2*log2(M)`. Den Quantisierer dort nicht anwenden: ein feineres
Raster mit aeusserster Stufe am Spitzenwert enthaelt die QAM-Punkte im Allgemeinen NICHT
(bei 16-QAM und 3 Bit liegt `A/3` zwischen den Stufen `A/7` und `3A/7`).

## LOS-Referenz

Heute: SISO-AWGN-Kurve, verschoben um `N_t*N_r` (`runQamSweepBfIdeal`). Mit DAC:

- `H = a_r(theta_r) * a_t(theta_t)'`, Gewichte `v = a_t / sqrt(N_t)` (reine Phasen).
- Quantisieren und normieren wie oben. Nach idealem Kombinieren am Empfaenger bleibt ein
  skalarer Kanal mit dem verzerrten Alphabet `c(x) = a_t' * t(x)`, Empfangsgewinn `N_r`, ein
  B-Bit-ADC. Die MI ist die einer beliebigen komplexen Konstellation ueber AWGN
  (`miGivenH` mit eigenem Alphabet; `miSisoAwgnQuant` setzt quadratische QAM voraus).
- Mittelung ueber `theta_t`, gleichverteilt in `sin(theta)`. Bei `theta_t = 0` sind alle
  Gewichte gleich und reell: nichts ist gedreht, der DAC ist exakt -- das ist der beste Fall
  und zugleich die Kontrolle gegen die vorhandene Kurve.

Die Idealisierung der Empfangsseite (Kombinieren vor dem ADC) bleibt wie in `bfideal`. Sie ist
unkritisch: mit `1/2*log2(M) + 3` ADC-Bit kostet eine beliebig gedrehte Konstellation am ADC
unter 0.001 bit (nachgerechnet 2026-10-09, `miGivenH` mit `h = exp(1j*phi)`, M = 4 bis 256).

## Ablage und Schnittstelle zum Gearbox

- MI-Ergebnisse je Stufe getrennt, mit Feldern fuer die DAC-Aufloesung (`results.Bdac`,
  `results.dacOffset`).
- Export in einen Datenordner je Stufe: `SE_data_bf_fixedB_dac<k>` und
  `SE_data_bfideal_fixedB_dac<k>`, k = 0..3. Die Kurvendatei traegt `sourceBdac`
  (bei N_t = 1: `1/2*log2(M)`).
- `loadSECurve` reicht `sourceBdac` durch; `qamGear` setzt `b_DAC = sourceBdac`, wenn das Feld
  vorhanden ist UND der Sender digital ist, sonst wie bisher `1/2*log2(M)`.
- **Analoger Sender zahlt nie mehr als `1/2*log2(M)`:** ein DAC, ungedrehtes Symbol, die
  Drehung macht der Phasenschieber. Im Code ist das `ctx.abf.enabled && ctx.abf.txAnalog`.
- Ohne das Feld (alle heutigen Ordner) aendert sich nichts: Golden Master bleibt bitgleich.

Fuer die Analog-Studie folgt daraus:

| Variante | neue Kurven |
|---|---|
| beide Seiten analog | keine |
| Sender analog, Empfaenger digital | keine wegen des DAC |
| beide Seiten digital (Referenz) | `SE_data_bf_fixedB_dac<k>`, `SE_data_bfideal_fixedB_dac<k>` |
| Sender digital, Empfaenger analog | eigene Kurven mit demselben Quantisierer und einem ADC hinter dem Kombinierer; rechnet die Analog-BF-Sitzung, sobald `dacQuantize` existiert |

Der Treiber der Analog-Studie rechnet die digitale Referenz je Stufe und nimmt das Minimum.

## Kontrollen

1. Viele DAC-Bit (z.B. +8): die vorhandene Kurve, im Rundungsbereich.
2. N_t = 1: bitgleich zur vorhandenen Kurve, fuer jede Stufe.
3. 4-QAM, +0 Bit, N_t > 1: die Kurve bricht deutlich ein (Nachtrag 2 misst 48 % EVM).
4. Normierung: `mean_x ||t(x)||^2 = 1` je Realisierung.
5. LOS, `theta_t = 0`: die vorhandene bfideal-Kurve.
6. MI waechst mit der Stufe (bis auf Monte-Carlo-Streuung); der Abstand zur idealen Kurve
   schrumpft mit N_t, weil sich die Fehler der Antennen unkorreliert addieren.

## Aufwand

- Rayleigh: grob das Vierfache von `runQamSweepBfRayleigh` mit EINER ADC-Regel. Nicht gemessen.
- LOS: billig je Punkt (skalarer Kanal), mal die Zahl der Richtungen.

## Ausblick

- Praekodierung, die die quantisierten Ausgaenge direkt waehlt (grob quantisierte
  Praekodierung). Sie wuerde digital bei 1 bis 2 Bit verbessern; das einfache Runden ist dort
  pessimistisch.
- Mehrere Stroeme (praekodiertes Multiplexing): derselbe Quantisierer, Alphabet `M^s`.
- Gemeinsame Aussteuerung fuer alle Antennen als Vergleichsfall (laut Nachtrag 2 etwa 0.7 Bit
  schlechter).
