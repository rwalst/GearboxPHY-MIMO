close all
clear all

%Hyper Parameters
numsims=400;
maxcores=200;
M_QAM_list=[4,16,64,256,1024];
params.maxiters=5e3; %max iterations for optimization
params.tolerance=1e-10; %precision requirements for optimization
params.numtriesPerOpt=20;

%define cell sizes

%this is the distance where the area (in a cell) between d_min and d_mean
%is equal to the area between d_mean and d_max. Assuming a uniform user
%distribution this means an equal amount of users is further away and
%closer than this distance
%d_mean=20;%evaluate at 20m
ZXM_list=[1,2,3];
%Pulse_list=["Energy","Arbitrary"];
Pulse_list=["Energy", "Arbitrary"];
pulse_jitter=[0.5, NaN];    %give a value for the jitter for energy, as this one is not dependent on it
params.fixed_LO_Pulse=table(Pulse_list,pulse_jitter);
%Pulse_list=[];
%Pulse_list=["Energy"];
%params.f_c=28 *10^9; %in Hz

f_c_vec=[2.4,8,28,60]*10^9;

params.distance=50;
params.pulse_filter="rc";
params.savefolder="Diss_Datapoints_v8_50m";

Plotonly=false;
OptOsc_Scheme=1;
linethickness=1.2;

R_vec=logspace(3 ,11,numsims);
num_gears=length(M_QAM_list)+length(ZXM_list)+length(Pulse_list);

% Parameters for Simulation
params.eta=0.1; %max bandwidth relative to carrier
params.epsilon_trans=0.01;
params.epsilon_rec=0.5;
params.alpha=0.5;
params.N_0=1.380649*10^(-23)*295;

params.beta=2; %pathloss component

params.c=3*10^8; %speed of light
params.c_PA=4.32*10^(-5); %PA constant
params.c_ADC=0.67.*10^(-15); %ADC constant
params.f_b  = 560*10^6; %bend frequency of ADC envelope
%new 2024 Data and using the best 20 ADCs for the envelope
%params.c_ADC=1.88.*10^(-15); %ADC constant
%params.f_b  =1000*10^6; %bend frequency of ADC envelope

params.NoiseFigure=10; %Receiver Noise figure
params.Maximum_P_T=10; %Max power in Watt
params.D_r=6;  %Antenna gain receiver
params.D_t=6;  %Antenna gain transmitter
%P_LO Berechnung
params.gamma_MOS=1;
%Assuming K. M. Megawer et al., "A Fast Startup CMOS Crystal Oscillator Using Two-Step Injection," in IEEE Journal of Solid-State Circuits, vol. 54, no. 12, pp. 3257-3268, Dec. 2019
% params.S_ref=2*10^(-160/10); %Equal to S_ref + S_CP in paper
% params.f_ref=54*10^6;
% params.Q_VCO=10;
% params.K_0_dB=-125;
% params.P_ref=0.2e-3;
%P_ADC Berechnung
%params.DAC_VDD=1; %supply Voltage in Volts
params.DAC_VDD=3; %supply Voltage in Volts
params.DAC_Cp=1e-12*1/2; %parasitic capacitance in F -  1/2 is needed because the dynamic power part needs to be halfed. Formel falsch gelesen
params.DAC_I0=10e-6; %unit current source in ampere
%Impulse Radio params
params.P_ED=2.4e-3;   %power of energy detector
%params.jitter_energy=0.3;




%generate file folder if it does not exist yet
if ~exist(params.savefolder, 'dir')
    mkdir(params.savefolder)
end



%First run optimization with variable oscillator to find optimal jitter at
%mean distance defined above

%%

pool=gcp('nocreate');
if(isempty(pool))
    parpool ('HPCServer',min(numsims,maxcores))
end

for f_=1:length(f_c_vec)
    params.f_c=f_c_vec(f_);
    fprintf(strcat('Running optimization f_c=',num2str(params.f_c.*10^(-9)), ' GHz \n'))
    %QAM
    modulation.family="QAM";
    modulation.order=NaN;
    for m=1:length(M_QAM_list)
        M_QAM=M_QAM_list(m);
        modulation.order=M_QAM;

        fprintf(strcat(num2str(M_QAM), "QAM\n"))

        parfor r=1:length(R_vec)
            Sim_Init(R_vec(r),modulation, params);
        end
    end
    %NA-QAM
    modulation.family="NA-QAM";
    modulation.order=max(M_QAM_list);
    fprintf("NA QAM\n")
    parfor r=1:length(R_vec)
        Sim_Init(R_vec(r),modulation, params);
    end
    %ZXM
    modulation.family="ZXM";
    modulation.order=NaN;
    for m=1:length(ZXM_list)
        M_tx=ZXM_list(m);
        modulation.order=M_tx;

        fprintf(strcat("M_tx=",num2str(M_tx), "ZXM\n"))
        %parfor r=1:length(R_vec)
        parfor r=1:length(R_vec)
            Sim_Init(R_vec(r),modulation, params);
        end
    end
    %Pulse schemes
    % So far they are all not dependent on phase jitter
    clear modulation %just to make sure
    modulation.family="Pulse";
    for m=1:length(Pulse_list)
        modulation.type=Pulse_list(m);
        modulation.order=1; %=M_tx
        fprintf(strcat(Pulse_list(m), " IR\n"))
        %PAPR raussuchen
        filename='SE_data/dkEnergyRX_ArbSign_SE99'; %case must match SE_data/dkEnergyRX_ArbSign_SE99.mat exactly on case-sensitive filesystems (e.g. the HPCServer cluster used above)
        load(filename);
        T_PAPR=struct2table(groupVal);
        if Pulse_list(m)=="Energy"
            logicmap=(T_PAPR.hTxName==params.pulse_filter) & (T_PAPR.modultn=="dkEnergyRX") & (T_PAPR.Mtx==modulation.order);

            %continue; %not dependent on PN. True, but we need the
            %values anyway
        elseif Pulse_list(m)=="Arbitrary"
            logicmap=(T_PAPR.hTxName==params.pulse_filter) & (T_PAPR.modultn=="maxArbSign") & (T_PAPR.Mtx==modulation.order);
        end
        params.PulsePAPR=T_PAPR.PAPR_dB(logicmap);
        %parfor r=1:length(R_vec)
        parfor r=1:length(R_vec)
            Sim_Init(R_vec(r),modulation, params);
        end
    end
    %save settings again (entire workspace) doppelt hält besser
    save(strcat(params.savefolder,'/01settings'));
end

    %% Combine results and plot
    %Plot List
    M_QAM_list=[16,64,256,1024];
    ZXM_list=[1,2,3];
    Pulse_list=["Energy", "Arbitrary"];
    legend_list_noNA=[Pulse_list+"-Pulse", "ZXM - Mtx="+ZXM_list,M_QAM_list+"-QAM"];
    legend_list=[legend_list_noNA, "NA-QAM"];


    linestyle_vec=["-","--",":","-."];
    
    savings_curve_plot=figure();
    optimalgearcurve_plot=figure();

for f_=1:length(f_c_vec)
    title_basestring=strcat('f_c=',num2str(f_c_vec(f_)*10^(-9)), ' GHz');
    Parameters_plot=figure();
    %bandwidth_curve_plot=figure();

    E_bit_NAQAM=NaN(1, length(R_vec));
    E_bit_Pulse=NaN( length(Pulse_list), length(R_vec));
    E_bit_ZXM=NaN(length(ZXM_list), length(R_vec));
    E_bit_QAM=NaN(length(M_QAM_list), length(R_vec));


    B_NAQAM=NaN( 1, length(R_vec));
    B_Pulse=NaN( length(Pulse_list), length(R_vec));
    B_ZXM=NaN( length(ZXM_list), length(R_vec));
    B_QAM=NaN(length(M_QAM_list), length(R_vec));

    gamma_NAQAM=NaN( 1, length(R_vec));
    gamma_Pulse=NaN( length(Pulse_list), length(R_vec));
    gamma_ZXM=NaN( length(ZXM_list), length(R_vec));
    gamma_QAM=NaN(length(M_QAM_list), length(R_vec));

    str_f_c = strrep(num2str(f_c_vec(f_)/10^9),'.','_');

    
    fprintf(strcat('Reading values values for d=',num2str(params.distance), 'm and f_c=' ,num2str(f_c_vec(f_)/10^9),'GHz\n'))
    params.LO_jitter_LNA_setting="fixed";
    %QAM
    modulation.family="QAM";
    modulation.order=NaN;
    for m=1:length(M_QAM_list)
        M_QAM=M_QAM_list(m);
        modulation.order=M_QAM;

        fprintf(strcat(num2str(M_QAM), "QAM\n"))

        for r=1:length(R_vec)
            R=R_vec(r);
            precision=5;
            str_rate=num2str(log10(R),precision);
            str_rate = strrep(str_rate,'.','_');
            
            filename=strcat(params.savefolder,'/','QAM_M=',num2str(M_QAM),'_fc=',str_f_c,'_log(R)=',str_rate, '_','d=',num2str(params.distance),'m_');

            loaded_Data=load(filename);
            E_bit_QAM(m,r)=loaded_Data.OptimalParameters.E_per_bit;
            B_QAM(m,r)=loaded_Data.OptimalParameters.Optimal_B;
            gamma_QAM(m,r)=loaded_Data.OptimalParameters.Optimal_gamma;
        end
    end

    %ZXM
    modulation.family="ZXM";
    modulation.order=NaN;
    for m=1:length(ZXM_list)
        M_tx=ZXM_list(m);
        modulation.order=M_tx;

        fprintf(strcat("M_tx=",num2str(M_tx), "ZXM\n"))
        %parfor r=1:length(R_vec)
        for r=1:length(R_vec)
            R=R_vec(r);
            M_tx=modulation.order;
            precision=5;
            str_rate=num2str(log10(R),precision);
            str_rate = strrep(str_rate,'.','_');
            
            filename=strcat(params.savefolder,'/','ZXM_Mtx=',num2str(M_tx),'_fc=',str_f_c,'_log(R)=',str_rate,'_','d=',num2str(params.distance),'m_');

            loaded_Data=load(filename);
            E_bit_ZXM(m,r)=loaded_Data.OptimalParameters.E_per_bit;
            B_ZXM(m,r)=loaded_Data.OptimalParameters.Optimal_B;
            gamma_ZXM(m,r)=loaded_Data.OptimalParameters.Optimal_gamma;
        end
    end
    %Pulse schemes
    % So far they are all not dependent on phase jitter
    clear modulation %just to make sure
    modulation.family="Pulse";
    for m=1:length(Pulse_list)
        modulation.type=Pulse_list(m);
        modulation.order=1; %=M_tx
        fprintf(strcat(Pulse_list(m), " IR\n"))
        for r=1:length(R_vec)
            R=R_vec(r);
            precision=5;
            str_rate=num2str(log10(R),precision);
            str_rate = strrep(str_rate,'.','_');
            
            filename=strcat(params.savefolder,'/','Pulse_',modulation.type,'d=',num2str(modulation.order),'_fc=',str_f_c,'_log(R)=',str_rate,'d=',num2str(params.distance),'m_');
            try
                loaded_Data=load(filename);
                E_bit_Pulse(m,r)=loaded_Data.OptimalParameters.E_per_bit;
                B_Pulse(m,r)=loaded_Data.OptimalParameters.Optimal_B;
                gamma_Pulse(m,r)=loaded_Data.OptimalParameters.Optimal_gamma;
            catch
                E_bit_Pulse(m,r)=NaN;
                B_Pulse(m,r)=NaN;
                gamma_Pulse(m,r)=NaN;
            end
        end
    end


    %NA-QAM
    modulation.family="NA-QAM";
    modulation.order=max(M_QAM_list);
    fprintf("NA QAM\n")
    for r=1:length(R_vec)
        R=R_vec(r);
        M=modulation.order;
        precision=5;
        str_rate=num2str(log10(R),precision);
        str_rate = strrep(str_rate,'.','_');
        %str_f_c = strrep(num2str(params.f_c/10^9),'.','_');
        filename=strcat(params.savefolder,'/','NA_QAM_M=',num2str(M),'_fc=',str_f_c,'_log(R)=',str_rate, '_','d=',num2str(params.distance),'m_');
        try
            loaded_Data=load(filename);
            E_bit_NAQAM(1,r)=loaded_Data.OptimalParameters.E_per_bit;
            B_NAQAM(1,r)=loaded_Data.OptimalParameters.Optimal_B;
            gamma_NAQAM(1,r)=loaded_Data.OptimalParameters.Optimal_gamma;
        catch
            fprintf("Oops")
            E_bit_NAQAM(1,r)=NaN;
        end
    end
    E_bit=[squeeze(E_bit_Pulse(:,:)); squeeze(E_bit_ZXM(:,:));squeeze(E_bit_QAM(:,:))];
    
    %smooth NaNs

        E_bit_smoothed=interpolateNAN(E_bit);

    

    %Lowest gear
    lowest=min(E_bit_smoothed,[], 1);
    savings=lowest./(E_bit_NAQAM);
    figure(Parameters_plot);
    clf
    subplot(4,1,1) %energy per bit
    %loglog(R_vec, E_bit)
    loglog(R_vec, interpolateNAN(squeeze(E_bit_Pulse(:,:))),'LineStyle', ':', 'LineWidth', 1)
    hold on
    loglog(R_vec, interpolateNAN(squeeze(E_bit_ZXM(:,:))),'LineStyle', '--', 'LineWidth', 1)
    loglog(R_vec, interpolateNAN(squeeze(E_bit_QAM(:,:))), 'LineWidth', 1)
    loglog(R_vec, interpolateNAN(squeeze(E_bit_NAQAM(:,:))),'LineStyle', ':', 'LineWidth', 1)
    legend(legend_list);
    grid on
    xlim([min(R_vec),max(R_vec)])
    ylim([1e-12,1e-4])
    title(strcat('E_bit ',title_basestring))
    ylabel('E_{bit}[J/bit]')
    xlabel('R_{eff} [bit/s]')

    subplot(4,1,2) %Bandwidth
    loglog(R_vec, interpolateNAN(squeeze(B_Pulse(:,:))),'LineStyle', ':', 'LineWidth', 1)
    hold on
    loglog(R_vec, interpolateNAN(squeeze(B_ZXM(:,:))),'LineStyle', '--', 'LineWidth', 1)
    loglog(R_vec, interpolateNAN(squeeze(B_QAM(:,:))), 'LineWidth', 1)
   % loglog(R_vec, interpolateNAN(squeeze(B_NAQAM(:,:))),'LineStyle', ':', 'LineWidth', 1)
    legend(legend_list);
    grid on
    xlim([min(R_vec),max(R_vec)])
    %ylim([1e-12,1e-4])
    title(strcat('Bandwdith  ',title_basestring))
    ylabel('B [Hz]')
    xlabel('R_{eff} [bit/s]')

    subplot(4,1,3) %Gamma
    loglog(R_vec, interpolateNAN(squeeze(gamma_Pulse(:,:))),'LineStyle', ':', 'LineWidth', 1)
    hold on
    loglog(R_vec, interpolateNAN(squeeze(gamma_ZXM(:,:))),'LineStyle', '--', 'LineWidth', 1)
    loglog(R_vec, interpolateNAN(squeeze(gamma_QAM(:,:))), 'LineWidth', 1)
    loglog(R_vec, interpolateNAN(squeeze(gamma_NAQAM(:,:))),'LineStyle', ':', 'LineWidth', 1)
    legend(legend_list);
    grid on
    xlim([min(R_vec),max(R_vec)])
    %ylim([1e-12,1e-4])
    title(strcat('gamma  ',title_basestring))
    ylabel('gamma')
    xlabel('R_{eff} [bit/s]')


    subplot(4,1,4) %Spectral Efficiency
    loglog(R_vec, interpolateNAN(squeeze(R_vec./(B_Pulse(:,:).*gamma_Pulse(:,:)))),'LineStyle', ':', 'LineWidth', 1)
    hold on
    loglog(R_vec,interpolateNAN(squeeze(R_vec./(B_ZXM(:,:).*gamma_ZXM(:,:)))),'LineStyle', '--', 'LineWidth', 1)
    loglog(R_vec,interpolateNAN(squeeze(R_vec./(B_QAM(:,:).*gamma_QAM(:,:)))), 'LineWidth', 1)
    loglog(R_vec,interpolateNAN(squeeze(R_vec./(params.eta*f_c_vec(f_).*gamma_NAQAM(:,:)))),'LineStyle', ':', 'LineWidth', 1)
    legend(legend_list);
    grid on
    xlim([min(R_vec),max(R_vec)])
    %ylim([1e-12,1e-4])
    title(strcat('Spectral Efficiency  ',title_basestring))
    ylabel('S [bit/s/Hz]')
    xlabel('R_{eff} [bit/s]')


    %Optimal Gear
    % Plot with optimal Mod Scheme
    %E_bit_2=[squeeze(E_bit_Pulse(:,:)); squeeze(E_bit_ZXM(:,:));squeeze(E_bit_QAM(:,:))];
    lowest=min(E_bit_smoothed,[], 1);
    opt_vec=NaN(1,length(R_vec));
    for r=1:length(R_vec)
        if(lowest(r)~=inf || ~isnan(lowest(r)))
            try
                opt_vec(r)=find(E_bit_smoothed(:,r)==lowest(r));
            catch
                opt_vec(r)=NaN;

            end
        end
    end
    figure(optimalgearcurve_plot);
    
    semilogx(R_vec,opt_vec,'DisplayName',strcat('f_c=', num2str(f_c_vec(f_)*10^(-9))),'LineStyle',linestyle_vec(f_));
    hold on
    yticks(1:length(M_QAM_list)+length(ZXM_list)+length(Pulse_list))
    yticklabels(legend_list_noNA)
    title(strcat('Optimal Gear ',title_basestring))
    legend
    %
    %savings_curve_plot=figure();

    figure(savings_curve_plot);
    
    %loglog(R_vec, E_bit)
    loglog(R_vec, squeeze(savings), 'LineWidth', 1,'DisplayName',strcat('f_c=', num2str(f_c_vec(f_)*10^(-9))),'LineStyle',linestyle_vec(f_))
    hold on
    grid on
    xlim([min(R_vec),max(R_vec)])
    ylim([10^(floor(log10(min(savings,[],'all')))),1])
    %title(strcat('distance=',num2str(params.distance),'m','_f_c=',num2str(params.f_c.*10^(-9)), ' GHz'))
    ylabel('E_{bit,Gearbox}/E_{bit,singleGear}')
    xlabel('R_{eff} [bit/s]')
    title(strcat('Savings ',title_basestring))
    legend
    %mean savings
end


function out=interpolateNAN(in)
for i_=1:size(in,1)
    in_vec=in(i_,:);
    X = ~isnan(in_vec);
    Y = cumsum(X-diff([1,X])/2);
    out(i_,:)= interp1(1:nnz(X),in_vec(X),Y);
end
end

%% power budget plot for
M_QAM=1024; %QAM
str_f_c = strrep(num2str(f_c_vec(3)/10^9),'.','_');%for 28GHz
modulation.order=M_QAM;

fprintf(strcat(num2str(M_QAM), "QAM\n"))

%Preallocate every entry with NaN fields up front. Previously, Power(r)
%was only ever assigned inside the if-branch below; any r whose point was
%infeasible (E_per_bit==NaN) left Power(r) unassigned, and MATLAB backfills
%such gaps in a struct array with EMPTY ([]) fields rather than NaN. Since
%[Power.DAC] etc. concatenate via a comma-separated list, an empty field
%contributes nothing to the result instead of a placeholder - so any
%infeasible point silently shifted every later entry out of alignment
%with R_vec instead of producing a NaN at its own position.
Power = repmat(struct('PA',NaN,'DAC',NaN,'LO_Tx',NaN,'Mix_Tx',NaN, ...
    'LNA',NaN,'LO_Rx',NaN,'Mix_Rx',NaN,'ADC',NaN), 1, length(R_vec));

for r=1:length(R_vec)
    R=R_vec(r);
    precision=5;
    str_rate=num2str(log10(R),precision);
    str_rate = strrep(str_rate,'.','_');

    filename=strcat(params.savefolder,'/','QAM_M=',num2str(M_QAM),'_fc=',str_f_c,'_log(R)=',str_rate, '_','d=',num2str(params.distance),'m_');

    loaded_Data=load(filename);
    if( ~isnan(loaded_Data.OptimalParameters.E_per_bit))
        Power(r)=loaded_Data.PowerBudget;
    end
    %else: leave the NaN-filled placeholder from the preallocation above,
    %so Power(r) still lines up with R_vec(r).
end

Power_Tx=[Power.DAC]+[Power.PA]+[Power.LO_Tx]+[Power.Mix_Tx];
Power_Rx=[Power.LNA]+[Power.LO_Rx]+[Power.Mix_Rx]+[Power.ADC];
Full_Power=Power_Tx+Power_Rx;
Portion_PA=[Power.PA] ./ Full_Power;
Portion_LO_Tx=[Power.LO_Tx] ./ Full_Power;
Portion_Mixer_Tx=[Power.Mix_Tx] ./ Full_Power;
Portion_LNA=[Power.LNA] ./ Full_Power;
Portion_ADC=[Power.ADC] ./ Full_Power;
Portion_DAC=[Power.DAC] ./ Full_Power;
Portion_LO_Rx=[Power.LO_Rx] ./ Full_Power;
Portion_Mixer_Rx=[Power.Mix_Rx] ./ Full_Power;

Area=[Portion_DAC;Portion_PA;Portion_LO_Tx;Portion_Mixer_Tx;Portion_LNA;Portion_LO_Rx;Portion_Mixer_Rx;Portion_ADC];
%end
figure
area(R_vec(1:length(Area)),Area.')
legend('DAC','PA','LO Tx','Mix Tx','LNA', 'LO Rx','Mix Rx', 'ADC')
str_Pow_title=strcat('Power for M=', num2str(M_QAM), 'QAM');
title(str_Pow_title)
set(gca, 'XScale', 'log')
xlabel('R_{eff} [bit/s]')
ylabel('Relative Power')
xlim([1e6, 1e11])