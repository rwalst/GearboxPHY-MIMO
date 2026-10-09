function carrierScenario = resolveScenarioForCarrier(scenario, f_c)
%RESOLVESCENARIOFORCARRIER Merges per-band hardware constants (P_Mix,
%   P_LO, and an eta override for the WiFi7 bands) into a copy of the
%   base scenario for one carrier frequency. See
%   +physics/bandHardwareParams.m. Keeps gears themselves agnostic of the
%   per-band lookup - they just read scenario.P_Mix/P_LO/eta/f_c.
%
%   scenario.B_maxByCarrier (rows [f_c B_max], see makeScenarioConfig.m)
%   sets the maximum bandwidth per carrier. It is applied as
%   eta = B_max/f_c, because every gear derives its bandwidth limit (and
%   NA-QAM its fixed bandwidth, and every initial guess) from eta*f_c -
%   so this one line reaches all of them. It takes precedence over the
%   band's eta override. A non-empty table without a row for f_c is an
%   error, never a silent fallback to eta.
%
%   scenario.adcPowerModel selects the ADC constant c_ADC, see
%   +physics/adcConstant.m.
%
%   scenario.dacPowerModel selects the DAC constants, see
%   +physics/dacConstants.m.
[P_Mix, P_LO, etaOverride] = gearboxphy.physics.bandHardwareParams(f_c);
carrierScenario = scenario;
carrierScenario.f_c = f_c;
carrierScenario.P_Mix = P_Mix;
carrierScenario.P_LO = P_LO;
if ~isnan(etaOverride)
    carrierScenario.eta = etaOverride;
end
% ADC power model: only the Walden constant changes, so it is resolved
% here once and every gear keeps reading cs.c_ADC. A scenario without the
% field (built by hand) keeps its c_ADC.
if isfield(scenario, 'adcPowerModel')
    carrierScenario.c_ADC = gearboxphy.physics.adcConstant(scenario.adcPowerModel, scenario.c_ADC);
end
% DAC power model: only the three constants change, resolved here once so
% that every gear keeps reading cs.DAC_VDD / DAC_I0 / DAC_Cp. A scenario
% without the field (built by hand) keeps its constants.
if isfield(scenario, 'dacPowerModel')
    [carrierScenario.DAC_VDD, carrierScenario.DAC_I0, carrierScenario.DAC_Cp] = ...
        gearboxphy.physics.dacConstants(scenario.dacPowerModel, scenario.DAC_VDD, scenario.DAC_I0, scenario.DAC_Cp);
end
if isfield(scenario, 'B_maxByCarrier') && ~isempty(scenario.B_maxByCarrier)
    row = find(abs(scenario.B_maxByCarrier(:,1) - f_c) <= 1e-9*f_c);
    if numel(row) ~= 1
        error('gearboxphy:B_maxByCarrier', ...
            'B_maxByCarrier needs exactly one row for f_c = %g GHz (found %d).', f_c/1e9, numel(row));
    end
    carrierScenario.eta = scenario.B_maxByCarrier(row, 2) / f_c;
end
end
