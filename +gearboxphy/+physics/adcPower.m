function P = adcPower(B, pow2_b, f_b, c_ADC)
%ADCPOWER ADC power draw for one channel pair (the "x2" for I/Q is baked
%   into this formula, matching the original per-gear formulas). ZXM
%   multiplies the result by M_tx at the call site; QAM/NA-QAM/Pulse use
%   it as-is. Shared once - previously copy-pasted across four
%   e_bit_fct_*.m files.
P = 2 * c_ADC * pow2_b * B * sqrt(1 + (B/f_b)^2);
end
