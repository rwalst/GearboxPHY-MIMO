function validateGear(gear)
%VALIDATEGEAR Asserts a gear struct has every required field, correctly
%   typed. This is the safety net that recovers most of what an abstract
%   classdef's load-time method check would have given (catching a gear
%   that forgot to implement something), without requiring a class
%   hierarchy - see ARCHITECTURE_PLAN.md section 4.1 for why this
%   framework uses plain functions/structs instead of classdef. Called
%   once when gearRegistry() builds its list, and again from
%   tests/+unit/GearsTest.m.
requiredFunctionFields = ["prepare","initialGuess","optimizerBounds", ...
    "makeObjective","computeBudget","antennaConfigs"];
for f = requiredFunctionFields
    assert(isfield(gear, f), 'gearboxphy:invalidGear', ...
        'Gear is missing required field "%s"', f);
    assert(isa(gear.(f), 'function_handle'), 'gearboxphy:invalidGear', ...
        'Gear field "%s" must be a function handle', f);
end
assert(isfield(gear, 'name'), 'gearboxphy:invalidGear', 'Gear is missing required field "name"');
assert(isstring(gear.name) && isscalar(gear.name), 'gearboxphy:invalidGear', ...
    'Gear "name" must be a scalar string');
assert(isfield(gear, 'orders'), 'gearboxphy:invalidGear', 'Gear is missing required field "orders"');
assert(isnumeric(gear.orders) && ~isempty(gear.orders), 'gearboxphy:invalidGear', ...
    'Gear "orders" must be a non-empty numeric array');

% isBaseline is optional (only naQamGear.m sets it) - see
% +gears/isBaselineGear.m - but if present it must be a proper flag.
if isfield(gear, 'isBaseline')
    assert(islogical(gear.isBaseline) && isscalar(gear.isBaseline), 'gearboxphy:invalidGear', ...
        'Gear "isBaseline", if present, must be a scalar logical');
end
end
