function [seq,pTransition] = fct_genMaxEntropicRllSeq(dCon,kCon,numSym )
% This function generates 
% * BPSK RLL sequence, 
% * DK sequence, 
% * alternating DK sequence, 
% * arbitrary positive or negative spikes
% of length 'numSymbols' and with d-constraint 'rllD' and k constraint 'rllK'.

%% special case d=0 (BPSK)
if dCon==0 && isinf(kCon)
    N = 2;
    Pdk = 0.5*ones(N);
    dataRll = (randi(2,numSym,1) - 1)*2 - 1;
    dataRll(1) = -1;
    dataDkAlt = 0.5*(dataRll - [-1; dataRll(1:end-1)]);
    dataDk = abs(dataDkAlt); 
    idx_ones = find(dataDk==1);
else
    %% Construct adjacency matrix
    if isinf(kCon)||(kCon<dCon)
        N = dCon + 1;
        [D, Pdk] = deal(zeros(N));
        D(1:end-1,2:end) = eye(dCon);
        D(end,1) = 1;
        D(end,end) = 1;
    else
        N = kCon + 1;
        [D, Pdk] = deal(zeros(N));
        D(1:end-1,2:end) = eye(kCon);
        D(dCon+1:end,1) = 1;
    end
    
    %%  Compute eigenvalues and eigenvectors of adjacency matrix
    [eigVecs, eigDiag] = eig(D);
    [lambda, idx] = max(diag(eigDiag));
    b = eigVecs(:,idx);
    
    %% Compute rate (entropy) of rll constraint
    %rllR = log2(lambda);
    
    %% Construct max entropy transition probabilities
    for i = 1:N
        for j = 1:N
            Pdk(i,j) = b(j)./b(i) .* D(i,j)./lambda;
        end
    end
    
    %% Simulate walk on markov chain to generate (d,k)-sequence
    dataDk = zeros(numSym,1);
    dataHmm = hmmgenerate(numSym, Pdk, eye(length(Pdk)));
    dataDk(dataHmm == 1) = 1;
    
    %% generate alternating (d,k)-sequence
    % first peak is always positive
    dataDkAlt = dataDk;
    idx_ones = find(dataDk==1);
    dataDkAlt(idx_ones(2:2:end)) = -1;
    
    %% Convert to RLL
    % Always starts in state '-1'
    dataRll = -1*ones(size(dataDk)); 
    % add last entry to idx_ones if number of entries is odd
    if mod(length(idx_ones),2)==1
        idx_ones = [idx_ones;length(idx_ones)+1];
        appendedIndex = true;
    else
        appendedIndex = false;
    end
    % set all values to '1' between every second pair of ones in the dk seq
    for i = 1:2:length(idx_ones)
        dataRll(idx_ones(i):(idx_ones(i+1)-1)) = 1;
    end

    if appendedIndex
        idx_ones = idx_ones(1:end-1);
    end
    
    % requires too much memory
    %intMtx = tril(ones(numSymbols));
    %dataRllOld = 2* intMtx * dataDkAlt -1;

end

%% generate (d,k)-sequence with arbitrary sign
dataArSign = zeros(size(dataDk));
dataArSign(idx_ones) = (randi(2,size(idx_ones)) - 1)*2 - 1;

%% Construct transition probabilities for alternating (dk) sequence
% not required for sequence generation but for calculation of MI
PdkAlt = [Pdk, zeros(N);...
    zeros(N),Pdk];
PdkAlt(1:N,N+1) = Pdk(:,1);
PdkAlt(N+1:end,1) = Pdk(:,1);
PdkAlt(1:N,1) = 0;
PdkAlt(N+1:end,N+1) = 0;

%% Construct transition probabilities for (dk) sequence with arbitrary sign
% not required for sequence generation but for calculation of MI
PArSign = [Pdk, zeros(N);...
    zeros(N),Pdk];
PArSign(:,1) = 0.5*[Pdk(:,1); Pdk(:,1)];
PArSign(:,N+1) = PArSign(:,1);

%% transpose transition probability metrices 
% current state: column, new state: row
Pdk = Pdk';
PdkAlt = PdkAlt';
PArSign = PArSign';

%% organize output as structs
seq.dk = dataDk;
seq.rll = dataRll;
seq.altDK = dataDkAlt;
seq.arbSig = dataArSign;

pTransition.dk = Pdk;
pTransition.altDK = PdkAlt;
pTransition.arbSig = PArSign;

end

