function scen = bf_arch_scenario(d, CFG, v, dataDir, adcModel, configs, dacModel, lnaModel)
%BF_ARCH_SCENARIO  Szenario einer Beamforming-Variante (analog, digital oder
%   gemischt) aus der Variantenbeschreibung v.
%   Gemeinsam fuer die Studien analog_bf (run_analog_bf_distance,
%   run_analog_bf_mixed_distance, validate_analog_bf) und digital_bf_dac
%   (run_dbf_dac_distance), damit alle garantiert dasselbe rechnen.
%   Hiess bis 2026-10-12 analog_bf_scenario und lag in studies/analog_bf/.
%
%   v.mode "beamforming":  SISO-Kurve des Datenordners, Gewinn N_t*N_r im
%                          Linkbudget (Fall 1, LOS).
%   v.mode "multiplexing": Kurve je Antennenkonfiguration, der Gewinn
%                          steckt in der Kurve (Fall 2); nur zusammen mit
%                          Ein-Strom-Kurven, deshalb der Schalter
%                          analogCurvesCarryArrayGain.
%
%   dacModel, lnaModel (optional): DAC- bzw. LNA-Leistungsmodell, siehe
%   +physics/dacConstants.m und +physics/lnaPowerFor.m. Leer oder nicht
%   uebergeben: der Standard von makeScenarioConfig (seit 2026-10-15
%   survey bzw. fom_floor; vorher fielen beide hier auf die alten Modelle
%   analytic/fom_bandwidth zurueck). adcModel leer: ebenso der Standard.
args = {'distance', d, 'RVec', CFG.rates, 'fcVec', CFG.fcGHz*1e9, 'dataDir', dataDir, ...
        'antennaMode', v.mode, ...
        'beamformingArch', v.arch, 'psType', v.ps, 'psBits', CFG.psBits, ...
        'psPower', CFG.psPower, 'psLossDb', CFG.psLossDb};
if nargin >= 7 && ~isempty(dacModel) && dacModel ~= "", args = [args, {'dacPowerModel', dacModel}]; end
if nargin >= 8 && ~isempty(lnaModel) && lnaModel ~= "", args = [args, {'lnaPowerModel', lnaModel}]; end
if ~isempty(adcModel) && adcModel ~= "", args = [args, {'adcPowerModel', adcModel}]; end
% LO-Verteilung je Mischer: nur Varianten mit v.lo = "per_mixer"; der
% Pufferwert steht JE VARIANTE in v.loPower [W] (dbf_ideal_lo4mW usw.).
if isfield(v, 'lo') && v.lo ~= ""
    args = [args, {'loDistributionModel', v.lo, 'loDistPowerPerMixer', v.loPower}];
end
% Mischfaelle: Architektur je Seite (v.archTx / v.archRx), sonst folgt jede
% Seite v.arch.
if isfield(v, 'archTx') && v.archTx ~= "", args = [args, {'beamformingArchTx', v.archTx}]; end
if isfield(v, 'archRx') && v.archRx ~= "", args = [args, {'beamformingArchRx', v.archRx}]; end
anyAnalog = v.arch == "analog" || (isfield(v, 'archTx') && v.archTx == "analog") || (isfield(v, 'archRx') && v.archRx == "analog");
if v.mode == "beamforming"
    args = [args, {'beamformingConfigs', configs}];
else
    args = [args, {'qamMimoConfigs', configs, 'analogCurvesCarryArrayGain', anyAnalog}];
end
scen = gearboxphy.sweep.makeScenarioConfig(args{:});
end
