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
videoList = rdir(fullfile(videoRoot,'*.avi'));
videoTimes = [];
for i=1:numel(videoList)        
    name_cells = strsplit(videoList(i).name,'\');
    name_cells = strsplit(name_cells{end});
    trial_time = str2num(name_cells{5})/24+str2num(name_cells{6})/(24*60)+str2num(name_cells{7})/(24*60*60);
    videoTimes(i) = trial_time;
end
