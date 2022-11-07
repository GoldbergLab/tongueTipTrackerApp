function t_stats = assign_laser_post_cue(t_stats, lick_struct, video_to_fpga_mapping)
% video_to_fpga_mapping = a vector where the nth value represents 
%   the fpga trial index that corresponds to the nth video 
%   trial index. Thus, if vid_index(n) == m, then the nth video trial 
%   corresponds to the mth fpga trial

for lick_num = 1:length(t_stats)
    video_trial_num = t_stats(lick_num).trial_num;
    if video_trial_num > length(video_to_fpga_mapping)
        break;
    end
    fpga_trial_num = video_to_fpga_mapping(video_trial_num);
    if isnan(fpga_trial_num)
        continue;
    end
    laser_post_cue = lick_struct(fpga_trial_num).laser_post_cue;
    if ~isempty(laser_post_cue)
        % There was a laser during this trial - let's see if it was during
        % this lick

        % Laser on time relative to cue
        laser_on = laser_post_cue(1);
        % Laser off time relative to cue
        laser_off = laser_post_cue(2);
        cue_time = t_stats(lick_num).pairs(1) - t_stats(lick_num).time_rel_cue;
        lick_time = t_stats(lick_num).pairs - cue_time; 
        [~, ~, overlaps] = getSegmentOverlap(lick_time(1), lick_time(2), laser_on, laser_off);
        t_stats(lick_num).laser_post_cue = overlaps;
    end
end
