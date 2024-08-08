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
extractionPattern1 = '[A-Z][a-z]{2} [A-Z][a-z]{2} [0-9]{2} [0-9]{4} [0-9]{2} [0-9]{2} [0-9]{2}\.[0-9]{3}';
% PCC filename timestamp format
timestampFormat1 = 'eee MMM dd yyyy HH mm ss.SSS';

% A second possible pattern to try (produced by PCC v3.5+ with {timeF}
% wildcard in filename string
extractionPattern2 = 'Y[0-9]{8}H[0-9]{6}\.[0-9]{9}';
timestampFormat2 = '''Y''yyyyMMdd''H''HHmmss.SSSSSSSSS';

% A third possible pattern to try (produced by PCC v3.5+ with {timeF}
% wildcard in filename string
extractionPattern3 = 'Y[0-9\ ]{8}H[0-9\ ]{6}\.[0-9]{9}';
timestampFormat3 = '''Y''yyyyMM d''H''HHmmss.SSSSSSSSS';

extractionPatterns = {extractionPattern1, extractionPattern2, extractionPattern3};
timestampFormats = {timestampFormat1, timestampFormat2, timestampFormat3};

timestamps = NaT(1, length(paths));
timestampText = cell(1, length(paths));

for formatNum = 1:length(extractionPatterns)
    extractionPattern = extractionPatterns{formatNum};
    timestampFormat = timestampFormats{formatNum};

    % Get mask for which timestamps are still un-parsed
    natMask = isnat(timestamps);

    % Extract the timestamp portion of the path for unparsed timestamps
    timestampText(natMask) = regexp(paths(natMask), extractionPattern, 'match');
    
    patternFound = cellfun(@(x)~isempty(x), timestampText);

    % Only one timestamp per path, so flatten cell array for unparsed timestamps
    timestampText(natMask & patternFound) = cellfun(@(x)x{1}, timestampText(natMask & patternFound), 'UniformOutput', false);

    % Attempt to parse the timestamp into a datetime object
    timestamps(natMask & patternFound) = datetime(timestampText(natMask & patternFound), 'InputFormat', timestampFormat);
end

% Warn user if any of the paths were not parseable
if any(isnat(timestamps))
    warning('The following paths were not parseable as a timestamp:');
    badPaths = paths(isnat(timestamps));
    for k = 1:length(badPaths)
        warning('\t%s', badPaths{k});
    end
end