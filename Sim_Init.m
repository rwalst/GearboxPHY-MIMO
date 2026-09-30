function Sim_Init(R,modulation, params)



%2.4 GHz
if (params.f_c==2.4*10^9)
    params.P_Mix=1.57*10^(-3);%[Source]:S. Murad, S. Mohyar, A. Harun, M. Yasin, I. Ishak, and R. Sapawi, “Low
    %noise figure 2.4 GHz down conversion CMOS mixer for wireless sensor
    %%network application," in Proc. 2016 IEEE Student Conf. Res. Develop.,
    %Kuala Lumpur, Malaysia, Dec. 2016, pp. 1–
    params.P_LO=6*10^(-3); %[Source]: ] J. Jin, “Low power current-mode voltage controlled oscillator for 2.4
    %GHz wireless applications," Comput. & Elect. Eng., vol. 40, no. 1, pp.
    %92–99, 2014.


    %28GHz
elseif (params.f_c==28*10^9)
    params.P_Mix=8.4*10^(-3); %[Source]: Y.-T. Chang and K.-Y. Lin, "A 28-GHz bidirectional active Gilbert-cell mixer in 90-nm CMOS,”
    params.P_LO=26.9*10^(-3); 



elseif (params.f_c==60*10^9)
    %60GHz
    params.P_Mix=17*10^(-3); %[Source]: J. Lee and Y. Lin, "60 GH CMOS downconversion mixer with 15.46 dB gain and 64.7 dB LO-RF isolation," Electron. Lett., vol. 49, no. 4,
    params.P_LO=60*10^(-3); %[Source]: S. Pinel et al., "A 90nm CMOS 60GHz radio"

    %120 GHz
elseif (params.f_c==120*10^9)
    params.P_Mix=8*10^(-3);%[Source]:Shenghui Yang, "A High‑Linearity Down‑Conversion
    % Mixer with Modified Transconductance Stage about 120 GHz"
    params.P_LO=43*10^(-3); %[Source]: Shenghui Yang, "Two implementations of 120 GHz
    % transformercross‐coupled oscillator based on cascode structure in
    % 55nm CMOS technology"

    %8GHz
elseif (params.f_c==8*10^9)
       params.P_Mix=6.9*10^(-3);
        params.P_LO=14.9*10^(-3); %siehe diss
elseif(params.f_c==6*10^9)
    params.eta=0.3; %Wifi7
    params.P_Mix=1.57*10^(-3);%[Source]:S. Murad, S. Mohyar, A. Harun, M. Yasin, I. Ishak, and R. Sapawi, “Low
    %noise figure 2.4 GHz down conversion CMOS mixer for wireless sensor
    %%network application," in Proc. 2016 IEEE Student Conf. Res. Develop.,
    %Kuala Lumpur, Malaysia, Dec. 2016, pp. 1–
    params.P_LO=6*10^(-3); %[Source]: ] J. Jin, “Low power current-mode voltage controlled oscillator for 2.4

elseif(params.f_c==6.1*10^9)
    % params.epsilon_trans=0.5; Warum?
    % params.epsilon_rec=1 Warum?
    params.eta=0.3; %Wifi7
    params.P_Mix=1.57*10^(-3);%[Source]:S. Murad, S. Mohyar, A. Harun, M. Yasin, I. Ishak, and R. Sapawi, “Low
    %noise figure 2.4 GHz down conversion CMOS mixer for wireless sensor
    %%network application," in Proc. 2016 IEEE Student Conf. Res. Develop.,
    %Kuala Lumpur, Malaysia, Dec. 2016, pp. 1–
    params.P_LO=6*10^(-3); %[Source]: ] J. Jin, “Low power current-mode voltage controlled oscillator for 2.4
else
    error(strcat('f_c=',num2str(params.f_c),'not supported'))
end





if modulation.family=="QAM"
    M=modulation.order;
    %as the rolloff is fixed for now we can also precompute the following 2
    precision=5;
    str_rate=num2str(log10(R),precision);
    str_rate = strrep(str_rate,'.','_');
    str_f_c = strrep(num2str(params.f_c/10^9),'.','_');
    filename=strcat(params.savefolder,'/','QAM_M=',num2str(M),'_fc=',str_f_c,'_log(R)=',str_rate, '_','d=',num2str(params.distance),'m_');

    if ~exist(strcat(filename,".mat"),'file')

        %read SE vector
        filename_SE=strcat('SE_data/','SE_',num2str(M),'_QAM','.mat');
        SE_data=load_mat_cached(filename_SE);

        params.bw_factor=get_p_containment_bw(params.alpha,99);   %get 99% containment BW
        %NOTE: params.PAPR_RRC used to be set here via get_QAM_PAPR, but
        %its value is never read anywhere downstream (e_bit_fct_QAM_v2.m
        %unpacks it into a local variable it never uses, computing its
        %own simpler PAPR from M directly instead) - removed as dead work.

        params.SNR_vec=SE_data.SNR_vec;
        params.mui_vec=SE_data.SE_vec./params.bw_factor;

        [OptimalParameters,PowerBudget]=get_min_E_bit_QAM(R, M, params);


        save(filename,'OptimalParameters','PowerBudget');
    end
elseif modulation.family=="NA-QAM"
    M=modulation.order;
    precision=5;
    str_rate=num2str(log10(R),precision);
    str_rate = strrep(str_rate,'.','_');
    str_f_c = strrep(num2str(params.f_c/10^9),'.','_');
    filename=strcat(params.savefolder,'/','NA_QAM_M=',num2str(M),'_fc=',str_f_c,'_log(R)=',str_rate, '_','d=',num2str(params.distance),'m_');
    if ~exist(strcat(filename,".mat"),'file')
        %read SE vector
        filename_SE=strcat('SE_data/','SE_',num2str(M),'_QAM','.mat');
        SE_data=load_mat_cached(filename_SE);

        params.bw_factor=get_p_containment_bw(params.alpha,99);   %get 99% containment BW
        %NOTE: params.PAPR_RRC used to be set here via get_QAM_PAPR, but
        %its value is never read anywhere downstream (e_bit_fct_NA_QAM_v2.m
        %unpacks it into a local variable it never uses, computing its
        %own simpler PAPR from M directly instead) - removed as dead work.

        params.SNR_vec=SE_data.SNR_vec;
        params.mui_vec=SE_data.SE_vec./params.bw_factor;

        [OptimalParameters,PowerBudget]=get_min_E_bit_NA_QAM(R, M, params);


        save(filename,'OptimalParameters','PowerBudget');
    end
elseif modulation.family=="ZXM"
    M_tx=modulation.order;
    precision=5;
    str_rate=num2str(log10(R),precision);
    str_rate = strrep(str_rate,'.','_');
    str_f_c = strrep(num2str(params.f_c/10^9),'.','_');
    filename=strcat(params.savefolder,'/','ZXM_Mtx=',num2str(M_tx),'_fc=',str_f_c,'_log(R)=',str_rate,'_','d=',num2str(params.distance),'m_');
    if ~exist(strcat(filename,".mat"),'file')
       %read SE vector
        %filename_SE=strcat('SE_data/','SE_MTX_',num2str(M_tx),'_ZXM','.mat');
        filename_SE=strcat('SE_data/','MUI_ZXM_Mtx=',num2str(M_tx),'_sigmaPN=-5','.mat'); %case must match SE_data/MUI_ZXM_Mtx=...mat exactly on case-sensitive filesystems (e.g. the HPCServer cluster targeted by Wrapper.m)
        SE_data=load_mat_cached(filename_SE);

        params.bw_factorZXM=get_p_containment_bw_ZXM(params.alpha,99,M_tx);

        params.SNR_vec=SE_data.SNR_dB_vec;
        params.SE_vec=SE_data.I_vec./params.bw_factorZXM;

        %das brauchen wir hier nicht
        [OptimalParameters,PowerBudget]=get_min_E_bit_ZXM(R,M_tx , params);


        save(filename,'OptimalParameters','PowerBudget');
    end
elseif modulation.family=="Pulse"
    %d=M;


    precision=5;
    str_rate=num2str(log10(R),precision);
    str_rate = strrep(str_rate,'.','_');
    str_f_c = strrep(num2str(params. f_c/10^9),'.','_');
    filename=strcat(params.savefolder,'/','Pulse_',modulation.type,'d=',num2str(modulation.order),'_fc=',str_f_c,'_log(R)=',str_rate,'d=',num2str(params.distance),'m_');
    if ~exist(strcat(filename,".mat"),'file')
        %read in SE vectors
        available_sigma_j=[0.00853 0.0127 0.0189 0.0281  0.0418 0.0621 0.0924 0.137 0.204 0.304 0.452 0.672 1];
        if strcmp(modulation.type,"Energy")
            M_tx=modulation.order;

            %read SE vector
            filename_SE=strcat('SE_data/','SE_Unipolar_IR','.mat');
            SE_data=load_mat_cached(filename_SE);

            params.SNR_vec=SE_data.SNR;
            params.SE_vec=SE_data.SE;%das ist hier wirklich die SE (die Kurven hatte Floria

        elseif strcmp(modulation.type,"Arbitrary")

            %read SE vector
            filename_SE=strcat('SE_data/','SE_Arbitrary_IR','.mat');
            SE_data=load_mat_cached(filename_SE);

            params.SNR_vec=SE_data.SNR;
            params.SE_vec=SE_data.SE;%das ist hier wirklich die SE (die Kurven hatte Floria

        end

        [OptimalParameters,PowerBudget]=get_min_E_bit_Pulse(R, modulation, params);

        save(filename,'OptimalParameters','PowerBudget');
    end
    %
    %
    % elseif modulation_type=="dk"
    %     d=M;
    %     [E_per_bit,Optimal_B,Optimal_gamma,Optimal_sigma]=get_min_E_bit_dk(R, d, params);
    %
    %     precision=5;
    %     str_rate=num2str(log10(R),precision);
    %     str_rate = strrep(str_rate,'.','_');
    %     str_f_c = strrep(num2str(params. f_c/10^9),'.','_');
    %     filename=strcat(params.savefolder,'/','dk_d=',num2str(d),'_fc=',str_f_c,'_log(R)=',str_rate);
    %     save(filename,'E_per_bit','Optimal_B','Optimal_gamma','Optimal_sigma');

else
    error('Modulation not supported')
end