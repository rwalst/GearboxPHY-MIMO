function op = operatingPointFrom(core)
%OPERATINGPOINTFROM Operating point of one optimized point, from a gear's
%   core struct. ONE place, shared by all four gears.
%
%   op = operatingPointFrom(core)
%
%   Fields, all scalars: SE (bit/s/Hz, = R/(gamma*B) at the optimum),
%   SNR_rx_dB (what the SE curve demands at that SE), SNR_tx_dB (the same
%   plus the link budget, = SNR_rx_dB + ctx.L_dB), P_t_W (transmit power),
%   B_Hz and gamma (the optimizer's own two variables, echoed here so one
%   struct describes the point completely).
%
%   WHY NOT IN THE POWER BUDGET: the budget struct carries an unwritten
%   invariant - the sum of ALL its fields is E_bit. validate_analog_bf,
%   analyze_mimo_comparison, analyze_lna_comparison and two unit tests
%   rely on it via sum(struct2array(pb)) or fieldnames(pb). An SNR in
%   there would be silently added to an energy. Hence a separate struct
%   and a separate output.
%
%   An INFEASIBLE core gives all-NaN rather than an error: the caller gets
%   a struct of the same shape at every point, so a result array never has
%   to special-case which points converged.
op = struct('SE', NaN, 'SNR_rx_dB', NaN, 'SNR_tx_dB', NaN, ...
            'P_t_W', NaN, 'B_Hz', NaN, 'gamma', NaN);
if ~isstruct(core) || ~isfield(core, 'feasible') || ~core.feasible
    return
end
op.SE        = core.SE;
op.SNR_rx_dB = core.SNR_rx_dB;
op.SNR_tx_dB = core.SNR_tx_dB;
op.P_t_W     = core.P_t_W;
op.B_Hz      = core.B;
op.gamma     = core.gamma;
end
