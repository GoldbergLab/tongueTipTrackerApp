function [vid_ind_arr, result] = align_videos_toFakeOutData_2D(sessionVideoRoots,sessionMaskRoots,sessionFPGARoots,time_aligned_trial, spoutPositionCalibrations, motorSpeeds, params)
% result is either true if the processing completed successfully or a cell array of char arrays describing the error.
result = true;
vid_ind_arr = [];
for sessionNum = 1:numel(sessionVideoRoots)
    try
        load(fullfile(sessionFPGARoots{sessionNum},'lick_struct.mat'));
    catch e
        if ~iscell(result)
            result = {};
        end
        result = [result, ['Error: Could not find lick_struct.mat for the session', sessionMaskRoots{sessionNum}, '. Make sure to get lick segmentation and kinematics first.']];
        continue;
    end
    
    %% Get Times of all the videos
    vid_real_time = getTongueVideoTimestamps(sessionVideoRoots{sessionNum});
        
    %% Get mapping between video trials and FPGA trials
    vid_index = mapVideoIndexToFPGATrialIndex(vid_real_time, lick_struct, time_aligned_trial);

    load(strcat(sessionMaskRoots{sessionNum},'\t_stats.mat'),'t_stats')
    l_sp_struct = lick_struct;
    vid_ind_arr{sessionNum} = vid_index;
    
    %% Assign Type of Lick   
    t_stats = assign_lick_type_2D(t_stats,l_sp_struct,vid_index);
    t_stats = assign_fakeout_type_2D(t_stats,l_sp_struct,vid_index);
    t_stats = assign_CSM_SSM(t_stats);
    t_stats = lick_index_rel2contact(t_stats);
    t_stats = add_SSM_dur(t_stats);
    t_stats = assign_laser_2D(t_stats, sessionVideoRoots{sessionNum});

    %% Calculate spout position
    t_stats = assign_actuator_commands(t_stats, l_sp_struct, vid_index);
    t_stats = mapSpoutCommandToPosition(t_stats, spoutPositionCalibrations{sessionNum});
    
    %% Add spout contact voxels
    fprintf('Finding contact voxels on Session %d\n', sessionNum);
    t_stats = find_contact_voxels(t_stats, sessionMaskRoots{sessionNum}, sessionVideoRoots{sessionNum}, vid_index, params);

    %% Save the Struct
    save(strcat(sessionMaskRoots{sessionNum},'\t_stats.mat'),'t_stats','l_sp_struct','vid_index');

end