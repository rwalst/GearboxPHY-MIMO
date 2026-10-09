function [VDD, I0, Cp] = dacConstants(model, VDD, I0, Cp)
%DACCONSTANTS Constants of dacPower.m for the chosen DAC power model
%   (docs/DAC_POWER_MODEL.md). dacPower.m itself does not change:
%       P = 2 * ( 1/2*VDD*I0*(2^b - 1) + Cp*VDD^2*b*B )      per I/Q pair,
%   i.e. Gast eq. (4.1) = Cui/Goldsmith/Bahai 2005 eq. (32) with f_s = B
%   (the factor 1/2 of the dynamic term is inside Cp: 0.5 pF means 1 pF).
%     "analytic"    - the scenario's own constants, by default 3 V, 10 uA,
%                     0.5 pF: Cui's example values for 0.5 um CMOS (static
%                     15 uW per LSB, dynamic 4.5 pJ per bit and sample).
%                     Byte-identical to every existing result.
%     "analytic_1V" - the same with VDD = 1 V, the value listed in chapters
%                     5 and 6 of the dissertation and in the later papers
%                     (5 uW, 0.5 pJ). I0 and Cp stay the scenario's.
%     "survey"      - 5 % quantile of the DAC survey of Caragiulo, Daigle
%                     and Murmann (96 DACs, 4-16 bit, 10 MS/s-224 GS/s):
%                     static 1.2 uW per LSB, dynamic 0.25 pJ per bit and
%                     sample. Only these two PRODUCTS are fitted; they are
%                     written here as VDD = 1 V, I0 = 2.4 uA, Cp = 0.25 pF
%                     so that dacPower.m can stay as it is. The single
%                     values are not circuit quantities. It REPLACES all
%                     three constants, so do not combine it with hand-set
%                     ones. No survey DAC is below 4 bit or 10 MS/s.
switch string(model)
    case "analytic"
        % unchanged
    case "analytic_1V"
        VDD = 1;
    case "survey"
        VDD = 1;
        I0  = 2.4e-6;
        Cp  = 0.25e-12;
    otherwise
        error('gearboxphy:dacPowerModel', 'Unknown dacPowerModel "%s".', string(model));
end
end
