function vid_index = mapVideoIndexToFPGATrialIndex(cue_time_video, lick_struct, time_aligned_trial)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% mapVideoIndexToFPGATrialIndex: Get mapping between video and FPGA trials
% usage:  vid_index = mapVideoIndexToFPGATrialIndex(vid_real_time, time_aligned_trial)
%
% where,
%    cue_time_video is a list of video timestamps in units of days
%    time_aligned_trials is a 1x2 array, where element 1 is the first video
%       trial number that corresponds to a FPGA trial, and element 2 is the
%       FPGA trial that corresponds to that video trial.
%    vid_index is a list of video list indices such that to find the video
%       index j corresponding to FPGA trial index k, use j = vid_index(k).
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

% Collect cue times in lick_stuct time base
cue_time_lick_struct = [lick_struct.real_time];
% Make lick-struct cue times relative to start of session
cue_time_lick_struct = cue_time_lick_struct - cue_time_lick_struct(time_aligned_trial(2));

% Make video cue times relative to start of session
cue_time_video = cue_time_video - cue_time_video(time_aligned_trial(1));

%% find corresponding spout trials
vid_index = [];
for i=1:numel(cue_time_video)       
    [min_val(i),vid_index(i)] = min(abs(cue_time_lick_struct-cue_time_video(i)));        
    if min_val(i)>2*10^(-5)
        vid_index(i) = nan;
    end
end 
