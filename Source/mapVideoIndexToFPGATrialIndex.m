function vid_index = mapVideoIndexToFPGATrialIndex(vid_real_time, lick_struct, time_aligned_trial)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% mapVideoIndexToFPGATrialIndex: Get mapping between video and FPGA trials
% usage:  vid_index = mapVideoIndexToFPGATrialIndex(vid_real_time, time_aligned_trial)
%
% where,
%    vid_real_time is a list of video timestamps in units of days
%    time_aligned_trials is a 1x2 array, where element 1 is the first video
%       trial number that corresponds to a FPGA trial, and element 2 is the
%       FPGA trial that corresponds to that video trial.
%    vid_index is a list of video list indices such that to find the video
%       index j corresponding to FPGA trial index k, use k = vid_index(j).
%
% Create a list that maps video trial index to FPGA trial index. This can
%   be used, for example, to find the lick_struct index that corresponds to
%   a particular video. If no FPGA trial is found that matches a particular
%   video index, the element at that video index will be set to NaN.
%
% See also: align_videos_toFakeOutData_2D, tongueTipTrackerApp
%
% Version: <version>
% Author:  Brian Kardon
% Email:   bmk27=cornell*org, brian*kardon=google*com
% Real_email = regexprep(Email,{'=','*'},{'@','.'})
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Align Time stamps
spout_time = mod(lick_struct(time_aligned_trial(2)).real_time,1);
vid_time = vid_real_time(time_aligned_trial(1));

tdiff = (spout_time - vid_time);

vid_real_time = vid_real_time + tdiff;

spout_time_vect = [lick_struct.real_time];
spout_time_vect = mod(spout_time_vect,1);

%% find corresponding spout trials
vid_index = [];
for i=1:numel(vid_real_time)       
    [min_val(i),vid_index(i)] = min(abs(spout_time_vect-vid_real_time(i)));        
    if min_val(i)>2*10^(-5)
        vid_index(i) = nan;
    end
end 
