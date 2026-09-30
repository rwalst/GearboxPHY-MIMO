function P = lnaPower(B, N_0)
%LNAPOWER Mezghani LNA power model. FoM_LNA is a fixed technology
%   constant (1e-7) that was never varied anywhere in the original
%   codebase, so it's baked in here rather than threaded through every
%   call site. Shared once - previously copy-pasted across four
%   e_bit_fct_*.m files (including a dead duplicate first computation,
%   already fixed in an earlier pass over the original code).
FoM_LNA = 1e-7;
P = 32 * B * N_0 / ((3-1) * FoM_LNA);
end
