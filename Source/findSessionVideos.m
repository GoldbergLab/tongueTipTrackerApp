function [videoPaths, timestamps] = findSessionVideos(sessionVideoRoot, videoType, timestampParser)
% findSessionVideos - find the videos for a tongueTipTracker video session
%                     in timestamp-sorted order
%   sessionVideoRoot = a video directory path
%   videoType = either 'avi' or 'cine'. Default is 'avi'
%   timestampParser = an optional timestamp parser function (see
%       sortFilesByTimestamp). If omitted, defaults to the
%       parsePCCFilenameTimestamp function
%   videoPaths = a cell array of video paths found sorted by timestamp
%   timestamps = the extracted timestamps
arguments
    sessionVideoRoot {mustBeText}
    videoType {mustBeMember(videoType, {'avi', 'cine'})} = 'avi'
    timestampParser function_handle = @parsePCCFilenameTimestamp
end

% Check which video type the user wants
switch videoType
    case 'avi'
        pattern = '.*\.[aA][vV][iI]$';
    case 'cine'
        pattern = '.*\.[cC][iI][nN][eE]$';
    otherwise
        error('videoType must be either ''cine'' or ''avi''');
end

% Find videos in the given video directory
matchPath = false;
recurse = false;
videoPaths = findFilesByRegex(sessionVideoRoot, pattern, matchPath, recurse);

% Sort the videos by timestamp using the provided parser
[videoPaths, I, timestamps] = sortFilesByTimestamp(videoPaths, timestampParser);

% Sort the timestamps
timestamps = timestamps(I);