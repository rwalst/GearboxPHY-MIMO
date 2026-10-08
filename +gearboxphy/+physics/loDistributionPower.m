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
%   value below. Only 28 GHz has one: 16.6 mW, the measured two-stage LO
%   buffer per path in Pang et al., JSSC 2019 (Table II; "only consumes
%   17 mW" in the text). That is the buffer alone. The complete LO chain
%   per path of that LO-phase-shifting transceiver draws about 89 mW
%   (polyphase-filter buffer 44.4, LO switch and buffer 28.0, LO buffer
%   16.6), so 16.6 mW is the low end.
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
    if cs.f_c == 28e9
        P_buf = 16.6e-3;
    else
        error('gearboxphy:loDistPower', ...
            ['loDistributionModel="per_mixer" has a default LO-buffer power only at 28 GHz. ' ...
             'Set loDistPowerPerMixer [W] for f_c = %g GHz.'], cs.f_c/1e9);
    end
end
P = (nMixers - 1) * P_buf;
end
