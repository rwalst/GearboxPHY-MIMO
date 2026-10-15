function fp = comboFingerprint(gearName, order, f_c, RVec, optParams, x0, bounds, ctxList)
%COMBOFINGERPRINT  The key of ONE runSweep unit: gear x order x carrier.
%
%   fp = gearboxphy.data.comboFingerprint(gear.name, order, f_c, ...
%            scenario.RVec, optParams, x0, bounds, ctxList)
%
%   WHY ctx IS THE RIGHT INPUT, and this is the whole idea: the gears are
%   built so that computeCore(x, ctx, R) and computeBudget(ctx, x, R) see
%   NOTHING but ctx and R. Everything that can move a number - the trimmed
%   SE curve, M, N_t, N_r, the ADC and DAC resolutions, the link budget
%   (which carries the distance), the carrier, the analog-BF parameters, the
%   LO powers, B_max and the whole hardware struct - is already inside ctx by
%   construction. Hashing ctx therefore cannot miss a dependency, whereas a
%   hand-written list of "the things that matter" would go stale the first
%   time a gear gains a field.
%
%   This is what makes the duplicates measurable in this repo collapse:
%
%   * The SISO gears (ZXM, Pulse, NA-QAM, QAM M=1024) read the 24 curves
%     that are byte-identical in all 36 SE_data* folders, so their ctx does
%     not depend on which BF/MUX variant is being swept. Measured: E_bit
%     agrees to 2e-9 across all six variants - they are one computation that
%     3a currently runs 6 x 3 = 18 times instead of 3.
%   * The analog variants of the DAC study use the Gearbox defaults
%     adcPowerModel="envelope" and dacPowerModel="analytic", so
%     abfdac_distance_<v>_analytic has the same ctx as
%     abf_distance_<v>_envelope. Measured: identical up to the optimiser's
%     own spread (<= 5e-3, the golden master shows 4.2e-3).
%
%   x0 AND bounds ARE IN THE KEY although they only steer the optimiser's
%   start: multistartOptimize is not seeded, so two runs with the same ctx
%   and different starting points are the same computation only up to that
%   spread. Keeping them in the key means a reused file is one that would
%   have been started the same way.
%
%   THE VERSION TAG IS LOAD-BEARING. Change WHAT goes into this key and the
%   tag must change too, otherwise an old stored file is served for a key
%   that now means something else. A new tag simply orphans the old store
%   entries, which costs compute - never correctness.
%
%   See also fingerprint, fetchFromStore, publishToStore, runSweep.
fp = gearboxphy.data.fingerprint( ...
    "gearboxphy/combo/v1", ...
    string(gearName), order, f_c, RVec, optParams, x0, bounds, ctxList);
end
