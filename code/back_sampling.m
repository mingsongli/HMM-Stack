function [samples,sites] = back_sampling(fMatrix,sampleSize,data,age_stack,rhos,phi)
%% This function generates sample alignments by backward sampling.

% L = length of data in the core
% T = length of age in the stack

% Inputs:
% fMatrix: a TxTxL-forward matrix computed by the forward algorithm
% param: a structure of parameters consisting of the following:
% param.mu: a 1xT-vector of means
% param.sigma: a 1xT-vector of standard deviations
% param.shift: it is not used in this sampling
% sampleSize: number of samples we want to generate
% data: a Lx3-matrix where the first column has the depth indexes and the
% third one has the del-O18 data
% age_stack: a 1xT-vector of ages in stack
% rhos: a 3x1-cell where the first one is rho_table and the second one is
% grid.
% phi: a hyperparameter for controlling the length of unaligned regions.

% Outputs:
% samples: a 1 x sampleSize - cell consisting of samples per each entry.
% sites: a 1 x sampleSize - cell consisting of sites of samples.


%% Define variables:
T = size(fMatrix,1);
L = size(fMatrix,3);
samples_matrix = zeros(L,sampleSize);
depth = data(:,1);
rho_table = rhos{1};
grid1 = [log(0.9220),log(1.0850)];
grid2 = rhos{3};
phi = log(phi);


%% Compute distribution of the last two samples:
term = zeros(1,T*T);
for t = 1:T
    term((t-1)*T+1:t*T) = fMatrix(t,:,L) - (1-T:0)*phi;
end
term = term - max(term);
dist = cumsum(exp(term)/sum(exp(term)));


%% Sample ages for each sample:
count = 1;
while count < sampleSize
    det_seed = rand();
    index1 = (det_seed > dist);
    sum_index = sum(index1);
    samples_matrix(L,count) = rem(sum_index,T)+1;
    samples_matrix(L-1,count) = (sum_index-rem(sum_index,T))/T+1;
    rho = (samples_matrix(L,count)-samples_matrix(L-1,count))/abs(depth(L)-depth(L-1));
    if rho == 0
        rho = 0.5/abs(depth(L)-depth(L-1));
    end
    if (rho-4)*(rho-0.25) <= 0
        det = 1;
        index = L-2;
        det_seed = rand(L,1);
        while det == 1 && index > 0
            index1 = (age_stack > age_stack(samples_matrix(index+1,count))-4*abs(depth(index+1)-depth(index)) & age_stack < age_stack(samples_matrix(index+1,count))-0.25*abs(depth(index+1)-depth(index))) | (age_stack == age_stack(samples_matrix(index+1,count)));
            dummy = 1:T;
            if sum(index1) > 1
                possible_t = dummy(index1);
                term = fMatrix(possible_t,samples_matrix(index+1,count),index+1);
                if sum(isinf(term)) < length(term)
                    term = term - max(term);
                    t = 1;
                    while t < length(possible_t)
                        term(t) = exp(term(t))*rho_table(1+sum(grid1<(age_stack(samples_matrix(index+1,count))-age_stack(possible_t(t)))/abs(depth(index+1)-depth(index))),sum(grid2<rho));
                        % term(t) = exp(term(t))*rho((age_stack(samples(index+1,count))-age_stack(possible_t(t)))/(depth(index+1)-depth(index)),(age_stack(samples(index+2,count))-age_stack(samples(index+1,count)))/(depth(index+2)-depth(index+1)));
                        t = t + 1;
                    end
                    term(t) = exp(term(t))*rho_table(1+sum(grid1<0.5/abs(depth(index+1)-depth(index))),sum(grid2<rho));
                    term = cumsum(term/sum(term));
                    index2 = (det_seed(index) > term);
                    sum_index = sum(index2);
                    samples_matrix(index,count) = possible_t(sum_index+1);
                    index = index - 1;
                    rho = (age_stack(samples_matrix(index+1,count))-age_stack(samples_matrix(index,count)))/abs(depth(index+1)-depth(index));
                    if rho == 0
                        rho = 0.5/abs(depth(index+1)-depth(index));
                    end
                else
                    det = 0;
                end
            elseif sum(index1) == 1
                possible_t = dummy(index1);
                term = fMatrix(possible_t,samples_matrix(index+1,count),index+1);
                if isinf(term) == 0
                    samples_matrix(index,count) = dummy(index1);
                    index = index - 1;
                    rho = 0.5/abs(depth(index+1)-depth(index));
                else
                    det = 0;
                end
            else
                det = 0;
            end
        end
        % If a full-length sample was drawn, it is stored.
        if det == 1
            count = count + 1;
        end
    end
end

sites = cell(1,sampleSize);
for i = 1:sampleSize
    sites{i} = samples_matrix(:,i);
end

samples_matrix = age_stack(samples_matrix);

samples = cell(1,sampleSize);
for i = 1:sampleSize
    samples{i} = samples_matrix(:,i);
end

disp('Backward sampling is done.');


end