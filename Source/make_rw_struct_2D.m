function [rw_trial_struct] = make_rw_struct_2D(nl_struct)
rw_struct_number = 1;
trial_num = 1;
rw_trial_struct = struct;
first_time = 1;

for i = 1:numel(nl_struct)
    if (isempty(nl_struct(i).rw_cue)==0)
        
        rw_cue = nl_struct(i).rw_cue;
        laser_cue = nl_struct(i).laser_cue;
        laser_onset = nl_struct(i).laser_onset;
        dispense = nl_struct(i).dispense;
        licks = nl_struct(i).lick_pairs;
        prev_licks = nl_struct(i).prev_lick;
        actuator1_ML = nl_struct(i).actuator1_ML;
        actuator2_AP = nl_struct(i).actuator2_AP;
        analog_lick = nl_struct(i).analog_lick;
        actuator1_ML_command = nl_struct(i).actuator1_ML_command;
        actuator2_AP_command = nl_struct(i).actuator2_AP_command;

        if first_time == 1
            ref_time = nl_struct(i).real_time;
            ref_frame_num = nl_struct(i).start_frame;
            first_time = 0;
        end
        
        for j =1:length(rw_cue(:,1))
            rw_trial_struct(trial_num).frame_num = nl_struct(i).start_frame;
            rw_trial_struct(trial_num).rw_cue = [rw_cue(j,1),rw_cue(j,2)];
            rw_trial_struct(trial_num).laser = laser_cue(j);
            rw_trial_struct(trial_num).actuator1_ML = actuator1_ML(j);
            rw_trial_struct(trial_num).actuator2_AP = actuator2_AP(j);
            rw_trial_struct(trial_num).analog_lick = analog_lick(rw_cue(j,1):rw_cue(j,2));
            rw_trial_struct(trial_num).actuator1_ML_command = actuator1_ML_command(rw_cue(j,1):rw_cue(j,2));
            rw_trial_struct(trial_num).actuator2_AP_command = actuator2_AP_command(rw_cue(j,1):rw_cue(j,2));
            
            if(isempty(dispense)==0)
                
                dispense = dispense(:,1);
                dispense_in_cue = dispense(dispense>rw_cue(j,1)&dispense<=rw_cue(j,2)+10);
                rw_trial_struct(trial_num).dispense =  dispense_in_cue-rw_cue(j,1);
                
                rw_trial_struct(trial_num).laser_onset_rel_disp = laser_onset(j)-dispense_in_cue;
                
                if numel(licks)
                    licks_in_cue_orig = licks(:,1);
                    prev_lick_orig = prev_licks;
                else
                    licks_in_cue_orig = [];
                    prev_lick_orig = [];
                end
                
                licks_in_cue = licks_in_cue_orig((licks_in_cue_orig>rw_cue(j,1))&(licks_in_cue_orig<(rw_cue(j,1)+1300)));
                licks_in_cue = licks_in_cue - rw_cue(j,1);
                lick_ili = diff(licks_in_cue);
                
                prev_lick_orig  = prev_lick_orig((licks_in_cue_orig>rw_cue(j,1))&(licks_in_cue_orig<(rw_cue(j,1)+1300)));
                
                try
                    retrival_licks = [licks_in_cue(1)];
                    prev_licks_vect = [prev_lick_orig(1)];
                    k=1;
                    retrival_ilis=[];
                   
                    while 1
                        retrival_licks = [retrival_licks licks_in_cue(k+1)];                        
                        retrival_ilis = [retrival_ilis lick_ili(k)];
                        prev_licks_vect = [prev_licks_vect prev_lick_orig(k+1)];
                        k=k+1;
                        if k == length(lick_ili)
                            break
                        end
                    end
                    
                    rw_trial_struct(trial_num).rw_licks = retrival_licks;
                    rw_trial_struct(trial_num).rw_ili = retrival_ilis;
                    rw_trial_struct(trial_num).prev_licks = prev_licks_vect;
                catch
                   if numel(licks_in_cue)
                    rw_trial_struct(trial_num).rw_licks = retrival_licks;
                    rw_trial_struct(trial_num).prev_licks = prev_licks_vect;%doesnt record if only one lick(dispense)
                   else
                    rw_trial_struct(trial_num).rw_licks = [];
                    rw_trial_struct(trial_num).prev_licks = [];
                   end    
                    rw_trial_struct(trial_num).rw_ili = [];
                end
            else
                rw_trial_struct(trial_num).dispense = [];
                rw_trial_struct(trial_num).laser_onset_rel_disp =[];
            end
            
            rw_trial_struct(trial_num).real_time = datenum(ref_time) + (rw_trial_struct(trial_num).frame_num-ref_frame_num)/(24*60*60) + (rw_trial_struct(trial_num).rw_cue(1))/(24*3600*1000);
            trial_num = trial_num+1;
            
        end
    end
end
end

% rw = 0;
% for i = 1:numel(nl_struct)
%     rw = rw+length(nl_struct(i).rw_cue);
% end


