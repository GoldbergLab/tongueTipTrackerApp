function t_stats = assign_actuator_commands(t_stats,l_sp_struct, vid_index)
% Modify t_stats struct so it has the vector of actuator commands
% Note that in order to have actuator commands both within and outside of
% the licks, we assign the whole trial actuator command vector to the first
% lick of the trial. All subsequent licks have "NaN" for the actuator
% command value.

for i=1:numel(t_stats)
    if isnan(vid_index(t_stats(i).trial_num))
        t_stats(i).actuator_command_x = NaN;
        t_stats(i).actuator_command_y = NaN;
    elseif ~isnan(vid_index(t_stats(i).trial_num))
        if t_stats(i).lick_index == 1
            % This is the first lick - assign the whole trial actuator command
            %   vector to this lick.
            t_stats(i).actuator_command_x = l_sp_struct(vid_index(t_stats(i).trial_num)).actuator1_ML_command;
            t_stats(i).actuator_command_y = l_sp_struct(vid_index(t_stats(i).trial_num)).actuator2_AP_command;
        else
            % This is not the first lick - just assign NaN - we can extrapolate
            %   based on the time_rel_cue field.
            t_stats(i).actuator_command_x = NaN;
            t_stats(i).actuator_command_y = NaN;
        end
    end
end