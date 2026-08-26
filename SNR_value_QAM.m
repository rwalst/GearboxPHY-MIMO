function [SNR] = SNR_value_QAM(SE,M,params)
%SNR_VALUE_QAM Required SNR [dB] for a given spectral efficiency SE, QAM.
%   Thin wrapper: see SNR_value_lookup.m for the shared interpolation
%   logic (previously duplicated verbatim across SNR_value_QAM/_ZXM/_Pulse).

SE_vec=params.mui_vec;
SNR_vec=params.SNR_vec;
if max(SE_vec)>log2(M)
    fprintf('oopsi. Das geht aber nicht');
end

SNR = SNR_value_lookup(SE, SE_vec, SNR_vec);

end
