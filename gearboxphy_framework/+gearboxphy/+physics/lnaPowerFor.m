function P = lnaPowerFor(lna, B)
%LNAPOWERFOR Power of ONE LNA [W] under the scenario's LNA model - the
%   single dispatch point every gear calls (LNA_POWER_MODEL.md).
%
%   lna is the struct built by lnaParams(cs): fields model, f_c, N_0,
%   beta_min. B is the (signal = LNA) bandwidth [Hz]; in the Gearbox the
%   LNA is designed for exactly the bandwidth it needs.
%
%   "fom_bandwidth" - lnaPower(B, N_0), the dissertation model. Called
%                     with the unmodified B, so the default reproduces
%                     every existing result bit for bit.
%   "fom_floor"     - lnaPower(max(B, beta_min*f_c), N_0): same formula,
%                     but an LNA cannot be narrower than beta_min*f_c.
%   "envelope"      - lnaPowerEnvelope(f_c, B, beta_min): 5 % envelope
%                     of the Belostotski survey, same floor.
switch lna.model
    case "fom_bandwidth"
        P = gearboxphy.physics.lnaPower(B, lna.N_0);
    case "fom_floor"
        P = gearboxphy.physics.lnaPower(max(B, lna.beta_min * lna.f_c), lna.N_0);
    case "envelope"
        P = gearboxphy.physics.lnaPowerEnvelope(lna.f_c, B, lna.beta_min);
    otherwise
        error('gearboxphy:lnaModel', 'Unknown LNA power model "%s".', lna.model);
end
end
