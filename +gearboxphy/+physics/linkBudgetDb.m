function L_dB = linkBudgetDb(cs, antennaConfig)
%LINKBUDGETDB Path loss [dB] seen by the link, including the array gain in
%   beamforming mode.
%
%   L_dB = linkBudgetDb(carrierScenario, antennaConfig)
%
%   This is the ONE place the antenna count is allowed to touch the link
%   budget, so the two antenna modes cannot drift apart:
%
%     "multiplexing" - unchanged from the original dissertation formula.
%       Multiple antennas carry independent STREAMS; the gain they provide
%       is already inside the MIMO SE curve, so folding it into the path
%       loss as well would count it twice (MIMO_EXTENSION.md decision 1).
%
%     "beamforming"  - multiple antennas carry ONE stream and are used for
%       gain instead. The SE curve therefore stays the SISO one and the
%       array shows up here, as an IDEAL gain of N_t*N_r:
%           L_dB_eff = L_dB - 10*log10(N_t*N_r)
%       Ideal means perfectly aligned beams and no array/taper loss - it
%       is an upper bound on what beamforming can deliver, chosen
%       deliberately as the simple limiting case (BEAMFORMING_EXTENSION.md).
%
%   SISO (N_t=N_r=1) gives 10*log10(1)=0 dB in both modes, so nothing
%   changes for any existing SISO result.
arguments
    cs (1,1) struct
    antennaConfig (1,1) struct = struct('N_t',1,'N_r',1)
end

L_dB = gearboxphy.physics.pathLossDb(cs.f_c, cs.distance, cs.D_r, cs.D_t, cs.beta, cs.c);

mode = "multiplexing";
if isfield(cs, 'antennaMode'), mode = cs.antennaMode; end
if mode == "beamforming"
    L_dB = L_dB - 10*log10(antennaConfig.N_t * antennaConfig.N_r);
end
end
