function out = e_bit_fct_Pulse(x,params,modulation,R,flag)
%E_BIT_FCT Ebit function for pulse schemes
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
%bw_factor=params.bw_factor;   %get 95% containment BW NOT required for
%Impulse
%PAPR_RRC=params.PAPR_RRC;
N_0=params.N_0;
P_Mix=params.P_Mix;
f_c=params.f_c;

B=10^x(1);
gamma=x(2);
B_max=eta*f_c;
%gamma=1;
%alpha=x(3);
%b=sqrt(M)/2;    %per I/Q dimension

if modulation.type=="Energy"
    b=1;
elseif modulation.type=="Arbitrary"
    b=1.59;
end



%M_=M;
%first check input variables
if(gamma<0 || gamma>1 || B>B_max || B<0)
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

%get required snr
SNR_rec=SNR_value_Pulse(S,params);

%this snr gets degraded by path loss and noise figure
SNR_transmitter=SNR_rec+10*log10(L);





%transmit power
P_t=10^(SNR_transmitter/10)*N_0*B;

if (P_t>Maximum_P_T)
    out=inf;
    return
end

%PAPR_QAM_Linear=3*(sqrt(M)-1)/(sqrt(M)+1);

%PAPR=10^((10*log10(PAPR_QAM_Linear)+3+3.17)/10);

%hardware power
P_PA=c_PA*P_t*sqrt(f_c)*10^(params.PulsePAPR/10);
P_ADC=2*c_ADC*2^(b)*B*sqrt(1+(B/f_b)^2);
P_LNA=9.9848*10^(-5)*f_c^(0.2)*10^(-1);
%Mezghani LNA model
FoM_LNA=10^(-7);
P_LNA=32*B*N_0/((3-1)*FoM_LNA);


P_LNA=32*B*N_0/((3-1)*FoM_LNA);

P_DAC=2*(1/2*params.DAC_VDD*params.DAC_I0*(2^b-1)+params.DAC_Cp*params.DAC_VDD^2*b*B);

%Calculate P_LO


P_LO=params.P_LO*0.7; %single ended!

%P_Mix=0.3*P_LO; %ACHTUNG, STARK HEURISTISCH

P_EnergyDetector=params.P_ED;

if modulation.type=="Energy"

    ebit=1/R*( (gamma+epsilon_trans*(1-gamma))*(P_PA+P_DAC+P_LO) +(gamma+epsilon_rec*(1-gamma))*(P_ADC+P_LNA+P_EnergyDetector) );
    %e_bit_no_const=1/R_eff*( (gamma+epsilon_trans*(1-gamma))*(P_PA+P_DAC) +(gamma+epsilon_rec*(1-gamma))*(P_ADC+P_LNA+P_LDPC) );
elseif modulation.type=="Arbitrary"
    ebit=1/R*( (gamma+epsilon_trans*(1-gamma))*(P_PA+P_DAC+P_LO) +(gamma+epsilon_rec*(1-gamma))*(P_ADC+P_LNA+P_LO+P_Mix) );
end
if strcmp(flag,"budget")
    out.PA=1/R*(gamma+epsilon_trans*(1-gamma))*(P_PA);
    out.DAC=1/R*(gamma+epsilon_trans*(1-gamma))*(P_DAC);
    out.LO_Tx=1/R*(gamma+epsilon_trans*(1-gamma))*(P_LO);
    out.Mix_Tx=0;
    out.LNA=1/R*(gamma+epsilon_rec*(1-gamma))*(P_LNA);
    if modulation.type=="Energy"
        out.EnergyDetector=1/R*(gamma+epsilon_rec*(1-gamma))*(P_EnergyDetector);
    elseif modulation.type=="Arbitrary"
        out.LO_Rx=1/R*(gamma+epsilon_rec*(1-gamma))*(P_LO);
        out.Mix_Rx=1/R*(gamma+epsilon_rec*(1-gamma))*(P_Mix);
    end
    out.ADC=1/R*(gamma+epsilon_rec*(1-gamma))*(P_ADC);
    return
else
    out=ebit;
    return ;
end
end

