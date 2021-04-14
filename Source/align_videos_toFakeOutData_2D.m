function [vid_ind_arr] = align_videos_toFakeOutData_2D(dirlist_video,segdir,dirlist_lick_trials,time_aligned_trial)

for j = 1:numel(dirlist_video)
    dirlist = rdir(strcat(dirlist_video(j).name,'\*.avi'));
    load(strcat(dirlist_lick_trials(j).name,'\lick_struct.mat'));
    
    %Time aligned Trial
    tal = time_aligned_trial;
    
    %% Get Times of all the videos
        vid_real_time = [];
    for i=1:numel(dirlist)        
        name_cells = strsplit(dirlist(i).name,'\');
        name_cells = strsplit(name_cells{end});
        trial_time = str2num(name_cells{5})/24+str2num(name_cells{6})/(24*60)+str2num(name_cells{7})/(24*60*60);
        vid_real_time(i) = trial_time;
    end
    
    %% Align Time stamps
    spout_time = mod(lick_struct(tal(j,2)).real_time,1);
    vid_time = vid_real_time(tal(j,1));
    
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
        
    load(strcat(segdir(j).name,'\t_stats.mat'),'t_stats')
    l_sp_struct = lick_struct;    
    vid_ind_arr{j} = vid_index;
    
    %% Assign Type of Lick   
    t_stats = assign_lick_type(t_stats,l_sp_struct,vid_index);
    t_stats = assign_fakeout_type_2D(t_stats,l_sp_struct,vid_index);
    
    %% Save the Struct
    save(strcat(segdir(j).name,'\t_stats.mat'),'t_stats','l_sp_struct','vid_index');

end