function B_max = channelBandwidth(f_c)
%CHANNELBANDWIDTH Maximum signal bandwidth [Hz] per carrier for
%   bandwidthModel = "channel" (makeScenarioConfig.m, default since
%   2026-10-15): one standard channel of the band instead of eta*f_c.
%     2.4 GHz    20 MHz   (one Wi-Fi channel)
%     8 GHz     100 MHz
%     28 GHz    400 MHz   (one 5G NR FR2 channel)
%     60 GHz   2.16 GHz   (one IEEE 802.11ad/ay channel)
%   Other carriers have no channel bandwidth and are an error, never a
%   silent fallback to eta*f_c; use bandwidthModel = "eta" or
%   B_maxByCarrier for them.
switch f_c
    case 2.4e9, B_max = 20e6;
    case 8e9,   B_max = 100e6;
    case 28e9,  B_max = 400e6;
    case 60e9,  B_max = 2.16e9;
    otherwise
        error('gearboxphy:channelBandwidth', ...
            ['bandwidthModel="channel" has a bandwidth only at 2.4, 8, 28 and 60 GHz, ' ...
             'not at f_c = %g GHz. Use bandwidthModel="eta" or B_maxByCarrier.'], f_c/1e9);
end
end
