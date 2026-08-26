function out = e_bit_fct_QAM_v2(x,params,M,R,f_c,flag)
%E_BIT_FCT Summary of this function goes here
%   Detailed explanation goes here

%"unpack" params (too lazy to rewrite all equations)
% Parameters
eta=params.eta; %max bandwidth relative to carrier
epsilon_trans=params.epsilon_trans;
epsilon_rec=params.epsilon_rec;
alpha=params.alpha;

distance=params.distance; %comm. systems in m
beta=params.beta; %pathloss component

c=params.c; %speed of light
c_PA=params.c_PA; %PA constant
c_ADC=params.c_ADC; %ADC constant
f_b=params.f_b; %bend frequency of ADC envelope
NoiseFigure=params.NoiseFigure; %Receiver Noise figure
Maximum_P_T=params.Maximum_P_T; %Max power in Watt
D_r=params.D_r;  %Antenna gain receiver
D_t=params.D_t;  %Antenna gain transmitter
%bw_factor=params.bw_factor;   %get 95% containment BW
%params.PAPR_RRC is no longer set upstream (Sim_Init.m) - it was dead:
%unpacked here but never referenced below, since PAPR is instead computed
%from M directly a few lines down.
N_0=params.N_0;
P_Mix=params.P_Mix;

B_max=eta*f_c;
B=10^x(1);
gamma=x(2);

%gamma=1;
%alpha=x(3);
%b=sqrt(M)/2;    %per I/Q dimension
b=log2(sqrt(M));
%M_=M;
%first check input variables
if(gamma<0 || gamma>1 || B>B_max|| B<0 )
    out=inf;
    return
end

if(B>B_max )
    out=inf;
    return
end

%now calculate energy per bit
lambda=c/f_c;
L=( D_r*D_t*(lambda/(4*pi*distance))^beta  )^(-1); %To match definition in paper

S=R/(gamma*B);
%S=R*bw_factor/(gamma*B);
%S=R/(gamma*B*bw_factor);
%% now calculate resulting sigma j based on Wiener filtering theory
%first calculate SNR for observations


%get required snr
SNR_rec=SNR_value_QAM(S,M,params);

%this snr gets degraded by path loss and noise figure
SNR_transmitter=SNR_rec+10*log10(L);





%transmit power
P_t=10^(SNR_transmitter/10)*N_0*B;%*bw_factor;

if (P_t>Maximum_P_T)
    out=inf;
    return
end

PAPR_QAM_Linear=3*(sqrt(M)-1)/(sqrt(M)+1);

PAPR=10^((10*log10(PAPR_QAM_Linear)+3+3.17)/10);

%hardware power
P_PA=c_PA*P_t*sqrt(f_c)*PAPR;
P_ADC=2*c_ADC*2^(b)*B*sqrt(1+(B/f_b)^2);
%Mezghani LNA model
FoM_LNA=10^(-7);
P_LNA=32*B*N_0/((3-1)*FoM_LNA);



P_DAC=2*(1/2*params.DAC_VDD*params.DAC_I0*(2^b-1)+params.DAC_Cp*params.DAC_VDD^2*b*B);


% P_LO=P_LO+params.P_ref;
P_LO=params.P_LO;
%separate sleep modes transmitter and receiver
ebit=1/R*( (gamma+epsilon_trans*(1-gamma))*(P_PA+P_DAC+P_LO+P_Mix) +(gamma+epsilon_rec*(1-gamma))*(P_ADC+P_LNA+P_LO+P_Mix) );
%e_bit_no_const=1/R_eff*( (gamma+epsilon_trans*(1-gamma))*(P_PA+P_DAC) +(gamma+epsilon_rec*(1-gamma))*(P_ADC+P_LNA+P_LDPC) );

if strcmp(flag,"budget")
    out.PA=1/R*(gamma+epsilon_trans*(1-gamma))*(P_PA);
    out.DAC=1/R*(gamma+epsilon_trans*(1-gamma))*(P_DAC);
    out.LO_Tx=1/R*(gamma+epsilon_trans*(1-gamma))*(P_LO);
    out.Mix_Tx=1/R*(gamma+epsilon_trans*(1-gamma))*(P_Mix);
    out.LNA=1/R*(gamma+epsilon_rec*(1-gamma))*(P_LNA);
    out.LO_Rx=1/R*(gamma+epsilon_rec*(1-gamma))*(P_LO);
    out.Mix_Rx=1/R*(gamma+epsilon_rec*(1-gamma))*(P_Mix);
    out.ADC=1/R*(gamma+epsilon_rec*(1-gamma))*(P_ADC);
      return 
else
    out=ebit;
    return ;
end
end

