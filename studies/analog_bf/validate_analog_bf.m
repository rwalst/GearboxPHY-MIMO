function validate_analog_bf()
%VALIDATE_ANALOG_BF  Schritt 0 der Analog-BF-Studie: schnelle Pruefungen,
%   die laut scheitern, bevor run_analog_bf_distance Rechenzeit verbraucht.
%
%   Aufruf: in GearboxPHY-MIMO/ einfach
%       setupGearboxPath; validate_analog_bf
%   Dauer: unter einer Minute, kein Pool. Bis auf B9 wird nicht optimiert,
%   nur die Zielfunktion an festen Punkten ausgewertet.
%
%   B1  Unit-Tests AnalogBeamformingTest und AdcModelTest bestehen.
%   B2  Datenordner SE_data_bfideal_fixedB: die 1x1-Kurven tragen
%       sourceB = 1/2*log2(M) + 3.
%   B3  Zwei Wege zum selben Punkt (digital): Modus "beamforming" mit der
%       SISO-Kurve und Gewinn im Linkbudget ergibt dieselbe Energie je Bit
%       wie Modus "multiplexing" mit der verschobenen bfideal-Kurve.
%       Belegt, dass Fall 1 auf den vorhandenen Kurven aufsetzen darf.
%   B4  N = 1: jede analoge Variante ist bitgleich die digitale Referenz.
%   B5  Budget der analogen Varianten bei N = 8: ADC, DAC und Mischer
%       einfach statt achtfach; aktiv traegt 8 x 20 mW je Seite; passiv
%       traegt keine Phasenschieber-Leistung; "comp" zahlt den Verlust im
%       LNA; Summe der Budgetfelder = Zielfunktion.
%   B6  Reihenfolge bei festem Arbeitspunkt: passive_pen <= passive_comp.
%   B7  ADC-Modell: quantile5 erhoeht NUR den ADC-Posten, um 3.17/0.67.
%   B9  EIN optimierter Punkt je Variante ueber denselben Aufrufweg wie der
%       Treiber (das Einzige hier, das optimiert; einige Sekunden).
%   B10 LO-Verteilung je Mischer trifft nur die digitale Referenz.
%   B11 Mischformen: Hardware je Seite, Lage zwischen den reinen Faellen,
%       LO-Verteilung nur auf der digitalen Seite, ein optimierter Punkt.
%   B8  Fall 2, nur wenn SE_data_abf_fixedB existiert: sourceMode
%       'bfanalog', sourceB nach fixedB, und die 1x1-Kurve stimmt mit der
%       digitalen Rayleigh-1x1-Kurve ueberein (ein ADC, eine Antenne).
nFail = 0;
fprintf('=== validate_analog_bf ===\n');

CFG = struct('rates', 1e8, 'distances', 200, 'fcGHz', 28, 'Ms', [4 16 64 256], 'Ns', [1 2 4 8 16], ...
             'psBits', 6, 'psPower', NaN, 'psLossDb', NaN);
fc = CFG.fcGHz * 1e9; d = 200; R = 1e8;
dataName = "SE_data_bfideal_fixedB";
assert(isfolder(gearboxphy.paths.dataDir(dataName)), 'validate_analog_bf:noData', ...
    '%s fehlt - erst export_mimo_comparison_curves ausfuehren.', dataName);
dataDir = gearboxphy.paths.dataDir(dataName);
configs = arrayfun(@(n) struct('N_t', n, 'N_r', n), CFG.Ns, 'UniformOutput', false);
gear = gearboxphy.gears.qamGear();
mk = @(name, mode, arch, ps) struct('name', name, 'data', dataName, 'mode', mode, 'arch', arch, 'ps', ps, 'lo', "", 'loPower', NaN);
vDig  = mk("dbf_ideal", "beamforming", "digital", "active");
vAct  = mk("abf_active", "beamforming", "analog", "active");
vComp = mk("abf_passive_comp", "beamforming", "analog", "passive_compensated");
vPen  = mk("abf_passive_pen", "beamforming", "analog", "passive_penalty");
csOf = @(v, adc) gearboxphy.sweep.resolveScenarioForCarrier( ...
    analog_bf_scenario(d, CFG, v, dataDir, adc, configs), fc);

% ---- B1 ---------------------------------------------------------------
r = runtests({fullfile(gearboxphy.paths.root(), 'tests', '+unit', 'AnalogBeamformingTest.m'), ...
              fullfile(gearboxphy.paths.root(), 'tests', '+unit', 'AdcModelTest.m')});
nFail = nFail + report(all([r.Passed]), sprintf('B1 Unit-Tests: %d von %d bestanden', sum([r.Passed]), numel(r)));

% ---- B2 ---------------------------------------------------------------
ok = true;
for M = CFG.Ms
    w = load(fullfile(dataDir, sprintf('SE_%d_QAM.mat', M)), 'sourceB');
    ok = ok && isfield(w, 'sourceB') && w.sourceB == 0.5*log2(M) + 3;
end
nFail = nFail + report(ok, 'B2 1x1-Kurven tragen sourceB = 1/2*log2(M) + 3');

% ---- B3 ---------------------------------------------------------------
vMux = mk("bfideal_curve", "multiplexing", "digital", "active");
worst = 0; x = [log10(2e8), 0.6];
for M = [4 64]
    for N = [2 8]
        cfg = struct('N_t', N, 'N_r', N);
        a = gear.makeObjective(gear.prepare(M, csOf(vDig, "envelope"), cfg), R);
        b = gear.makeObjective(gear.prepare(M, csOf(vMux, "envelope"), cfg), R);
        worst = max(worst, abs(a(x) / b(x) - 1));
    end
end
nFail = nFail + report(worst < 1e-6, sprintf(['B3 "beamforming" + SISO-Kurve gegen "multiplexing" + ' ...
    'bfideal-Kurve: max rel. Abweichung %.2e'], worst));

% ---- B4 ---------------------------------------------------------------
ok = true; cfg1 = struct('N_t', 1, 'N_r', 1);
for v = {vAct, vComp, vPen}
    a = gear.makeObjective(gear.prepare(16, csOf(v{1}, "envelope"), cfg1), R);
    b = gear.makeObjective(gear.prepare(16, csOf(vDig, "envelope"), cfg1), R);
    ok = ok && isequal(a(x), b(x));
end
nFail = nFail + report(ok, 'B4 N = 1: analog bitgleich digital, alle drei Phasenschieber');

% ---- B5 ---------------------------------------------------------------
N = 8; cfg = struct('N_t', N, 'N_r', N); M = 16;
bud = @(v, adc) gear.computeBudget(gear.prepare(M, csOf(v, adc), cfg), x, R);
bD = bud(vDig, "envelope"); bA = bud(vAct, "envelope"); bC = bud(vComp, "envelope"); bP = bud(vPen, "envelope");
rel = @(a, b) abs(a / b - 1);
ok = rel(bA.ADC, bD.ADC / N) < 1e-12 && rel(bA.DAC, bD.DAC / N) < 1e-12 && ...
     rel(bA.Mix_Rx, bD.Mix_Rx / N) < 1e-12 && rel(bA.Mix_Tx, bD.Mix_Tx / N) < 1e-12;
nFail = nFail + report(ok, sprintf('B5a aktiv, N = 8: ADC, DAC, Mischer einfach statt %d-fach', N));
cs = csOf(vAct, "envelope"); g = x(2);
ok = rel(bA.PS_Rx, (1/R) * (g + cs.epsilon_rec * (1 - g)) * N * 20e-3) < 1e-12 && ...
     rel(bA.PS_Tx, (1/R) * (g + cs.epsilon_trans * (1 - g)) * N * 20e-3) < 1e-12;
nFail = nFail + report(ok, 'B5b aktiv: 8 x 20 mW Phasenschieber je Seite');
ok = bC.PS_Rx == 0 && bC.PS_Tx == 0 && bP.PS_Rx == 0 && bP.PS_Tx == 0;
nFail = nFail + report(ok, 'B5c passiv: keine Phasenschieber-Leistung');
ok = rel(bC.LNA, bD.LNA * 10^(7.5/10)) < 1e-12 && rel(bP.LNA, bD.LNA) < 1e-12;
nFail = nFail + report(ok, sprintf('B5d passiv comp: LNA x %.2f (7.5 dB); passiv pen: LNA unveraendert', 10^(7.5/10)));
ok = true;
for v = {vAct, vComp, vPen}
    f = gear.makeObjective(gear.prepare(M, csOf(v{1}, "envelope"), cfg), R);
    b = bud(v{1}, "envelope");
    ok = ok && rel(f(x), sum(struct2array(b))) < 1e-12;
end
nFail = nFail + report(ok, 'B5e Summe der Budgetfelder = Zielfunktion');

% ---- B6 ---------------------------------------------------------------
fP = gear.makeObjective(gear.prepare(M, csOf(vPen, "envelope"), cfg), R);
fC = gear.makeObjective(gear.prepare(M, csOf(vComp, "envelope"), cfg), R);
nFail = nFail + report(fP(x) <= fC(x), sprintf('B6 passive_pen %.4e <= passive_comp %.4e J/bit', fP(x), fC(x)));

% ---- B7 ---------------------------------------------------------------
bQ = bud(vAct, "quantile5");
fn = setdiff(fieldnames(bA), {'ADC'});
ok = rel(bQ.ADC, bA.ADC * 3.17 / 0.67) < 1e-12 && all(cellfun(@(n) isequal(bQ.(n), bA.(n)), fn));
nFail = nFail + report(ok, 'B7 quantile5 aendert nur den ADC-Posten, um den Faktor 3.17/0.67');

% ---- B10 --------------------------------------------------------------
fn = setdiff(fieldnames(bD), {'LO_Tx', 'LO_Rx'});
cs = csOf(vDig, "envelope");
vLoAll = {};
for pw = [4e-3 12.5e-3 17e-3]
    vLo = vDig; vLo.lo = "per_mixer"; vLo.loPower = pw;
    vLo.name = "dbf_ideal_lo" + strrep(sprintf('%g', pw*1e3), '.', 'p') + "mW";
    vLoAll{end+1} = vLo; %#ok<AGROW>
    bL = bud(vLo, "envelope");
    ok = all(cellfun(@(n) isequal(bL.(n), bD.(n)), fn)) && ...
         rel(bL.LO_Rx - bD.LO_Rx, (1/R) * (g + cs.epsilon_rec * (1 - g)) * (N - 1) * pw) < 1e-9 && ...
         rel(bL.LO_Tx - bD.LO_Tx, (1/R) * (g + cs.epsilon_trans * (1 - g)) * (N - 1) * pw) < 1e-9;
    nFail = nFail + report(ok, sprintf('B10 %s: digital N = %d zahlt %d x %g mW je Seite mehr, sonst nichts', ...
        vLo.name, N, N - 1, pw*1e3));
end
vAlo = vAct; vAlo.lo = "per_mixer"; vAlo.loPower = 17e-3;
nFail = nFail + report(isequal(bud(vAlo, "envelope"), bA), 'B10 LO-Verteilung: analog bitgleich unveraendert (ein Mischer je Seite)');

% ---- B11 --------------------------------------------------------------
% Mischformen (run_analog_bf_mixed_distance): jede Seite zaehlt fuer sich.
mkm = @(name, tx, rx, ps) struct('name', name, 'data', dataName, 'mode', "beamforming", 'arch', "digital", ...
    'archTx', tx, 'archRx', rx, 'ps', ps, 'lo', "", 'loPower', NaN);
vAD = mkm("mix_txA_rxD_active", "analog", "digital", "active");
vDA = mkm("mix_txD_rxA_active", "digital", "analog", "active");
bAD = bud(vAD, "envelope"); bDA = bud(vDA, "envelope");
ok = rel(bAD.DAC, bA.DAC) < 1e-12 && rel(bAD.Mix_Tx, bA.Mix_Tx) < 1e-12 && rel(bAD.PS_Tx, bA.PS_Tx) < 1e-12 && ...
     rel(bAD.ADC, bD.ADC) < 1e-12 && rel(bAD.Mix_Rx, bD.Mix_Rx) < 1e-12 && bAD.PS_Rx == 0;
nFail = nFail + report(ok, 'B11a Sender analog / Empfaenger digital: Tx wie analog, Rx wie digital, keine PS am Empfaenger');
ok = rel(bDA.DAC, bD.DAC) < 1e-12 && rel(bDA.Mix_Tx, bD.Mix_Tx) < 1e-12 && bDA.PS_Tx == 0 && ...
     rel(bDA.ADC, bA.ADC) < 1e-12 && rel(bDA.Mix_Rx, bA.Mix_Rx) < 1e-12 && rel(bDA.PS_Rx, bA.PS_Rx) < 1e-12;
nFail = nFail + report(ok, 'B11b Sender digital / Empfaenger analog: Tx wie digital, Rx wie analog, keine PS am Sender');
% zwischen den reinen Faellen: aktiv und mit 6 Bit unterscheidet nur die Hardware
fAD = gear.makeObjective(gear.prepare(M, csOf(vAD, "envelope"), cfg), R);
fDA = gear.makeObjective(gear.prepare(M, csOf(vDA, "envelope"), cfg), R);
fDD = gear.makeObjective(gear.prepare(M, csOf(vDig, "envelope"), cfg), R);
fAA = gear.makeObjective(gear.prepare(M, csOf(vAct, "envelope"), cfg), R);
lo_ = min(fDD(x), fAA(x)); hi_ = max(fDD(x), fAA(x));
ok = fAD(x) >= lo_*(1-1e-3) && fAD(x) <= hi_*(1+1e-3) && fDA(x) >= lo_*(1-1e-3) && fDA(x) <= hi_*(1+1e-3);
nFail = nFail + report(ok, sprintf('B11c aktiv, fester Punkt: Mischfaelle %.4e / %.4e zwischen digital %.4e und analog %.4e J/bit', ...
    fAD(x), fDA(x), fDD(x), fAA(x)));
vADp = mkm("mix_txA_rxD_passive", "analog", "digital", "passive_penalty");
vADc = mkm("x", "analog", "digital", "passive_compensated");
ok = isequal(bud(vADp, "envelope"), bud(vADc, "envelope"));
nFail = nFail + report(ok, 'B11d digitaler Empfaenger: passive_penalty und passive_compensated bitgleich');
vADlo = vAD; vADlo.lo = "per_mixer"; vADlo.loPower = 12.5e-3;
bL = bud(vADlo, "envelope");
ok = isequal(bL.LO_Tx, bAD.LO_Tx) && rel(bL.LO_Rx - bAD.LO_Rx, (1/R) * (g + cs.epsilon_rec * (1 - g)) * (N - 1) * 12.5e-3) < 1e-9;
nFail = nFail + report(ok, 'B11e LO-Verteilung trifft im Mischfall nur die digitale Seite');
[e, ~, ~, pb] = gearboxphy.sweep.optimizeOnePoint(gear, gear.prepare(16, csOf(vAD, "envelope"), struct('N_t', 4, 'N_r', 4)), R, ...
    gear.initialGuess(16, csOf(vAD, "envelope")), gear.optimizerBounds(16, csOf(vAD, "envelope")), ...
    struct('tolerance', 1e-10, 'maxiters', 5e3, 'numtriesPerOpt', 20));
nFail = nFail + report(isfinite(e) && isfield(pb, 'PS_Tx'), sprintf('B11f mix_txA_rxD_active optimiert, 4x4: E = %.4e J/bit', e));

% ---- B8 ---------------------------------------------------------------
abfDir = gearboxphy.paths.dataDir("SE_data_abf_fixedB");
if isfolder(abfDir)
    ok = true; worst = 0;
    refDir = gearboxphy.paths.dataDir("SE_data_bf_fixedB");
    for M = CFG.Ms
        w = load(fullfile(abfDir, sprintf('SE_%d_QAM.mat', M)));
        ok = ok && strcmp(char(w.sourceMode), 'bfanalog') && w.sourceB == 0.5*log2(M) + 3;
        if isfolder(refDir)
            q = load(fullfile(refDir, sprintf('SE_%d_QAM.mat', M)));
            se = interp1(w.SNR_vec, w.SE_vec, q.SNR_vec, 'linear');
            worst = max(worst, max(abs(se - q.SE_vec), [], 'omitnan'));
        end
    end
    nFail = nFail + report(ok, 'B8a Fall-2-Kurven: sourceMode bfanalog, sourceB nach fixedB');
    % verschiedene Realisierungszahlen und Schaetzer: nur grob gleich
    nFail = nFail + report(worst < 0.1, sprintf(['B8b 1x1 analog gegen 1x1 digital (Rayleigh): ' ...
        'max |dSE| = %.3f bit (Monte-Carlo-Streuung)'], worst));
else
    fprintf('  [ -- ] B8 uebersprungen: SE_data_abf_fixedB fehlt (Fall 2 noch nicht exportiert)\n');
end

% ---- B9 ---------------------------------------------------------------
% Derselbe Aufrufweg wie localOneDistance im Treiber, an EINEM Punkt
% optimiert: belegt, dass der Sweep durchlaeuft und die Felder traegt,
% die er wegschreibt.
op = struct('tolerance', 1e-10, 'maxiters', 5e3, 'numtriesPerOpt', 20);
Eopt = struct();
for v = [{vDig}, vLoAll, {vAct, vComp, vPen}]
    cs = csOf(v{1}, "envelope");
    ctx = gear.prepare(16, cs, struct('N_t', 4, 'N_r', 4));
    [e, ~, ~, pb] = gearboxphy.sweep.optimizeOnePoint(gear, ctx, R, gear.initialGuess(16, cs), gear.optimizerBounds(16, cs), op);
    Eopt.(char(v{1}.name)) = e;
    okv = isfinite(e) && isstruct(pb) && (v{1}.arch == "digital" || isfield(pb, 'PS_Tx'));
    nFail = nFail + report(okv, sprintf('B9 %-19s 4x4, 16-QAM, %g m, R = %g bit/s: E = %.4e J/bit', v{1}.name, d, R, e));
end
nFail = nFail + report(Eopt.abf_passive_pen <= Eopt.abf_passive_comp * (1 + 1e-6), ...
    'B9 optimiert: passive_pen <= passive_comp');

if nFail == 0
    fprintf('=== alle Pruefungen bestanden ===\n');
else
    error('validate_analog_bf:failed', '%d Pruefung(en) fehlgeschlagen', nFail);
end
end

function f = report(ok, msg)
if ok, fprintf('  [ OK ] %s\n', msg); f = 0;
else,  fprintf('  [FAIL] %s\n', msg); f = 1; end
end
