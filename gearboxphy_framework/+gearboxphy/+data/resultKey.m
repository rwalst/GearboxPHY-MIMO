function key = resultKey(gearName, order, f_c)
%RESULTKEY ONE canonical, sanitized result-file key builder - the single
%   place these strings are ever built. Replaces the hand-rolled strcat
%   filename construction that was duplicated across Sim_Init.m and
%   Wrapper.m (twice) in the original codebase, which is how two real
%   case-sensitivity bugs slipped in during this project's history
%   (dkEnergyRx/dkEnergyRX, MUI_ZXM_MTX/MUI_ZXM_Mtx). Lower-cased and
%   stripped of anything but alphanumerics, so there is no case choice
%   left to get wrong at any call site.
key = string(sprintf('%s_M%g_fc%gGHz', ...
    lower(regexprep(char(gearName), '[^a-zA-Z0-9]', '')), order, f_c/1e9));
end
