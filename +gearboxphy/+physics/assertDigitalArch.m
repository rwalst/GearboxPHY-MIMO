function assertDigitalArch(cs, antennaConfig, gearName)
%ASSERTDIGITALARCH Analog beamforming (cs.beamformingArch = "analog") is
%   implemented in the QAM gear only. Every other gear calls this in its
%   prepare(), so a multi-antenna analog request fails loudly there
%   instead of being computed silently with digital hardware. A SISO
%   configuration passes: with one antenna per side both architectures
%   are the same link.
if isfield(cs, 'beamformingArch') && string(cs.beamformingArch) == "analog" ...
        && (antennaConfig.N_t > 1 || antennaConfig.N_r > 1)
    error('gearboxphy:analogNotImplemented', ...
        'beamformingArch="analog" is implemented for the QAM gear only, not for %s (%dx%d).', ...
        string(gearName), antennaConfig.N_t, antennaConfig.N_r);
end
end
