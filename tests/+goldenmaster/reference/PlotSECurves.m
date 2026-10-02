clear all
close all
M_QAM_list=[4,16,64,256,1024];
ZXM_list=[1,2,3];
Pulse_list=["Energy", "Arbitrary"];
%QAM
figure
hold on
for m_=1:length(M_QAM_list)
    M=M_QAM_list(m_);
    filename_SE=strcat('SE_data/','SE_',num2str(M),'_QAM','.mat');
    load(filename_SE);

    bw_factor=get_p_containment_bw(0.5,99);   %get 99% containment BW
    plot(SNR_vec, SE_vec./bw_factor, 'DisplayName',strcat(num2str(M),'-QAM'));
end

%ZXM
for m_=1:length(ZXM_list)
    M_tx=ZXM_list(m_);
    filename_SE=strcat('SE_data/','MUI_ZXM_MTX=',num2str(M_tx),'_sigmaPN=-5','.mat');
    load(filename_SE);
    bw_factorZXM=get_p_containment_bw_ZXM(0.5,99,M_tx);
    plot(SNR_dB_vec, I_vec./bw_factor, 'DisplayName',strcat('ZXM, M_tx=',num2str(M_tx)));
end

%unipolar
filename_SE=strcat('SE_data/','SE_Unipolar_IR_v2','.mat');
load(filename_SE);
plot(SNR, SE, 'DisplayName','Unipolar IR');
%Arbitrary
filename_SE=strcat('SE_data/','SE_Arbitrary_IR_v2','.mat');
load(filename_SE);
plot(SNR, SE,'DisplayName','variable-sign IR');

legend