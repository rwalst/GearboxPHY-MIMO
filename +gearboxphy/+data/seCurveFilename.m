function [filename, isSISO] = seCurveFilename(gearName, order, antennaConfig, dataDir, antennaMode)
%SECURVEFILENAME Builds the SE_data filename for one (gear, order,
%   antennaConfig) combo - factored out of loadSECurve.m so the filename
%   can also be checked for existence (see filterAvailableAntennaConfigs.m)
%   without actually loading the file. This stays the ONE place these
%   filenames are ever built; loadSECurve.m calls this and then loads.
arguments
    gearName (1,1) string
    order (1,1) double
    antennaConfig (1,1) struct
    dataDir (1,1) string = "SE_data"
    antennaMode (1,1) string = "multiplexing"
end

% Ein blosser Name wie "SE_data_mux_fixedB" wird hier EINMAL zu einem
% absoluten Pfad unter data/ aufgeloest; absolute Pfade (Tests, temporaere
% Verzeichnisse) gehen unveraendert durch. Vorher war die Vorgabe schlicht
% "SE_data" -- relativ zum aktuellen Verzeichnis, was nur funktionierte,
% solange man im Wurzelverzeichnis stand.
dataDir = gearboxphy.paths.dataDir(dataDir);

isSISO = antennaConfig.N_t==1 && antennaConfig.N_r==1;

% In BEAMFORMING mode the array buys path-loss gain, not extra streams
% (BEAMFORMING_EXTENSION.md): every antenna config reuses the SISO curve,
% and the gain shows up in +physics/linkBudgetDb.m instead. Forcing
% isSISO here is what makes that true for every gear at once, including
% the MIMO-less ones whose asserts below would otherwise reject a
% non-SISO config outright.
if antennaMode == "beamforming"
    isSISO = true;
end

switch gearName
    case "QAM"
        if isSISO
            filename = fullfile(dataDir, sprintf('SE_%d_QAM.mat', order));
        else
            filename = fullfile(dataDir, sprintf('SE_%d_QAM_%dx%d.mat', ...
                order, antennaConfig.N_t, antennaConfig.N_r));
        end
    case "NA-QAM"
        assert(isSISO, 'gearboxphy:mimoNotSupported', ...
            'NA-QAM has no MIMO variant (MIMO_EXTENSION.md decision 2) - antennaConfig must be SISO (N_t=N_r=1).');
        filename = fullfile(dataDir, sprintf('SE_%d_QAM.mat', order));
    case "ZXM"
        % MIMO_EXTENSION.md decision 2 excluded ZXM from MIMO because only
        % Gast's AWGN SISO curves existed. QuantizedMimoMI/zxm now computes
        % ZXM over an arbitrary channel matrix (zxmMimoMiAll), so the
        % restriction is lifted for ZXM -- the other gears keep it.
        %
        % The SISO name is unchanged, so a folder holding OUR ZXM curves
        % shadows the framework original of the same name. That is why
        % exportZxmToGearboxSEData refuses to write into SE_data*,
        % SE_data_mux* or SE_data_bf*: the two models must never sit in one
        % folder, or which one a run used stops being recoverable.
        if isSISO
            filename = fullfile(dataDir, sprintf('MUI_ZXM_Mtx=%d_sigmaPN=-5.mat', order));
        else
            filename = fullfile(dataDir, sprintf('MUI_ZXM_Mtx=%d_sigmaPN=-5_%dx%d.mat', ...
                order, antennaConfig.N_t, antennaConfig.N_r));
        end
    case "Pulse-Energy"
        assert(isSISO, 'gearboxphy:mimoNotSupported', ...
            'Pulse-Energy has no MIMO variant (MIMO_EXTENSION.md decision 2) - antennaConfig must be SISO (N_t=N_r=1).');
        filename = fullfile(dataDir, 'SE_Unipolar_IR.mat');
    case "Pulse-Arbitrary"
        assert(isSISO, 'gearboxphy:mimoNotSupported', ...
            'Pulse-Arbitrary has no MIMO variant (MIMO_EXTENSION.md decision 2) - antennaConfig must be SISO (N_t=N_r=1).');
        filename = fullfile(dataDir, 'SE_Arbitrary_IR.mat');
    otherwise
        error('gearboxphy:unknownGear', 'No SE curve mapping for gear "%s"', gearName);
end
end
