function P = loDistributionPower(cs, nMixers)
%LODISTRIBUTIONPOWER Extra LO power [W] for feeding nMixers mixers on one
%   side of the link (docs/ANALOG_BEAMFORMING.md, "LO distribution").
%
%   P = loDistributionPower(carrierScenario, nMixers)
%
%   cs.loDistributionModel:
%     "shared" (default, also for a scenario without the field) - 0. One
%         LO per side whatever the number of mixers, as in the
%         dissertation. Byte-identical to every existing result.
%     "per_mixer" - every mixer beyond the first needs its own LO buffer:
%             P = (nMixers - 1) * P_buf .
%         The first mixer is covered by P_LO, so a single-chain link
%         (SISO, or analog beamforming with its one mixer) is unchanged.
%
%   P_buf is cs.loDistPowerPerMixer; NaN (default) takes the per-carrier
%   value below: 3 mW at 2.4 GHz, 7 mW at 8 GHz, 12.5 mW at 28 GHz; other
%   carriers have none and need loDistPowerPerMixer set.
%   28 GHz: 12.5 mW are the measured LO repeaters
%   per I/Q downconverter in Khanna et al., JSSC 2026 (25 mW for two
%   downconverters, four LO phases over 600 um). It is the middle of the
%   measured 28 GHz values for a buffer or repeater per additional chain
%   (9 to 17 mW; Pang et al., JSSC 2019: 16.6 mW two-stage LO buffer). It
%   covers the distribution only: where each chain also generates its own
%   I/Q phases or shifts the LO phase, 35 to 95 mW per chain are reported
%   (docs/ANALOG_BEAMFORMING.md). Until 2026-10-13 the default was 16.6 mW.
%   2.4 and 8 GHz (set 2026-10-13): about half of P_LO, the ratio found at
%   28 GHz. 3 mW matches a measured 2 GHz receiver (LO phase generation
%   and mixer drivers from an external LO; measured range 3 to 7 mW).
%   7 mW at 8 GHz is a setting: the three measured values at 5 to 8 GHz
%   are 1.4, 24 and 29 mW and none is from an array; 2 to 25 mW is the
%   range to scan.
P = 0;
if ~isfield(cs, 'loDistributionModel') || string(cs.loDistributionModel) == "shared"
    return
end
assert(string(cs.loDistributionModel) == "per_mixer", 'gearboxphy:loDistributionModel', ...
    'Unknown loDistributionModel "%s".', string(cs.loDistributionModel));
if nMixers <= 1
    return
end
P_buf = NaN;
if isfield(cs, 'loDistPowerPerMixer'), P_buf = cs.loDistPowerPerMixer; end
if isnan(P_buf)
    if cs.f_c == 2.4e9
        P_buf = 3e-3;
    elseif cs.f_c == 8e9
        P_buf = 7e-3;
    elseif cs.f_c == 28e9
        P_buf = 12.5e-3;
    else
        error('gearboxphy:loDistPower', ...
            ['loDistributionModel="per_mixer" has a default LO-buffer power only at 2.4, 8 and 28 GHz. ' ...
             'Set loDistPowerPerMixer [W] for f_c = %g GHz.'], cs.f_c/1e9);
    end
end
P = (nMixers - 1) * P_buf;
end
