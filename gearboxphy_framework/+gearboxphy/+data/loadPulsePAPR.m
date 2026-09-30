function paprDb = loadPulsePAPR(pulseType, M_tx, pulseFilter, dataDir)
%LOADPULSEPAPR Looks up the dk-encoded PAPR [dB] table for pulse schemes
%   (ported from the inline groupVal/struct2table filtering logic that
%   used to live in Wrapper.m). Filename case matches the actual file
%   exactly (dkEnergyRX_ArbSign_SE99.mat, capital RX) - this exact
%   mismatch was a real bug fixed in Wrapper.m earlier in this project's
%   history, so it stays correct here as the one place this filename is
%   ever built.
arguments
    pulseType (1,1) string {mustBeMember(pulseType,["Energy","Arbitrary"])}
    M_tx (1,1) double = 1
    pulseFilter (1,1) string = "rc"
    dataDir (1,1) string = "SE_data"
end
filename = fullfile(dataDir, 'dkEnergyRX_ArbSign_SE99.mat');
raw = gearboxphy.data.loadMatCached(filename);
T_PAPR = struct2table(raw.groupVal);

if pulseType == "Energy"
    logicmap = (T_PAPR.hTxName==pulseFilter) & (T_PAPR.modultn=="dkEnergyRX") & (T_PAPR.Mtx==M_tx);
else % "Arbitrary"
    logicmap = (T_PAPR.hTxName==pulseFilter) & (T_PAPR.modultn=="maxArbSign") & (T_PAPR.Mtx==M_tx);
end
paprDb = T_PAPR.PAPR_dB(logicmap);
end
