function cfg = lna_comparison_config()
%LNA_COMPARISON_CONFIG  Single source of truth for the LNA-model comparison
%   (LNA_POWER_MODEL.md): which variants exist and where their results
%   live. Read by run_lna_comparison, analyze_lna_comparison and
%   validate_lna_comparison, so the three can never disagree about a
%   directory name or a parameter.
%
%   A CASE is one runSweep call:
%       study x bandwidth setting x LNA model x distance
%   and writes to  <here>/results_lna/<study>_<bw>_<model>_d<d>/.
%
%   Studies
%     "siso"         SISO, d = 50 m (the dissertation setting)
%     "beamforming"  ideal beamforming, N x N for N in bfN, all gears may
%                    pick an array (BEAMFORMING_EXTENSION.md) - this is
%                    where the per-element LNA power actually bites
%   Bandwidth settings
%     "eta01"   B_max = 0.1*f_c (dissertation):   240 MHz / 800 MHz / 2.8 GHz
%     "narrow"  B_max per carrier:                 20 MHz / 100 MHz / 400 MHz
%   LNA models (makeScenarioConfig 'lnaPowerModel')
%     "fom_bandwidth"  dissertation formula (reference)
%     "fom_floor"      same, bandwidth floored at 0.05*f_c
%     "envelope"       survey envelope, same floor

here = fileparts(mfilename('fullpath'));

cfg.root   = fullfile(here, 'results_lna');
cfg.fcVec  = [2.4 8 28] * 1e9;
cfg.RVec   = logspace(3, 11, 100);
cfg.models = ["fom_bandwidth" "fom_floor" "envelope"];
cfg.modelLabels = ["dissertation (FoM)" "dissertation + floor" "survey envelope"];
cfg.lnaBetaMin = 0.05;

cfg.bw(1).name  = "eta01";
cfg.bw(1).label = "B_{max} = 0.1 f_c";
cfg.bw(1).B_maxByCarrier = zeros(0, 2);          % -> eta = 0.1 (makeScenarioConfig default)
cfg.bw(2).name  = "narrow";
cfg.bw(2).label = "B_{max} = 20 / 100 / 400 MHz";
cfg.bw(2).B_maxByCarrier = [2.4e9 20e6; 8e9 100e6; 28e9 400e6];

cfg.studies = ["siso" "beamforming"];
cfg.distances.siso        = 50;
cfg.distances.beamforming = [50 5000];
cfg.bfN = [1 2 4 8 16 32 64];
end
