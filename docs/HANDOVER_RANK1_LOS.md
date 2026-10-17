# Übergabe: Ist „LOS" in dieser Studie Sichtverbindung — oder nur Rangarmut?

**Für eine eigene Session.** Diese Datei ist so geschrieben, dass sie ohne
Vorgeschichte reicht. Stand: 2026-10-16, `GearboxPHY-MIMO 6ac9882`,
`QuantizedMimoMI ac29828`.

> **Stand 2026-10-17.**
>
> - **Schritt 1 und die Implikationen sind untersucht**, ohne Repo-Änderung
>   und ohne Gearbox-Lauf: `Groupmeetings/rank1_los_study/README.md`.
>   - Mit frei wählbarem Abstand gewinnt MUX bei 1 Gbit/s bis ≈ 630 m.
>   - d\* hängt fast nur an der zulässigen Apertur.
> - **Schritte 2–4 (Kugelwellen-Zweig, `losmimo`-Kurven) sind NICHT
>   begonnen.** Ob sie kommen, ist nicht entschieden.
> - **Daneben vorbereitet:** dieselbe Geometrie für alle drei Architekturen
>   *innerhalb* von Rang 1 (`MIMO_TODO.md` Abschnitt 3.6,
>   `studies/rank1_geometry/`).

---

## 1. Die Frage

Die MIMO-Studie vergleicht drei Antennenarchitekturen (Multiplexing,
digitales und analoges Beamforming) über vier Kanäle: Rayleigh, Rice K = 3,
Rice K = 30 und „LOS". Ergebnis bisher: **je mehr Sichtverbindung, desto
eher gewinnt Beamforming**, mit dem Schwellwert K\* als Kennzahl.

Der LOS-Kanal ist dabei **per Konstruktion Rang 1**. Damit misst die K-Achse
nicht „gestreut → Sichtverbindung", sondern „vollrangig → rangarm". Ein
echter Sichtverbindungskanal ist aber nicht zwangsläufig rangarm: bei
passendem Antennenabstand (LOS-MIMO) stehen die Spalten orthogonal und
Multiplexing funktioniert ungeschmälert.

> **Die Frage dieser Session:** Trägt die Empfehlung „bei Sichtverbindung
> Beamforming" — oder gilt sie nur für λ/2-Arrays, und kippt sie, sobald der
> Elementabstand eine Entwurfsgröße wird?

---

## 2. Was feststeht

**2.1 Das Modell kann Rang > 1 bei LOS nicht darstellen.**
`QuantizedMimoMI/qam/core/riceChannel.m:83`:

```matlab
aT = exp(1j*pi*(0:Nt-1).'*sin(thetaT));   % ULA, Elementabstand lambda/2
aR = exp(1j*pi*(0:Nr-1).'*sin(thetaR));
Hlos = aR * aT';                          % äußeres Produkt -> Rang 1
```

Ein äußeres Produkt hat Rang 1, **unabhängig vom Winkel und unabhängig vom
Elementabstand**. Der Abstand steckt nur im `pi` des Exponenten (λ/2). Es
genügt also *nicht*, im Code den Abstand zu ändern — der Rangzuwachs von
LOS-MIMO kommt aus der **gekrümmten Wellenfront** (Fresnel-Zone), die das
Fernfeldmodell nicht hat.

**2.2 Unter λ/2 ist Rang 1 richtig.** Vollrang verlangt `d_t·d_r ≈ λ·R/N`;
mit `d = λ/2` heißt das `R ≤ N·λ/4`:

| | Vollrang-Abstand `√(λR/N)` | Apertur `N·d` | λ/2-Array vollrangig bis |
|---|---|---|---|
| 28 GHz, R = 10 m, N = 32 | 5,8 cm | 1,85 m | R ≤ 8,6 cm |
| 28 GHz, R = 100 m, N = 32 | 18,3 cm | 5,86 m | R ≤ 8,6 cm |
| 28 GHz, R = 10 m, N = 4 | 16,4 cm | 0,65 m | R ≤ 1,1 cm |
| 2,4 GHz, R = 10 m, N = 32 | 19,8 cm | 6,33 m | R ≤ 1,00 m |

Für **jede** Distanz der Studie (10 m … 10 km) ist der broadside-λ/2-LOS-Kanal
also tatsächlich Rang 1. **Die vorhandenen Kurven sind nicht falsch.** Die
Lücke ist, dass λ/2 nie als Entscheidung behandelt wurde.

**2.3 Die Bedingung ist „passend", nicht „groß".** Bei `d_t·d_r = k·λR/N`
(k teilerfremd zu N) ist H_LOS orthogonal; dazwischen schwanken die
Singulärwerte. Es gibt also mehrere günstige Abstände, keinen Schwellwert.

**2.4 Was die vorhandenen Daten bei Rang 1 sagen** (aus `docs/MIMO_TODO.md`
Abschnitt 1 und `results/cmp_distance_*.mat`):

- **BF gewinnt überall**: q = E_bit(BF)/E_bit(MUX) ≤ 1,000 schon bei 10 m,
  fällt auf 0,165. d\* = 46 m.
- MUX bricht nicht auf SISO ein: 16×16 mit QPSK erreicht bei Rang 1
  **6,0 bit** statt der 32 bit des Deckels — das Summenalphabet
  `x_1 + … + x_Nt` trägt mehr als ein Strom, aber keine 16 Ströme.
- MUX zahlt dabei N Ketten, N DACs und `+log2(N)` ADC-Bit (`scaledB`).

**2.5 Eine größere Apertur kostet im Energiemodell nichts.** Elementabstand
und Apertur kommen in `+gearboxphy/` **nirgends** vor (geprüft per grep). Die
Hypothese, die das interessant macht: LOS-MIMO liefert bei kurzer Distanz
praktisch gratis vollen Rang und kippt die Empfehlung genau dort, wo
Beamforming heute am deutlichsten gewinnt.
**Vorsicht in die Gegenrichtung:** gratis ist das nur im *Modell*. Eine
1,85-m-Apertur bringt Mechanik, Mast, Windlast, Kabelwege, Phasensynchronität
und Kalibrierung mit. Wenn die Antwort „LOS-MIMO gewinnt" lautet, gehört
dieser Posten benannt, sonst ersetzt die Session eine ungeprüfte Annahme
durch die nächste.

---

## 3. Was offen ist

1. Hat ein vollrangiger LOS-Kanal bei realistischer Geometrie überhaupt
   genug Rang, dass MUX seine N Ströme nutzen kann — oder ist die
   Konditionszahl so schlecht, dass bei endlichem SNR und endlicher
   ADC-Auflösung nichts davon ankommt? **Das ist die eigentliche Frage**,
   und sie ist mit Quantisierung schärfer als in der Lehrbuchversion.
2. Ab welcher Distanz ist LOS-MIMO mit vertretbarer Apertur machbar?
3. Kippt d\* oder K\*, und in welche Richtung?
4. Soll der Elementabstand eine Entwurfsgröße des Gearbox werden?

---

## 4. Vorgehen, billigstes zuerst

**Schritt 1 — Rechenprobe ohne jede Codeänderung (eine Stunde).**
`riceChannel` muss dafür *nicht* angefasst werden: H lässt sich direkt
bauen und an `miAuto`/`miGivenH`/`ergodicMiAuto` übergeben.

```matlab
% Kugelwelle, zwei parallele ULAs, Abstand R, Elementabstände dt/dr
lam = 3e8/28e9; R = 10; N = 8; d = sqrt(lam*R/N);
pt = (0:N-1).'*d; pr = (0:N-1).'*d;            % Positionen, broadside
D  = sqrt(R^2 + (pr - pt.').^2);               % Nr x Nt Entfernungen
H  = exp(-1j*2*pi*D/lam);                      % |Eintrag| = 1, wie Hlos
svd(H)                                          % <- die eine Zahl, um die es geht
```

Erwartung bei `d = sqrt(λR/N)`: alle N Singulärwerte gleich groß
(Konditionszahl ≈ 1). Zum Vergleich `svd(ones(N))` → ein Wert, Rest null.
Dann **dieselbe MI-Rechnung auf beiden Matrizen** (`miGivenH` bei N = 8,
M = 4, B aus `adcBitsRule`), und die Frage ist beantwortet, ob Schritt 2 ff.
die Arbeit wert sind. **Diese Probe darf lokal laufen** — eine Matrix, ein
SNR-Punkt. Alles Größere gehört auf den HPC.

**Schritt 2 — Kugelwellen-Zweig in `riceChannel`.** Das `los`-struct ist
schon da (`thetaT`/`thetaR`), es braucht einen zweiten Zweig, etwa
`los.geometry = struct('R',..,'dt',..,'dr',..)`. Harte Bedingung:

- `validateRice` R1a/R1b müssen **bitgleich** bleiben (K = 0 ist die
  Grundlage jeder Regression gegen die vorhandenen Kurven).
- R3 (Rangkollaps `λ_2/λ_1 → 0`) gilt künftig nur noch für den
  Fernfeldzweig — dort muss er weiter greifen, sonst ist der alte Pfad
  verändert.
- Neuer Test: bei `d_t·d_r = λR/N` ist die Konditionszahl ≈ 1.
- Die Zufallsziehung muss in Reihenfolge und Menge unverändert bleiben
  (`Hw` wird auch bei K = Inf gezogen und verworfen — darauf beruht die
  Paarung MUX ↔ BF).

**Schritt 3 — MI-Kurven als EIGENE Familie.** Nicht die vorhandenen
LOS-Kurven überschreiben: neuer Name (Vorschlag `losmimo`), eigener
Ergebnisordner, eigener Export. `runQamSweep32Los.m` ist die Vorlage für
einen Treiber; das SNR-Raster muss neu bestimmt werden, weil der Arraygewinn
ein anderer ist (Begründung und Messwerte in `runQamSweepMux32.m`).

**Schritt 4 — Gearbox-Seite**, erst wenn Schritt 1 ein Signal zeigt:
Kurvenfamilie in `export_mimo_comparison_curves.m` aufnehmen, dann dieselbe
Distanzstudie wie für Rang 1 fahren und d\* vergleichen.

---

## 5. Was nicht passieren darf

- **K = 0 bitgleich halten.** Sonst sind alle vorhandenen Kurven
  unvergleichbar. `validateRice` ist Schritt 0 jeder Änderung.
- **Vorhandene LOS-/Rang-1-Kurven nicht überschreiben.** Neue Geometrie =
  neuer Name = neuer Ordner.
- **Simulationen nur auf dem HPC.** Lokal nur Einzelproben wie Schritt 1;
  lauffähige `.m`-Treiber vorbereiten, nicht lokal rechnen.
- **Keine Shellskripte in `QuantizedMimoMI`** (Ausnahme nur `hpc/zih/`).
- **Vor jedem HPC-Lauf committen**, nach jedem `git pull` in MATLAB
  `clear functions` (ein veralteter Funktionscache hat am 2026-10-16 schon
  einen Lauf gekostet).

---

## 6. Wo was steht

| | Datei |
|---|---|
| Die Annahme, prominent | `docs/MIMO_TODO.md`, Banner ganz oben |
| Vorgehen, Abstandstabelle | `docs/MIMO_TODO.md`, Abschnitt 3.5 |
| Herleitung, Tragweite | `docs/MIMO_TODO.md`, Abschnitt 5.1 |
| Kanalmodell | `QuantizedMimoMI/qam/core/riceChannel.m` (Zeile 83, und der Kopfkommentar „WAS K DAMIT MISST") |
| Validierung | `QuantizedMimoMI/qam/validate/validateRice.m` (R1a/R1b/R2/R3/R4) |
| Rang-1-Treiber als Vorlage | `QuantizedMimoMI/qam/sweep/runQamSweep32Los.m`, `runQamSweepMuxRank1.m` |
| Ergebnisse bei Rang 1 | `results/cmp_distance_mux_scaledB_KInf.mat`, `..._bfideal_fixedB.mat`; Auswertung `studies/mimo_comparison/analyze_rice_comparison.m` |
| Plan der Rice-Erweiterung | `RICE_EXTENSION_PLAN.md`, Abschnitt „Was K wirklich misst" |

**Konventionen:** Commit-Betreff in `GearboxPHY-MIMO` englisch, in
`QuantizedMimoMI` deutsch; dort Kommentare ohne Umlaute (ae/oe/ue/ss).
Beide enden mit der `Co-Authored-By`-Zeile.

---

## 7. Abnahme

Die Session ist fertig, wenn eine der beiden Antworten mit Zahlen belegt ist:

- **„Trägt."** Der vollrangige LOS-Kanal ändert d\* und K\* nicht wesentlich,
  weil Konditionszahl, SNR oder ADC-Auflösung die zusätzlichen Ströme
  auffressen. Dann kann der Banner im TODO durch eine Fußnote ersetzt
  werden — mit der Messung, die das zeigt.
- **„Trägt nicht."** MUX holt über den vollrangigen LOS-Kanal seine Ströme
  zurück und d\* kippt. Dann muss die Hauptaussage der Studie umformuliert
  werden: nicht „bei Sichtverbindung Beamforming", sondern „bei λ/2-Arrays
  Beamforming" — und der Elementabstand wird eine Entwurfsgröße.

In beiden Fällen gehört das Ergebnis in `docs/MIMO_TODO.md` (Banner,
Abschnitt 3.5 und 5.1) und die Bezeichnung vereinheitlicht: derselbe Kanal
heißt dort heute auf der MUX-Seite „Rang 1" und auf der BF-Seite „LOS".
