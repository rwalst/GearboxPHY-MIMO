function c_ADC = adcConstant(model, c_ADC_envelope)
%ADCCONSTANT Walden constant c_ADC [J per conversion step] of adcPower.m
%   for the chosen ADC power model (docs/ADC_POWER_MODEL.md).
%     "envelope"  - the scenario's own c_ADC, by default 0.67 fJ: the
%                   best-case envelope of the Murmann ADC survey (Gast,
%                   eq. 4.7). Byte-identical to every existing result.
%     "quantile5" - 3.17 fJ: the 5 % quantile of the same survey (rev.
%                   2026-08-01) for f_s = 1 MHz..2 GHz, designs since
%                   2015 (n = 176), with the envelope's corner f_b kept.
%                   No ADC in that band reaches the envelope; the best
%                   one is 2.1x above it.
%   Only the constant changes; adcPower.m and f_b stay as they are.
switch string(model)
    case "envelope"
        c_ADC = c_ADC_envelope;
    case "quantile5"
        c_ADC = 3.17e-15;
    otherwise
        error('gearboxphy:adcPowerModel', 'Unknown adcPowerModel "%s".', string(model));
end
end
