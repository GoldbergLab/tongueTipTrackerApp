function t_stats = assign_fakeout_type_2D(t_stats,l_sp_struct,vid_index)

% Note that, for some sessions, the recentering position can be the center
% position itself.  For others, it can be closer in AP, but the same in ML.
%  In other sessions, it can be different in ML (by mistake on the user),
%  and/or maybe even different in AP (by mistake of the user).  

for i=1:numel(t_stats)
    t_stats(i).fakeout_trial = nan;
    t_stats(i).recenter_trial = nan;
end

% get the number of unique spout positions
dist_table = table([l_sp_struct.actuator1_ML]', [l_sp_struct.actuator2_AP]');
unique_dist = table2array(unique(dist_table, 'rows'));
[~, ind] = sort(unique_dist(:, 1));
unique_dist = unique_dist(ind, :);

% loop through each trial in lick_struct/l_sp_struct
for i=1:numel(l_sp_struct)
    
    % find the corresponding video relative to lick_struct trial number
    vid_trial = find(vid_index==i);
    
    % if there is a video...
    if numel(vid_trial)
        
        % find and extract the corresponding trial in t_stats file
        vid_licks_ind = find([t_stats.trial_num] == vid_trial);
      
        % if there are more than 2 lick offsets
        if numel(l_sp_struct(i).rw_licks_offset)>=2

            % calculate the number of times the spout moved on a trial
            ml_spout_pos = l_sp_struct(i).actuator1_ML_command;
            ml_spout_pos_change = diff(l_sp_struct(i).actuator1_ML_command);
            ml_num_spout_pos_change = sum((abs(ml_spout_pos_change)) > 0);
            ap_spout_pos_change = diff(l_sp_struct(i).actuator2_AP_command);
            ap_num_spout_pos_change = sum((abs(ap_spout_pos_change)) > 0);

            % if the number of times the ML or AP spout position has
            % changed is 0, this is a center trial without recentering.  
            if ml_num_spout_pos_change == 0 && ap_num_spout_pos_change == 0
                for kk = 1:numel(vid_licks_ind)
                    t_stats(vid_licks_ind(kk)).fakeout_trial = 2;
                    t_stats(vid_licks_ind(kk)).recenter_trial = 0;
                end
                
            % if the number of times the ML spout position changed is 0,
            % but the number of times for the AP spout position is 1, then
            % this is a center trial with recentering.
            elseif ml_num_spout_pos_change == 0 && ap_num_spout_pos_change == 1
                for kk = 1:numel(vid_licks_ind)
                    t_stats(vid_licks_ind(kk)).fakeout_trial = 2;
                    t_stats(vid_licks_ind(kk)).recenter_trial = 1;
                end          
                
            % if the number of times the ML spout position changed is 1,
            % then this could be either a 'pure fakeout' trial or fakeout
            % with recentering. 
            elseif ml_num_spout_pos_change == 1
                % since this can be either a 'center recenter' trial, or a
                % fakeout left/right trial, we need to check the values and
                % compare them to the min/max of position values...note
                % that this assumes the 'center recenter' position is
                % either the same as the center position, or slightly
                % less/more than the left/right - but not greater than or
                % equal to the left/right
                
                % get the min/max position values in ML
                min_ML_pos = min(unique_dist(:, 1));
                max_ML_pos = max(unique_dist(:, 1));
                
                % get the time of the first spout change
                time_spout_pos_change = find(ml_spout_pos_change, 1);
                
                % if the derivative is positive, and the ML spout position
                % is the maximum of all spout positions, then this is a
                % right trial
                if ml_spout_pos_change(time_spout_pos_change) > 0 && (ml_spout_pos(time_spout_pos_change + 1) == max_ML_pos)
                    for kk = 1:numel(vid_licks_ind)
                        t_stats(vid_licks_ind(kk)).fakeout_trial = 3;
                        t_stats(vid_licks_ind(kk)).recenter_trial = 0;
                    end
                % if the derivative is positive, and the ML spout position
                % is the maximum of all spout positions, then this is a
                % right trial
                elseif ml_spout_pos_change(find(ml_spout_pos_change, 1)) < 0 && (ml_spout_pos(time_spout_pos_change + 1) == min_ML_pos)
                    for kk = 1:numel(vid_licks_ind)
                        t_stats(vid_licks_ind(kk)).fakeout_trial = 1;
                        t_stats(vid_licks_ind(kk)).recenter_trial = 0;
                    end
                % otherwise, you are a 'center recenter' trial where the
                % user made an accident with the spout position for ML
                else
                    for kk = 1:numel(vid_licks_ind)
                        t_stats(vid_licks_ind(kk)).fakeout_trial = 2;
                        t_stats(vid_licks_ind(kk)).recenter_trial = 1;
                    end
                end       
                
            % if this value is two, then this is both a fakeout and
            % recentering trial
            elseif ml_num_spout_pos_change == 2
                % check the derivative value to see if it's a left or
                % right recenter trial - ***MIGHT WANT TO ADD A 'FLIP'
                % BUTTON HERE.  SOME SESSIONS, THIS MIGHT BE DIFFERENT
                % DEPENDING ON THE MOTOR.
                
                % get the time of the first spout change
                time_spout_pos_change = find(ml_spout_pos_change, 1);

                % if the derivative is positive, this is a right trial
                if ml_spout_pos_change(time_spout_pos_change) > 0
                    for kk = 1:numel(vid_licks_ind)
                        t_stats(vid_licks_ind(kk)).fakeout_trial = 3;
                        t_stats(vid_licks_ind(kk)).recenter_trial = 1;
                    end
                % if the derivative is negative, this is a left trial
                elseif ml_spout_pos_change(time_spout_pos_change) < 0
                    for kk = 1:numel(vid_licks_ind)
                        t_stats(vid_licks_ind(kk)).fakeout_trial = 1;
                        t_stats(vid_licks_ind(kk)).recenter_trial = 1;
                    end
                end                                       
            end
        end
    end
    
end

end