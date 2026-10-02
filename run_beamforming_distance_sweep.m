%RUN_BEAMFORMING_DISTANCE_SWEEP  Zwei feste Raten, Sweep ueber die Distanz.
%
%   Aufruf:  run_beamforming_distance_sweep
%            QUICK = true; run_beamforming_distance_sweep   % Funktionstest
%
%   WARUM DIESER SCHNITT. Der Sweep ueber R_eff zeigt bei je einer festen
%   Distanz, wann sich Antennen lohnen. Der Gewinn wirkt aber
%   ausschliesslich auf den PA-Term, und dessen Anteil am Budget haengt vor
%   allem an der Distanz. Der hier gerechnete Schnitt -- Rate fest, Distanz
%   variabel -- macht deshalb genau die Groesse sichtbar, die
%   Proposition 1 des Papers vorhersagt: die Distanz, ab der ein weiteres
%   Element sich rechnet. Eine niedrige und eine hohe Rate, weil der
%   Umschlagpunkt von beidem abhaengt, nicht nur von der Distanz.
%
%   Es wird NICHT runSweep benutzt: das schreibt ein Ergebnisverzeichnis je
%   Distanz, was hier 25 Verzeichnisse fuer zwei Ratenpunkte bedeutete.
%   Stattdessen wird direkt ueber (Distanz, Rate, Gang, Konfiguration)
%   aufgezaehlt und alles in EINE .mat geschrieben.

if ~exist('QUICK','var'), QUICK = false; end

%% ===================== CONFIG =====================================
CFG.rates     = [1e6 1e9];                 % niedrig / hoch [bit/s]
CFG.distances = logspace(1, 4, 25);        % 10 m .. 10 km
CFG.fcGHz     = 28;
CFG.configs   = { ...
    struct('N_t',1,'N_r',1),   struct('N_t',2,'N_r',2),   struct('N_t',4,'N_r',4), ...
    struct('N_t',8,'N_r',8),   struct('N_t',16,'N_r',16), struct('N_t',32,'N_r',32), ...
    struct('N_t',64,'N_r',64) };
CFG.outFile   = 'results_beamforming_distance.mat';
%% ===================================================================

if QUICK
    CFG.distances = logspace(1,4,5);
    CFG.configs   = CFG.configs([1 2 4]);
    CFG.outFile   = 'results_beamforming_distance_quick.mat';
end

TXF = {'PA','DAC','LO_Tx','Mix_Tx'};
RXF = {'LNA','LO_Rx','Mix_Rx','ADC','EnergyDetector'};

reg   = gearboxphy.gears.gearRegistry();
nD    = numel(CFG.distances);
nR    = numel(CFG.rates);
nC    = numel(CFG.configs);
fc    = CFG.fcGHz * 1e9;

% Gang/Ordnung-Paare einmal aufzaehlen, damit die Schleifen flach bleiben
combos = struct('gear',{},'order',{},'label',{});
for g = 1:numel(reg)
    for o = reg{g}.orders
        combos(end+1) = struct('gear', reg{g}, 'order', o, ...
            'label', sprintf('%s M=%g', reg{g}.name, o)); %#ok<SAGROW>
    end
end
nG = numel(combos);
fprintf('%d Distanzen x %d Raten x %d Gang/Ordnung x %d Konfigurationen\n', nD, nR, nG, nC);

E    = nan(nD, nR, nG, nC);     % Energie je Bit
Etx  = nan(nD, nR, nG, nC);     % Sendeseite
Erx  = nan(nD, nR, nG, nC);     % Empfangsseite
Epa  = nan(nD, nR, nG, nC);     % nur PA

t0 = tic;
for di = 1:nD
    d = CFG.distances(di);
    scen = gearboxphy.sweep.makeScenarioConfig('distance', d, ...
        'RVec', CFG.rates, 'fcVec', fc, ...
        'antennaMode', "beamforming", 'beamformingConfigs', CFG.configs);
    cs = gearboxphy.sweep.resolveScenarioForCarrier(scen, fc);
    op = struct('tolerance', scen.tolerance, 'maxiters', scen.maxiters, ...
                'numtriesPerOpt', scen.numtriesPerOpt);
    for gi = 1:nG
        gear = combos(gi).gear; order = combos(gi).order;
        cfgs = gear.antennaConfigs(order, cs);
        assert(numel(cfgs) == nC, ...
            '%s liefert %d statt %d Antennenkandidaten - Beamforming-Fix pruefen', ...
            gear.name, numel(cfgs), nC);
        x0 = gear.initialGuess(order, cs); bnds = gear.optimizerBounds(order, cs);
        for ci = 1:nC
            ctx = gear.prepare(order, cs, cfgs{ci});
            for ri = 1:nR
                [e, ~, ~, pb] = gearboxphy.sweep.optimizeOnePoint( ...
                    gear, ctx, CFG.rates(ri), x0, bnds, op);
                E(di,ri,gi,ci) = e;
                if isstruct(pb)
                    fn = fieldnames(pb);
                    unknown = setdiff(fn, [TXF RXF]);
                    assert(isempty(unknown), 'unbekanntes Budget-Feld: %s', strjoin(unknown,','));
                    Etx(di,ri,gi,ci) = sum(cellfun(@(n) pb.(n), intersect(fn,TXF,'stable')));
                    Erx(di,ri,gi,ci) = sum(cellfun(@(n) pb.(n), intersect(fn,RXF,'stable')));
                    Epa(di,ri,gi,ci) = pb.PA;
                end
            end
        end
    end
    fprintf('  d = %8.1f m  (%2d/%2d)  %.1f min\n', d, di, nD, toc(t0)/60);
end

gearLabels = string({combos.label});
N_t = cellfun(@(c) c.N_t, CFG.configs);
save(CFG.outFile, 'E', 'Etx', 'Erx', 'Epa', 'CFG', 'gearLabels', 'N_t');
fprintf('\nfertig nach %.1f min -> %s\n', toc(t0)/60, CFG.outFile);
