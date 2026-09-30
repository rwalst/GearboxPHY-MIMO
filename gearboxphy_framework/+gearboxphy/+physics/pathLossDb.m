function L_dB = pathLossDb(f_c, distance, D_r, D_t, beta, c)
%PATHLOSSDB Free-space path loss [dB], matching the dissertation's
%   definition (ported from the "L" derivation duplicated across all
%   four get_min_E_bit_*.m files in the original codebase).
lambda = c / f_c;
L = (D_r * D_t * (lambda/(4*pi*distance))^beta)^(-1);
L_dB = 10*log10(L);
end
