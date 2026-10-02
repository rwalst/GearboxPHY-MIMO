function fig = plotEnergyReport(resultsDir, scenario, f_c)
%PLOTENERGYREPORT The 4-subplot per-carrier figure (E_bit, bandwidth,
%   gamma, spectral efficiency vs rate) across every gear/order, ported
%   from Wrapper.m's per-f_c plotting section. Iterates gearRegistry()
%   polymorphically instead of the original's hardcoded M_QAM_list/
%   ZXM_list/Pulse_list plus repeated per-family load loops.
%
%   A combo with no result file yet (never swept) renders as a NaN row -
%   expected during an incremental sweep. Any OTHER load error (a
%   corrupted file, an unexpected format) is NOT swallowed and propagates
%   as a real error instead (code review finding #2: a bare try/catch
%   here used to mask both cases identically, reintroducing the exact
%   "silent skip" failure mode this rewrite was meant to eliminate).
gears = gearboxphy.gears.gearRegistry();
n = numel(scenario.RVec);
RVec = scenario.RVec;

legendNames = strings(0);
E_bit_all = []; B_all = []; gamma_all = [];
for gi = 1:numel(gears)
    gear = gears{gi};
    for oi = 1:numel(gear.orders)
        order = gear.orders(oi);
        key = gearboxphy.data.resultKey(gear.name, order, f_c);
        if isfile(fullfile(resultsDir, key + ".mat"))
            S = gearboxphy.data.loadAllResults(resultsDir, key);   % let real errors propagate
            E_bit_all(end+1,:) = S.E_per_bit(:).'; %#ok<AGROW>
            B_all(end+1,:) = S.Optimal_B(:).'; %#ok<AGROW>
            gamma_all(end+1,:) = S.Optimal_gamma(:).'; %#ok<AGROW>
        else
            E_bit_all(end+1,:) = NaN(1,n); %#ok<AGROW>
            B_all(end+1,:) = NaN(1,n); %#ok<AGROW>
            gamma_all(end+1,:) = NaN(1,n); %#ok<AGROW>
        end
        legendNames(end+1) = sprintf('%s (order=%g)', gear.name, order); %#ok<AGROW>
    end
end

fig = figure();

subplot(4,1,1)
loglog(RVec, gearboxphy.report.interpolateNaN(E_bit_all), 'LineWidth', 1)
legend(legendNames); grid on
xlim([min(RVec),max(RVec)]); ylim([1e-12,1e-4])
title(sprintf('E_{bit} f_c=%g GHz', f_c/1e9)); ylabel('E_{bit} [J/bit]'); xlabel('R_{eff} [bit/s]')

subplot(4,1,2)
loglog(RVec, gearboxphy.report.interpolateNaN(B_all), 'LineWidth', 1)
legend(legendNames); grid on
xlim([min(RVec),max(RVec)])
title('Bandwidth'); ylabel('B [Hz]'); xlabel('R_{eff} [bit/s]')

subplot(4,1,3)
loglog(RVec, gearboxphy.report.interpolateNaN(gamma_all), 'LineWidth', 1)
legend(legendNames); grid on
xlim([min(RVec),max(RVec)])
title('gamma'); ylabel('gamma'); xlabel('R_{eff} [bit/s]')

subplot(4,1,4)
SE_all = RVec ./ (B_all .* gamma_all);
loglog(RVec, gearboxphy.report.interpolateNaN(SE_all), 'LineWidth', 1)
legend(legendNames); grid on
xlim([min(RVec),max(RVec)])
title('Spectral Efficiency'); ylabel('S [bit/s/Hz]'); xlabel('R_{eff} [bit/s]')
end
