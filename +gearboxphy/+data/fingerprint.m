function h = fingerprint(varargin)
%FINGERPRINT  Canonical 64-bit hash of plain data - the key the result store uses.
%
%   h = gearboxphy.data.fingerprint(a, b, c, ...)   -> "a1b2c3d4e5f60718"
%
%   WHAT IT IS FOR: two runs compute the same thing exactly when the inputs
%   to the optimisation are the same. This turns those inputs into one
%   string, so "same thing" becomes a file lookup instead of a judgement
%   call. See +data/comboFingerprint.m for what gets fed in.
%
%   WHY NOT HASH THE FILE: measured on this repo's own data, the SISO curve
%   SE_4_QAM.mat has a DIFFERENT byte content in all 36 SE_data* folders,
%   while SNR_vec, SE_vec, sourceB, snrShiftDb, snrReference and sourceMode
%   are bit-identical - only generatedOn (a timestamp), source (a path) and
%   srcSnrStep differ. A file hash would therefore miss every real duplicate
%   and find none. The hash has to run over the PAYLOAD that the computation
%   actually reads, which is what the callers pass here.
%
%   CANONICAL means the same data always gives the same string: struct
%   fields are sorted by name, the class and size of every array go into the
%   stream (so 1 and true and "1" cannot collide), and nothing depends on
%   field order, on the MATLAB session or on the platform.
%
%   FUNCTION HANDLES AND OBJECTS ARE AN ERROR, deliberately. They cannot be
%   hashed meaningfully, and silently skipping them would produce a key that
%   claims two different computations are the same - the one failure mode
%   that would corrupt results instead of just wasting time.
%
%   See also comboFingerprint, publishToStore, fetchFromStore.
parts = cell(1, numel(varargin));
for k = 1:numel(varargin)
    parts{k} = localBytes(varargin{k});
end
bytes = [parts{:}];

if ~usejava('jvm')
    error('gearboxphy:data:fingerprintNoJvm', ...
        ['fingerprint needs the JVM for SHA-256 (matlab -batch has it, ' ...
         'matlab -nojvm does not). Without it the result store cannot be ' ...
         'keyed, so the run would silently recompute everything.']);
end
md = java.security.MessageDigest.getInstance('SHA-256');
md.update(bytes);
digest = typecast(md.digest(), 'uint8');

hex = lower(reshape(dec2hex(digest, 2)', 1, []));
h = string(hex(1:16));   % 64 bit: plenty for a few thousand result files
end

% ---------------------------------------------------------------------
function b = localBytes(v)
%LOCALBYTES  One value -> bytes, class and shape included.
if isa(v, 'function_handle') || (~isnumeric(v) && ~islogical(v) && ...
        ~ischar(v) && ~isstring(v) && ~isstruct(v) && ~iscell(v))
    error('gearboxphy:data:fingerprintUnhashable', ...
        ['Cannot fingerprint a value of class "%s". Only numeric, logical, ' ...
         'char, string, struct and cell are allowed - see fingerprint.m.'], class(v));
end

tag = localTag(sprintf('%s|%s|', class(v), mat2str(size(v))));

if isstruct(v)
    acc = {tag};
    for e = 1:numel(v)                      % struct ARRAY: element by element
        f = sort(fieldnames(v(e)));         % field ORDER must not matter
        for i = 1:numel(f)
            acc{end+1} = localTag([f{i} '=']);     %#ok<AGROW>
            acc{end+1} = localBytes(v(e).(f{i}));  %#ok<AGROW>
        end
    end
    b = [acc{:}];
elseif iscell(v)
    acc = {tag};
    for e = 1:numel(v)
        acc{end+1} = localBytes(v{e});      %#ok<AGROW>
    end
    b = [acc{:}];
elseif isstring(v)
    acc = {tag};
    for e = 1:numel(v)
        if ismissing(v(e))
            acc{end+1} = localTag('<missing>');  %#ok<AGROW>
        else
            acc{end+1} = localTag(char(v(e)));   %#ok<AGROW>
        end
        acc{end+1} = uint8(0);              %#ok<AGROW>  Trenner
    end
    b = [acc{:}];
elseif ischar(v)
    b = [tag, localTag(v)];
else
    % Numeric and logical through a FIXED representation: logical -> uint8,
    % everything else -> double. Without the cast, int32(1) and 1 would hash
    % differently although they drive the same computation; with it, the
    % class tag above still keeps them apart where that matters.
    if islogical(v)
        raw = uint8(v(:));
    else
        raw = typecast(double(v(:)), 'uint8');
    end
    b = [tag, raw(:)'];
end
end

function b = localTag(s)
%LOCALTAG  Text -> bytes, UTF-8, so a non-ASCII field name cannot change
%   the key depending on the platform's default encoding.
if isempty(s)
    b = uint8([]);  return
end
b = uint8(unicode2native(char(s), 'UTF-8'));
end
