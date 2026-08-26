function [params,Power] = get_params(R,f_c, Modulation_type,M, B, gamma, sigma_j,distance)
%GET_PARAMS Summary of this function goes here
%   Detailed explanation goes here%

%init
Power.ADC=NaN;
Power.DAC=NaN;
Power.Mixer=NaN;
Power.LO=NaN;
Power.LNA=NaN;
Power.PA=NaN;


params.eta=0.1; %max bandwidth relative to carrier
params.epsilon_trans=0.01;
params.epsilon_rec=0.5;
epsilon_trans=params.epsilon_trans;
epsilon_rec=params.epsilon_rec;
params.alpha=0.4;
params.N_0=1.380649*10^(-23)*295;

params.f_c=28*10^9; %in Hz

params.distance=20; %comm. systems in m
params.beta=2; %pathloss component

params.c=3*10^8; %speed of light
params.c_PA=4.32*10^(-5); %PA constant
params.c_ADC=2*0.67.*10^(-15); %ADC constant
params.f_b  = 560*10^6; %bend frequency of ADC envelope
params.NoiseFigure=10; %Receiver Noise figure
params.Maximum_P_T=10; %Max power in Watt
params.D_r=6;  %Antenna gain receiver
params.D_t=6;  %Antenna gain transmitter

%P_LO Berechnung
params.gamma_MOS=1;
params.S_ref=10^(-176/10);
params.f_ref=100*10^6;
params.Q_VCO=10;
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
    params.P_LO=10.8*10^(-3); %[Source]: Y. Fu, L. Li, D. Wang, X. Wang, and L. He, "28-GHz CMOS VCO with capacitive splitting and transformer feedback techniques for 5G communication,"



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

elseif(params.f_c==6*10^9)
    params.eta=0.3; %Wifi7
    params.P_Mix=1.57*10^(-3);%[Source]:S. Murad, S. Mohyar, A. Harun, M. Yasin, I. Ishak, and R. Sapawi, “Low
    %noise figure 2.4 GHz down conversion CMOS mixer for wireless sensor
    %%network application," in Proc. 2016 IEEE Student Conf. Res. Develop.,
    %Kuala Lumpur, Malaysia, Dec. 2016, pp. 1–
    params.P_LO=6*10^(-3); %[Source]: ] J. Jin, “Low power current-mode voltage controlled oscillator for 2.4

elseif(params.f_c==6.1*10^9)
    params.epsilon_trans=0.5;
    params.epsilon_rec=1;
    params.eta=0.3; %Wifi7
    params.P_Mix=1.57*10^(-3);%[Source]:S. Murad, S. Mohyar, A. Harun, M. Yasin, I. Ishak, and R. Sapawi, “Low
    %noise figure 2.4 GHz down conversion CMOS mixer for wireless sensor
    %%network application," in Proc. 2016 IEEE Student Conf. Res. Develop.,
    %Kuala Lumpur, Malaysia, Dec. 2016, pp. 1–
    params.P_LO=6*10^(-3); %[Source]: ] J. Jin, “Low power current-mode voltage controlled oscillator for 2.4
else
    error(strcat('f_c=',num2str(params.f_c),'not supported'))
end

params.bw_factor=get_p_containment_bw(params.alpha,95);   %get 95% containment BW
params.PAPR_RRC=get_QAM_PAPR(M,params.alpha);

if strcmp(Modulation_type,"QAM")
    %ADC
    b=log2(sqrt(M));
    
    
    lambda=params.c/f_c;
    beta=2;
    
L=( params.D_r*params.D_t*(lambda/(4*pi*distance))^beta  )^(-1); %To match definition in paper

S=R/(gamma*B*params.bw_factor);

%get required snr
try
SNR_rec=SNR_value(S,"QAM",M,sigma_j);
catch
    SNR_rec=inf;
end
%this snr gets degraded by path loss and noise figure
SNR_transmitter=SNR_rec+10*log10(L);


k= physconst('Boltzmann');



%transmit power
P_t=10^(SNR_transmitter/10)*params.N_0*B*params.bw_factor;


PAPR_QAM_Linear=3*(sqrt(M)-1)/(sqrt(M)+1);

PAPR=10^((10*log10(PAPR_QAM_Linear)+3+3.17)/10);

%hardware power
Power.PA= (gamma+epsilon_trans*(1-gamma))*(params.c_PA*P_t*sqrt(f_c)*PAPR);
Power.ADC=(gamma+epsilon_rec*(1-gamma))*(2*params.c_ADC*2^(b)*B*sqrt(1+(B/params.f_b)^2));
%Mezghani LNA model
FoM_LNA=10^(-7);
Power.LNA=(gamma+epsilon_rec*(1-gamma))*(32*B*params.N_0/((3-1)*FoM_LNA));

Power.DAC=(gamma+epsilon_trans*(1-gamma))*2*(1.5*10^(-5)*2^b+9*10^(-12)*b*B);

%Calculate P_LO

Power.LO=((gamma+epsilon_trans*(1-gamma))+(gamma+epsilon_rec*(1-gamma)))* k*300*(1+params.gamma_MOS)*params.S_ref/(pi*params.Q_VCO*params.f_ref)^2*((2*pi*f_c/sigma_j)^4);
Power.Mixer=((gamma+epsilon_trans*(1-gamma))+(gamma+epsilon_rec*(1-gamma)))*params.P_Mix;
%e_bit=1/R*( (gamma+epsilon_trans*(1-gamma))*(P_PA+P_DAC+P_LO+P_Mix) +(gamma+epsilon_rec*(1-gamma))*(P_ADC+P_LNA+P_LO+P_Mix) );
end

end

