function [vid_ind_arr, result] = align_videos_toFakeOutData_2D(sessionVideoRoots,sessionMaskRoots,sessionFPGARoots,time_aligned_trial)
% result is either true if the processing completed successfully or a cell array of char arrays describing the error.
result = true;
vid_ind_arr = [];

for sessionNum = 1:numel(sessionVideoRoots)
    videoList = rdir(fullfile(sessionVideoRoots{sessionNum},'*.avi'));
    try
        load(fullfile(sessionFPGARoots{sessionNum},'lick_struct.mat'));
    catch e
        if ~iscell(result)
            result = {};
        end
        result = [result, ['Error: Could not find lick_struct.mat for the session', sessionMaskRoots{sessionNum}, '. Make sure to get lick segmentation and kinematics first.']];
        continue;
    end
    
    %Time aligned Trial
    tal = time_aligned_trial;
    
    %% Get Times of all the videos
        vid_real_time = [];
    for i=1:numel(videoList)        
        name_cells = strsplit(videoList(i).name,'\');
        name_cells = strsplit(name_cells{end});
        trial_time = str2num(name_cells{5})/24+str2num(name_cells{6})/(24*60)+str2num(name_cells{7})/(24*60*60);
        vid_real_time(i) = trial_time;
    end
    
    %% Align Time stamps
    spout_time = mod(lick_struct(tal(sessionNum,2)).real_time,1);
    vid_time = vid_real_time(tal(sessionNum,1));
    
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
        
    load(strcat(sessionMaskRoots{sessionNum},'\t_stats.mat'),'t_stats')
    l_sp_struct = lick_struct;    
    vid_ind_arr{sessionNum} = vid_index;
    
    %% Assign Type of Lick   
    t_stats = assign_lick_type_2D(t_stats,l_sp_struct,vid_index);
    t_stats = assign_fakeout_type_2D(t_stats,l_sp_struct,vid_index);
    t_stats = assign_CSM_SSM(t_stats);
    t_stats = lick_index_rel2contact(t_stats);
    t_stats = add_SSM_dur(t_stats);
    
    %% Save the Struct
    save(strcat(sessionMaskRoots{sessionNum},'\t_stats.mat'),'t_stats','l_sp_struct','vid_index');

end