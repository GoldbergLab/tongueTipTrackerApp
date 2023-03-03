function [video_to_fpga_mapping_arr, result] = align_videos_tolickdata(sessionVideoRoots, sessionDataRoots, sessionFPGARoots, time_aligned_trial)
% result is either true if the processing completed successfully or a cell array of char arrays describing the error.
result = true;
video_to_fpga_mapping_arr = [];

for sessionNum = 1:numel(sessionVideoRoots)
    videoList = rdir(fullfile(sessionVideoRoots{sessionNum},'*.avi'));
    try
        s = load(fullfile(sessionFPGARoots{sessionNum}, 'lick_struct.mat'), 'lick_struct');
        lick_struct = s.lick_struct;
    catch e
        if ~iscell(result)
            result = {};
        end
        result = [result, ['Error: Could not find lick_struct.mat for the session', sessionDataRoots{sessionNum}, '. Make sure to get lick segmentation and kinematics first.']];
        continue;
    end
    
    %Time aligned Trial
    tal = time_aligned_trial;
    
    %% Get Times of all the videos
        video_timestamps = [];
    for videoNum=1:numel(videoList)        
        name_cells = strsplit(videoList(videoNum).name,'\');
        name_cells = strsplit(name_cells{end});
        trial_time = str2double(name_cells{5})/24+str2double(name_cells{6})/(24*60)+str2double(name_cells{7})/(24*60*60);
        video_timestamps(videoNum) = trial_time;
    end
    
    %% Align Time stamps
    spout_time = mod(lick_struct(tal(sessionNum,2)).real_time,1);
    vid_time = video_timestamps(tal(sessionNum,1));
    
    tdiff = (spout_time - vid_time);
    
    video_timestamps = video_timestamps + tdiff;
    
    fpga_timestamps = [lick_struct.real_time];
    fpga_timestamps = mod(fpga_timestamps,1);
    
    % Create a vector where the nth value represents corresponding the 
    %   fpga trial index that corresponds to the nth video trial index.
    %   Thus, if video_to_fpga_mapping(n) == m, then the nth video trial 
    %   corresponds to the mth fpga trial
    video_to_fpga_mapping = nan(1, numel(video_timestamps));
    for videoNum = 1:numel(video_timestamps)
        [timestamp_discrepancy, video_to_fpga_mapping(videoNum)] = min(abs(fpga_timestamps - video_timestamps(videoNum)));        
        if timestamp_discrepancy > 2*10^(-5)
            % The best aligned video and fpga trials were not aligned well
            % enough - probably not an actual match. Mark this as no match
            % (nan)
            video_to_fpga_mapping(videoNum) = nan;
        end
    end 
        
    try
        load(fullfile(sessionDataRoots{sessionNum},'t_stats.mat'),'t_stats')
    catch e
        if ~iscell(result)
            result = {};
        end
        result = [result, ['Error: Could not find t_stats.mat for the session', sessionDataRoots{sessionNum}, '. Make sure to process FPGA data first.']];
        continue
    end

    l_sp_struct = lick_struct;    
    video_to_fpga_mapping_arr{sessionNum} = video_to_fpga_mapping;

    %% Assign Type of Lick   
    t_stats = assign_lick_type(t_stats,l_sp_struct,video_to_fpga_mapping);
    t_stats = assign_CSM_SSM(t_stats);
    t_stats = lick_index_rel2contact(t_stats);
    t_stats = add_SSM_dur(t_stats);
    t_stats = assign_laser_post_cue(t_stats,l_sp_struct,video_to_fpga_mapping);
    
    %% Save the Struct
    save(fullfile(sessionDataRoots{sessionNum},'t_stats.mat'),'t_stats','l_sp_struct','video_to_fpga_mapping');

end