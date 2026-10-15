function run_dac_model_siso(over)
%RUN_DAC_MODEL_SISO  SISO-Gearbox-Sweep ueber alle Gaenge fuer die drei
%   DAC-Leistungsmodelle (docs/DAC_POWER_MODEL.md).
%
%   Aufruf: in GearboxPHY-MIMO/ einfach
%       setupGearboxPath; run_dac_model_siso
%
%   RESSOURCEN: 100 Worker, 64 GB, 12 h. Ein Knoten.
%   NICHT GEMESSEN. Drei Laeufe wie run_sweep.m, aber NUR SISO (keine
%   MIMO-Kandidaten) und drei statt vier Traegern, also jeweils deutlich
%   billiger als results/main. runSweep ueberspringt fertige Kombinationen
%   und setzt Checkpoints je Ratenpunkt: nach einem Abbruch einfach noch
%   einmal starten.
%
%   ZIH-Cluster statt Windows: sbatch hpc/zih/submit_study.sbatch run_dac_model_siso
%   mit --cpus-per-task=101 (einer fuer den Client). Anleitung und
%   Schritt 0: docs/HPC_RUNBOOK_ZIH.md.
%
%   WOZU: Leistungsbudget der Komponenten ueber der Rate (wie Abb. 5.7 der
%   Dissertation) und optimaler Gang ueber der Rate (wie Abb. 5.5), jeweils
%   im Vergleich der drei DAC-Leistungsmodelle. Ein SISO-Sender schickt ein
%   ungedrehtes Symbol; die DAC-AUFLOESUNG ist hier kein Thema
%   (studies/digital_bf_dac), nur die DAC-LEISTUNG.
%
%   SZENARIO wie run_sweep.m / results/main: SISO ueber AWGN, d = 50 m, alle
%   Gaenge (QAM, NA-QAM, ZXM, Pulse), 400 Raten von 1e3 bis 1e11 bit/s,
%   Traeger 2.4 / 8 / 28 GHz, sonst die Vorgaben von makeScenarioConfig.
%   Das Modell "analytic" wiederholt damit die SISO-Spalte von results/main;
%   es wird trotzdem mitgerechnet, damit alle drei Laeufe aus demselben
%   Code-Stand stammen.
%
%   AUSGABE: results/dac_siso_<modell>/<gang>_M<M>_fc<f>GHz.mat
%   (Schema von runSweep: RVec, E_per_bit, Optimal_B, Optimal_gamma,
%   PowerBudget, ...). Abbildungen fuer die Folien:
%   Groupmeetings/dac_deck/fig_siso_dac_models.py.
%
%   over (optional): struct, dessen Felder gleichnamige Einstellungen unten
%   ersetzen (fuer Tests: kleines Raster, USE_PARALLEL = false).

%% ===================== CONFIG =====================================
P.N_WORKERS     = 100;                    % feste Poolgroesse
P.MODELS        = ["analytic" "analytic_1V" "survey"];
P.DISTANCE      = 50;                     % [m]
P.RVEC          = logspace(3, 11, 400);   % [bit/s]
P.FC_GHZ        = [2.4 8 28];
P.USE_PARALLEL  = true;
P.RESULT_PREFIX = "";                     % nur fuer Tests
%% ===================================================================
if nargin >= 1 && isstruct(over)
    for f = fieldnames(over).'
        assert(isfield(P, f{1}), 'run_dac_model_siso:over', 'Unbekannte Einstellung "%s".', f{1});
        P.(f{1}) = over.(f{1});
    end
end

for model = P.MODELS
    name = sprintf('%sdac_siso_%s', P.RESULT_PREFIX, model);
    fprintf('\n######## DAC-Leistungsmodell %s -> results/%s ########\n', model, name);
    scenario = gearboxphy.sweep.makeScenarioConfig( ...
        'dacPowerModel', model, ...
        'distance', P.DISTANCE, ...
        'RVec', P.RVEC, ...
        'fcVec', P.FC_GHZ * 1e9, ...
        'maxCores', P.N_WORKERS);          % qamMimoConfigs bleibt die Vorgabe: nur 1x1
    t0 = tic;
    gearboxphy.sweep.runSweep(scenario, 'resultsDir', name, 'useParallel', P.USE_PARALLEL);
    fprintf('%s fertig nach %.1f min\n', name, toc(t0)/60);
end
end
