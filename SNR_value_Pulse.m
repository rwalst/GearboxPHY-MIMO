function [SNR] = SNR_value_Pulse(SE,params)
%SNR_VALUE Summary of this function goes here
%   Detailed explanation goes here

clear SE_vec
clear SNR_vec

SE_vec=params.SE_vec;
SNR_vec=params.SNR_vec;
if max(SE_vec>2)
    fprintf('oopsi. Das geht aber nicht');
end

end_idx=find(SE_vec==max(SE_vec),1);
start_idx=find(SE_vec,1,'first');
%find(SE_vec,0,'last')
SE_vec=SE_vec(start_idx:end_idx); %wegen Quadratur ACHTUNG
SNR_vec=SNR_vec(start_idx:end_idx);


SNR=interp1(SE_vec, SNR_vec,SE,'linear',NaN);

%returns NaN if its outside of domain
for s_=1:length(SE)
    if isnan(SNR(s_))
        if SE(s_)>max(SE_vec)
            SNR(s_)=inf; %if SNR is higher than domain, use saturated value
        elseif SE(s_)<min(SE_vec)
            %assumption that for low SNR the AWGN capacity is (almost) reached
            SNR(s_)=0; %??
        end
    end
end





end

