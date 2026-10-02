function [lambda,runlength_avg] = maxEntropicDkProperties(d, k)
%MAXENTROPICDKPROPERTIES Ported verbatim from fct_maxEntropic_dk_properties.m.
%   Returns the maximum eigenvalue of the RLL adjacency matrix and the
%   resulting average runlength. d/k can be vectors; d indexes the 1st
%   output dimension, k the 2nd. Called by containmentBandwidthZXM.
d = reshape(d, length(d), 1);
k = reshape(k, 1, length(k));
assert(all(all(k>=d)),'Error: every d must be smaller or equal to k')

lambda = zeros(length(d), length(k));
runlength_avg = zeros(length(d), length(k));
for n=1:length(k)
    for i=1:length(d)
        if ~isinf(k(n))
            D = zeros(k(n)+1);
            D(1:end-1,2:end) = eye(k(n));
            D(d(i)+1:end,1) = 1;
        elseif d(i) == 0
            D = ones(2);
        else
            D = zeros(d(i)+1);
            D(1:end-1,2:end) = eye(d(i));
            D(end,1) = 1;
            D(end,end) = 1;
        end
        [~, eigDiag] = eig(D);
        lambda(i,n) = max(diag(eigDiag));
    end
    if k(n) == Inf
        runlength_avg(:,n) = ...
            lambda(:,n).^(-d-1).*((d+1).*lambda(:,n).^2-d.*lambda(:,n))./((lambda(:,n)-1).^2);
    else
        runlength_avg(:,n) = ...
            lambda(:,n).^(-d-k(n)-1).*(-(k(n)+2)*lambda(:,n).^(d+1)+(d+1).*lambda(:,n).^(k(n)+2)...
            -d.*lambda(:,n).^(k(n)+1)+(k(n)+1)*lambda(:,n).^d)./(lambda(:,n)-1).^2;
    end
end
end
