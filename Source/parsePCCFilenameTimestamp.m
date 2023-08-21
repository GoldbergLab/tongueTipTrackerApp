function timestamps = parsePCCFilenameTimestamp(paths)
% Timestamp parser for PCC (phantom camera control) style filename
% timestamps, for use with sortFilesByTimestamp function within
% tongueTipTrackerApp.
%   paths - a char array representing a path containing a PCC-formatted
%       timestamp, or a cell array of them
%   timestamps - a datetime array representing the timestamp parsed from
%       the one or more paths provided

% If only one path was passed, wrap it in a cell array for consistency
if ischar(paths)
    paths = {paths};
end

% Pattern to extract the timestamp portion of the file path
extractionPattern = '[A-Z][a-z]{2} [A-Z][a-z]{2} [0-9]{2} [0-9]{4} [0-9]{2} [0-9]{2} [0-9]{2}\.[0-9]{3}';
% PCC filename timestamp format
timestampFormat = 'eee MMM dd yyyy HH mm ss.SSS';

% Extract the timestamp portion of the path
timestampText = regexp(paths, extractionPattern, 'match');

% Only one timestamp per path, so flatten cell array
timestampText = cellfun(@(x)x{1}, timestampText, 'UniformOutput', false);

% Attempt to parse the timestamp into a datetime object
timestamps = datetime(timestampText, 'InputFormat', timestampFormat);

% Warn user if any of the paths were not parseable
if any(isnat(timestamps))
    warning('The following paths were not parseable as a timestamp:');
    badPaths = paths(isnat(timestamps));
    for k = 1:length(badPaths)
        warning('\t%s', badPaths{k});
    end
end