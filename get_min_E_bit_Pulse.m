function [OptimalParameters,PowerBudget] = get_min_E_bit_Pulse(R, modulation, params)
%GET_MIN_E_BIT Summary of this function goes here
%   Detailed explanation goes here

f_c=params.f_c;


num_bands=length(f_c);

Optimal_B=NaN;
Optimal_gamma=NaN;

B_0=0.99*params.eta*f_c;
gamma_0=1;
numtries=params.numtriesPerOpt;


vals=NaN(numtries,1);
for i=1:numtries
    x_0=[log10(B_0),gamma_0];
    if i>1
        x_0=x_0./(1+rand(1,2).*0.1);
    end

    fun = @(x)e_bit_fct_Pulse(x,params,modulation,R,"minimization");
    options=optimset('TolX',params.tolerance,'TolFun',params.tolerance,'MaxIter',params.maxiters, ...
        'MaxFunEvals',params.maxiters, 'Display', 'off');
    [optimal_parameters,value,exitflag,output] = fminsearch(fun,x_0,options);

    optimal_parameters_vec(i,:)=optimal_parameters;
    vals(i)=value;

end
%find best
index=find(vals==min(vals),1);
optimal_parameters=optimal_parameters_vec(index,:);



%save Parameters
%E_per_bit=value;
if(~isinf(value))
    index=find(vals==min(vals),1,'first');
    optimal_parameters=optimal_parameters_vec(index,:);

    PowerBudget=e_bit_fct_Pulse(optimal_parameters,params,modulation,R,"budget");

    E_per_bit=vals(index);
    Optimal_B=10^optimal_parameters(1);
    Optimal_gamma=optimal_parameters(2);
   
else
    PowerBudget=NaN;
     E_per_bit=NaN;
end

OptimalParameters.E_per_bit=E_per_bit;
OptimalParameters.Optimal_B=Optimal_B;
OptimalParameters.Optimal_gamma=Optimal_gamma;

end

