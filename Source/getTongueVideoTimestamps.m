function videoTimes = getTongueVideoTimestamps(videoRoot)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% getTongueVideoTimestamps: Get list of timestamps of tongue videos
% usage:  videoTimes = getTongueVideoTimestamps(videoRoot)
%
% where,
%    videoRoot is the path to a folder containing tongue videos
%    videoTimes is a list of timestamps of videos in the given folder, in
%       units of days.
%
% Get a list of timestamps from a folder of tongue videos in units of days
%
% See also: align_videos_toFakeOutData_2D, tongueTipTrackerApp
%
% Version: 1.0
% Author: Code abstracted from a function probably written by Teja Bollu
%   and/or Brendan Ito
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Get Times of all the videos

% Get all video timestamps as an array of datetime objects
[~, videoTimestamps] = findSessionVideos(videoRoot, 'avi', @parsePCCFilenameTimestamp);

% Find the timestamp of the first video
startTimestamp = videoTimestamps(1);

% Find the start time of the first video
startTime = timeofday(startTimestamp);

% Calculate the timestamp of the midnight before the first video
startMidnightTimestamp = startTimestamp - startTime;

% Express the video times as fractions of a day relative to the midnight
% before the first video
videoTimes = days(videoTimestamps - startMidnightTimestamp);
