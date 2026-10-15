function args = oldModelArgs()
%OLDMODELARGS Name-value pairs that select the dissertation's component
%   models, i.e. the defaults of makeScenarioConfig until 2026-10-15
%   (hardwareModelPreset("old")).
%
%   old = gearboxphy.sweep.oldModelArgs();
%   s = gearboxphy.sweep.makeScenarioConfig(old{:}, 'distance', 50, ...);
%
%   Put them FIRST: makeScenarioConfig takes the last value of a repeated
%   name, so every switch a study sets itself (e.g. lnaPowerModel in the
%   LNA comparison) still wins. Every study whose results were computed
%   before the defaults changed builds its scenario this way, so its
%   stored results stay valid and resumable.
preset = gearboxphy.physics.hardwareModelPreset("old");
names = fieldnames(preset);
args = cell(1, 2*numel(names));
for k = 1:numel(names)
    args{2*k-1} = names{k};
    args{2*k}   = preset.(names{k});
end
end
