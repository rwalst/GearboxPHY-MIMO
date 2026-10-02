function lna = lnaParams(cs)
%LNAPARAMS The LNA-model fields of a carrier scenario, bundled for
%   lnaPowerFor.m. Built once per (gear, order, carrier) in each gear's
%   narrowHwParams(). A scenario without lnaPowerModel (built by hand,
%   e.g. in older tests) gets the dissertation model, so nothing changes
%   for callers that never heard of the switch.
lna.model = "fom_bandwidth";
if isfield(cs, 'lnaPowerModel'), lna.model = string(cs.lnaPowerModel); end
lna.beta_min = 0.05;
if isfield(cs, 'lnaBetaMin'), lna.beta_min = cs.lnaBetaMin; end
lna.f_c = cs.f_c;
lna.N_0 = cs.N_0;
end
