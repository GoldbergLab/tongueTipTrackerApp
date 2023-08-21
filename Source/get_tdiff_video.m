function [tdiff_fpga, tdiff_vid, result] = get_tdiff_video(sessionVideoRoots, sessionFPGARoots, timestampParser)
% Get intertrial intervals for each session based on both video and fpga
% data streams
%
%   timestampParser = an optional timestamp parser function (see
%       sortFilesByTimestamp). If omitted, defaults to the
%       parsePCCFilenameTimestamp function

% Check if we need default timestamp parser
if ~exist('timestampParser', 'var') || isempty(timestampParser)
    timestampParser = @parsePCCFilenameTimestamp;
end

% Loop over video session directories
result = true;

% Initialize tdiff arrays
tdiff_vid = cell(size(sessionVideoRoots));
tdiff_fpga = cell(size(sessionFPGARoots));

% Get video trial time differences
for sessionNum = 1:numel(sessionVideoRoots)
    % Parse video filename timestamps
    [~, videoTimestamps] = findSessionVideos(sessionVideoRoots{sessionNum}, 'avi', timestampParser);
    tdiff_vid{sessionNum} = days(diff(videoTimestamps));
end

% Get fpga trial time differences
for sessionNum=1:numel(sessionFPGARoots)
    % Load lick_struct
    try
        load(fullfile(sessionFPGARoots{sessionNum},'lick_struct.mat'), 'lick_struct');
    catch e
        result = ['Failed to load lick_struct.mat at ', fullfile(sessionFPGARoots{sessionNum},'lick_struct.mat')];
    end
        
    tdiff_fpga{sessionNum} = diff([lick_struct.real_time]);
end