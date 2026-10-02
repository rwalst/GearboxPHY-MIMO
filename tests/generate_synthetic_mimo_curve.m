% GENERATE_SYNTHETIC_MIMO_CURVE Creates a SYNTHETIC, TEST-ONLY MIMO SE
%   curve (SE_16_QAM_2x2.mat) by roughly doubling the SISO curve's
%   spectral efficiency at each SNR point (a crude stand-in for a 2x2
%   spatial-multiplexing capacity gain - NOT a real capacity derivation).
%   This exists purely to exercise the MIMO wiring (nested-enumeration
%   selection, N_t/N_r power scaling, result schema) end-to-end in this
%   sandbox, since MIMO_EXTENSION.md decision 3 leaves real MIMO curve
%   generation out of scope - real curves must replace this before any
%   MIMO sweep result is scientifically meaningful.
siso = load(fullfile(gearboxphy.paths.dataDir('SE_data'), 'SE_16_QAM.mat'));
SNR_vec = siso.SNR_vec;
SE_vec = siso.SE_vec * 2;   % crude synthetic stand-in only - NOT a real MIMO capacity curve
save(fullfile(gearboxphy.paths.dataDir('SE_data'), 'SE_16_QAM_2x2.mat'), 'SNR_vec', 'SE_vec');
fprintf('Wrote SYNTHETIC test-only SE_data/SE_16_QAM_2x2.mat\n');
