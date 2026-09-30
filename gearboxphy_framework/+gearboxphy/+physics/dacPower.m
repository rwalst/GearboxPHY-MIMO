function P = dacPower(B, b, pow2_b, DAC_VDD, DAC_I0, DAC_Cp)
%DACPOWER DAC power draw for one channel pair (the "x2" for I/Q is baked
%   into this formula). ZXM multiplies the result by M_tx at the call
%   site. Shared once - previously copy-pasted across four e_bit_fct_*.m
%   files.
P = 2 * (1/2*DAC_VDD*DAC_I0*(pow2_b-1) + DAC_Cp*DAC_VDD^2*b*B);
end
