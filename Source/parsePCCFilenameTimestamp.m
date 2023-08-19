function timestamp = parsePCCFilenameTimestamp(path)
% Timestamp parser for PCC (phantom camera control) style filename
% timestamps, for use with sortFilesByTimestamp function within
% tongueTipTrackerApp.
%   path - a char array representing a path containing a PCC-formatted
%       timestamp
%   timestamp - a datetime object representing the timestamp parsed from
%       the path

% Pattern to extract the timestamp portion of the file path
extractionPattern = '[A-Z][a-z]{2} [A-Z][a-z]{2} [0-9]{2} [0-9]{4} [0-9]{2} [0-9]{2} [0-9]{2}\.[0-9]{3}';
% PCC filename timestamp format
timestampFormat = 'eee MMM dd yyyy HH mm ss.SSS';

% Extract the timestamp portion of the path
timestampText = regexp(path, extractionPattern, 'match');

if isempty(timestampText)
    % Could not find a timestamp in the path
    timestamp = NaT();
    warning('No timestamp found within %s', path);
    return;
end

% Should be exactly one timestamp, so get it
timestampText = timestampText{1};

try
    % Attempt to parse the timestamp into a datetime object
    timestamp = datetime(timestampText, 'InputFormat', timestampFormat);
catch
    % Timestamp was not parseable for some reason
    timestamp = NaT;
    warning('Failed to parse timestamp for %s', path);
    return;
end
