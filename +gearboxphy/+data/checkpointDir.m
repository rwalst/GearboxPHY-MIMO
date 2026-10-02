function d = checkpointDir(resultsDir, key)
%CHECKPOINTDIR ONE place the checkpoint DIRECTORY path is built.
%
%   d = checkpointDir(resultsDir, key)
%
%   NO DOTS ANYWHERE IN THIS PATH, deliberately - two separate sources of
%   them used to be here and both broke checkpointing on a cluster share:
%
%   1. The folder was called ".checkpoints". A leading dot makes it a
%      hidden entry, which several network filesystems (SMB/UNC shares in
%      particular, which this project uses) treat specially or refuse to
%      create outright. It is now plain "checkpoints".
%
%   2. The key itself carries the carrier frequency in GHz, so 2.4 GHz
%      produced "qam_M16_fc2.4GHz" - a dot INSIDE A DIRECTORY NAME. A dot
%      in a FILE name is ordinary; in a directory name it is exactly what
%      trips path handling on those same shares. resultKey.m's docstring
%      claims the key is "stripped of anything but alphanumerics", but its
%      regexprep only sanitises the GEAR NAME - the formatted f_c slips
%      straight through. Rather than change resultKey (which would orphan
%      every existing results/*.mat file, whose names legitimately contain
%      that dot before the extension), the dot is replaced by "p" HERE,
%      for the directory component only: fc2.4GHz -> fc2p4GHz.
%
%   Result filenames are deliberately NOT touched by this.
safeKey = strrep(char(key), '.', 'p');
d = fullfile(resultsDir, 'checkpoints', safeKey);
end
