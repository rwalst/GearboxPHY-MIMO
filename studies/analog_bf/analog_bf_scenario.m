function scen = analog_bf_scenario(d, CFG, v, dataDir, adcModel, configs)
%ANALOG_BF_SCENARIO  Szenario einer Variante der Analog-BF-Studie.
%   Gemeinsam fuer run_analog_bf_distance und validate_analog_bf, damit
%   beide garantiert dasselbe rechnen.
%
%   v.mode "beamforming":  SISO-Kurve des Datenordners, Gewinn N_t*N_r im
%                          Linkbudget (Fall 1, LOS).
%   v.mode "multiplexing": Kurve je Antennenkonfiguration, der Gewinn
%                          steckt in der Kurve (Fall 2); nur zusammen mit
%                          Ein-Strom-Kurven, deshalb der Schalter
%                          analogCurvesCarryArrayGain.
args = {'distance', d, 'RVec', CFG.rates, 'fcVec', CFG.fcGHz*1e9, 'dataDir', dataDir, ...
        'adcPowerModel', adcModel, 'antennaMode', v.mode, ...
        'beamformingArch', v.arch, 'psType', v.ps, 'psBits', CFG.psBits, ...
        'psPower', CFG.psPower, 'psLossDb', CFG.psLossDb};
% LO-Verteilung je Mischer: nur Varianten mit v.lo = "per_mixer"; der
% Pufferwert steht JE VARIANTE in v.loPower [W] (dbf_ideal_lo4mW usw.).
if isfield(v, 'lo') && v.lo ~= ""
    args = [args, {'loDistributionModel', v.lo, 'loDistPowerPerMixer', v.loPower}];
end
if v.mode == "beamforming"
    args = [args, {'beamformingConfigs', configs}];
else
    args = [args, {'qamMimoConfigs', configs, 'analogCurvesCarryArrayGain', v.arch == "analog"}];
end
scen = gearboxphy.sweep.makeScenarioConfig(args{:});
end
