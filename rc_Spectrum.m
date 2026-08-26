function [H] = rc_Spectrum(f,T,beta,varargin)
%RC_SPECTRUM computes the spectrum of a Raised Cosine Filter defined by T
% and rolloff factor beta at the frequency f.
% Optional string specifies normalization:
%   - 'normAmplitude' (Default) results in the maximum value being one.
%   - 'unitEnergyRC' Energy of RC spectrum is one.
%   - 'unitEnergyRRC' Energy of RRC spectrum (the square root of the
%       returned spectrum) is one.
% When computing an rc in time domain:
% f -> t
% T -> 1/T' with T' being the width
A = 1;
i = 1;
expo = 1;
while i <= length(varargin)
    switch varargin{i}
        case 'normAmplitude'
            A = 1;
            i = i + 1;
        case 'unitEnergyRC'
            A = sqrt(4*T./(4-beta));
            i = i + 1;
        case 'unitEnergyRRC'
            A = T;
            i = i + 1;
        case 'exponent'
            expo = varargin{i+1};
            i = i + 2;
    end
end
H = zeros(size(f));
H(abs(f)<=(1-beta)./(2*T)) = 1;
mask = abs(f)>(1-beta)./(2*T) & abs(f)<=(1+beta)./(2*T);
% expression from wikipedia
H(mask) = ...
    (0.5*(1+cos(pi*T./beta.*(abs(f(mask))-(1-beta)./(2*T))))).^expo;
% perform normalization
H = A*H;
end