function t_stats = assign_laser_post_cue(t_stats, lick_struct, video_to_fpga_mapping)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% assign_laser_post_cue: assign a laser_post_cue value for each lick
% usage:  t_stats = assign_laser_post_cue(t_stats, lick_struct, video_to_fpga_mapping)
%
% where,
%    t_stats is a t_stats struct array, where each struct represents data
%       about one lick. This struct array is modified, then returned.
%    lick_struct is a lick_struct struct array, where each struct
%       represents data about one trial
%    video_to_fpga_mapping = a vector where the nth value represents 
%       the fpga trial index that corresponds to the nth video 
%       trial index. Thus, if vid_index(n) == m, then the nth video trial 
%       corresponds to the mth fpga trial
%
% In the "classic" tongue tracking analysis pipeline, whether or not the
%   laser was on was determined from the video filenames, which were
%   modified based on the tags in the XML associated with the video, which
%   were created by the camera when it received a digital high on its GPIO
%   port. However, for the 1D doublestep experiments, that GPIO port was
%   repurposed to record whether or not a doublestep took place (I think?),
%   so it no longer was for laser. Instead, this script replaces that
%   method of determining if the laser was on or off, with a method based
%   on the FPGA data itself, where the laser on/off times are also
%   recorded.
%
% See also: align_videos_tolickdata, make_rw_struct, nplick_struct
%
% Version: 1.0
% Author:  Brian Kardon
% Email:   bmk27=cornell*org, brian*kardon=google*com
% Real_email = regexprep(Email,{'=','*'},{'@','.'})
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Loop over t_stats rows (each one of which is a lick)
for lick_num = 1:length(t_stats)
    video_trial_num = t_stats(lick_num).trial_num;
    if video_trial_num > length(video_to_fpga_mapping)
        break;
    end
    % Map the video trial number to an fpga trial number
    fpga_trial_num = video_to_fpga_mapping(video_trial_num);
    if isnan(fpga_trial_num)
        continue;
    end
    % Get the laser on/off times, if they exist
    laser_post_cue = lick_struct(fpga_trial_num).laser_post_cue;
    if ~isempty(laser_post_cue)
        % There was a laser during this trial - let's see if it was during
        % this lick

        % Laser on time relative to cue
        laser_on = laser_post_cue(1);
        % Laser off time relative to cue
        laser_off = laser_post_cue(2);
        % Infer the cue time for this lick's trial
        cue_time = t_stats(lick_num).pairs(1) - t_stats(lick_num).time_rel_cue;
        % Convert lick start/end times to times relative to the cue
        lick_time = t_stats(lick_num).pairs - cue_time; 
        % Determine if the laser was on during this lick
        [~, ~, overlaps] = getSegmentOverlap(lick_time(1), lick_time(2), laser_on, laser_off);
        t_stats(lick_num).laser_post_cue = overlaps;
    end
end
