function seData = loadSECurve(gearName, order, antennaConfig, dataDir, antennaMode)
%LOADSECURVE ONE place that knows the on-disk SE_data FIELDS per gear
%   (filenames themselves are built by seCurveFilename.m, so there's
%   still exactly one place a filename is ever constructed - this
%   function just adds the "which .mat fields map to SNR_vec/SE_vec"
%   knowledge on top).
%
%   antennaConfig is a struct('N_t',N_t,'N_r',N_r). The SISO case
%   (N_t=N_r=1) resolves to today's existing filenames with zero
%   migration needed. A non-SISO antennaConfig is only supported for
%   "QAM" (MIMO_EXTENSION.md decision 2); seCurveFilename.m errors
%   clearly for any other gear rather than silently ignoring antenna
%   count.
%
%   Returns a struct with raw (NOT bandwidth-normalized) fields
%   SNR_vec, SE_vec. Bandwidth normalization stays gear-specific business
%   logic in +gears/*.m, not here.
%
%   Zusaetzlich (nur QAM/NA-QAM, sonst Defaults):
%     sourceB       ADC-Aufloesung in Bit je reeller Dimension, mit der die
%                   Kurve GERECHNET wurde (NaN = unbekannt, z.B. Gasts
%                   SISO-Kurven). qamGear/naQamGear bezahlen genau diese
%                   Aufloesung, damit SE und ADC-Leistung zusammenpassen.
%     snrReference  "total" = SNR bezogen auf die GESAMT-Sendeleistung.
%
%   SCHUTZ gegen unnormierte MIMO-Kurven: QuantizedMimoMI rechnet mit
%   Es = 1 JE STROM, die Gesamtsendeleistung ist also N_t. Das Gearbox
%   rechnet P_T aus der SNR als GESAMTleistung. Ohne Umrechnung bekaeme
%   Multiplexing 10*log10(N_t) dB geschenkt (3/6/9/12 dB bei 2x2..16x16).
%   exportToGearboxSEData schreibt deshalb die umgerechnete Achse und das
%   Feld snrReference="total"; jede Mehrstrom-Kurve OHNE dieses Feld wird
%   hier abgewiesen, statt still falsch gerechnet zu werden.
arguments
    gearName (1,1) string
    order (1,1) double
    antennaConfig (1,1) struct
    dataDir (1,1) string = "SE_data"
    antennaMode (1,1) string = "multiplexing"
end

[filename, isSISO] = gearboxphy.data.seCurveFilename(gearName, order, antennaConfig, dataDir, antennaMode);

seData.sourceB = NaN;
seData.snrReference = "";

switch gearName
    case {"QAM", "NA-QAM"}
        raw = gearboxphy.data.loadMatCached(filename);
        seData.SNR_vec = raw.SNR_vec;
        seData.SE_vec  = raw.SE_vec;
        if isfield(raw, 'sourceB'),      seData.sourceB = double(raw.sourceB); end
        if isfield(raw, 'snrReference'), seData.snrReference = string(raw.snrReference); end
    case "ZXM"
        raw = gearboxphy.data.loadMatCached(filename);
        seData.SNR_vec = raw.SNR_dB_vec;
        seData.SE_vec  = raw.I_vec;
        % Ohne das Feld scheitert JEDE Mehrstrom-ZXM-Kurve unten am
        % snrReference-Assert -- die Framework-Originale sind SISO und
        % tragen es nicht, unsere MIMO-Kurven schreiben es.
        if isfield(raw, 'snrReference'), seData.snrReference = string(raw.snrReference); end
    case {"Pulse-Energy", "Pulse-Arbitrary"}
        raw = gearboxphy.data.loadMatCached(filename);
        seData.SNR_vec = raw.SNR;
        seData.SE_vec  = raw.SE;
end

% Einstrom-Kurven (isSISO, auch jede Kurve im Beamforming-Modus) sind von
% der Normierungsfrage nicht betroffen: ein Strom, Es = Gesamtleistung.
if ~isSISO
    assert(seData.snrReference == "total", 'gearboxphy:snrReference', ...
        ['%s hat kein Feld snrReference="total". MIMO-Kurven aus ' ...
         'QuantizedMimoMI sind je STROM normiert (Es=1 pro Strom), das ' ...
         'Gearbox rechnet aber mit der GESAMT-Sendeleistung - ohne ' ...
         'Umrechnung bekaeme Multiplexing 10*log10(N_t) dB geschenkt. ' ...
         'Kurve mit exportToGearboxSEData.m neu exportieren.'], filename);
end
end
