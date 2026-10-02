function [PAPR_RRC, PAPR_RC,PAPR_baseband]=get_QAM_PAPR(M,rolloff)
% M=16;
% rolloff=0.5
%
%PERFORMANCE NOTE: result depends only on (M,rolloff), but Sim_Init.m
%calls this once per rate point in a sweep over hundreds of rates for the
%same M. Memoized below so repeat calls are O(1).

persistent cache
if isempty(cache)
    cache = containers.Map('KeyType','char','ValueType','any');
end
key = sprintf('%.15g_%.15g', M, rolloff);
if isKey(cache, key)
    out = cache(key);
    PAPR_RRC = out(1); PAPR_RC = out(2); PAPR_baseband = out(3);
    return
end

%QAM baseband PAPR
%PAPR_baseband=(3.*2.^b-1)./(2.^b+1);


%PAPR_baseband=(3*(sqrt(M)-1))/(sqrt(M)+1);
%PAPR Calculation
%Peak Power

constellation_points=-sqrt(M)+1:2:sqrt(M)-1;

constellation_points_c=qammod(0:M-1,M);

PAPR_baseband=(max(abs(constellation_points_c).^2))/(mean(abs(constellation_points_c).^2));

PAPR_RC=PAPR_baseband*(pi^2/(8 *rolloff))/(1-rolloff/4);

n=7;
Mean=mean(abs(constellation_points_c).^2);
%[Source]Root-raised cosine filter influences on PAPR distribution of single carrier signals
if (rolloff>0.4)
    k=1:(n-1)/2;
    C=(-1).^(k+1).*sin(rolloff.*k.*pi);
    D=4.*k.*rolloff.*(-1).^k.*cos(rolloff.*k.*pi);
    summe=sum(abs((C+D)./(k.*pi.*(1-(4.*k.*rolloff).^2))));
    Max=(max(abs(constellation_points_c).^2))*(1-rolloff+4*rolloff/pi+2*(summe))^2;
    PAPR_RRC=(Max/Mean);
elseif (rolloff<=0.4)
    k=1:(n-1)/2;
    A=(-1).^k.*cos(rolloff*pi/2*(1-2.*k));
    B=2*rolloff.*(1-2.*k).*(-1).^(k+1).*sin(rolloff*pi/2*(1-2.*k));
    summe=abs((A+B)./(pi/2.*(1-2.*k).*(1-(2.*(1-2.*k).*rolloff).^2 )  ) );
    Max=4*(max(abs(constellation_points_c).^2))*sum(summe)^2;
    PAPR_RRC=(Max/Mean);
end


%Technically above we have the PMEPR As such

PAPR_RRC=2*PAPR_RRC;
PAPR_RC=2*PAPR_RC;

cache(key) = [PAPR_RRC, PAPR_RC, PAPR_baseband]; %#ok<NASGU>
end