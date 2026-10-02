function [SNR] = SNR_value_ZXM(SE,params)
%SNR_VALUE_ZXM Required SNR [dB] for a given mutual information SE, ZXM.
%   Thin wrapper: see SNR_value_lookup.m for the shared interpolation
%   logic (previously duplicated verbatim across SNR_value_QAM/_ZXM/_Pulse).

SE_vec=params.SE_vec;
SNR_vec=params.SNR_vec;
if max(SE_vec>4)
    fprintf('oopsi. Das geht aber nicht');
end

SNR = SNR_value_lookup(SE, SE_vec, SNR_vec);

end
