function [rw_trial_struct] = make_rw_struct(nl_struct)
rw_struct_number = 1;
trial_num = 1;
rw_trial_struct = struct;
first_time = 1;

for chunk_num = 1:numel(nl_struct)
    if (isempty(nl_struct(chunk_num).rw_cue)==0)
        
        rw_cue = nl_struct(chunk_num).rw_cue;
        laser_cue = nl_struct(chunk_num).laser_cue;
        laser_post_cue = nl_struct(chunk_num).laser_post_cue;
        dispense = nl_struct(chunk_num).dispense;
        licks = nl_struct(chunk_num).lick_pairs;
        
        if first_time == 1
            ref_time = nl_struct(chunk_num).real_time;
            ref_frame_num = nl_struct(chunk_num).start_frame;
            first_time = 0;
        end
        
        for cue_num = 1:length(rw_cue(:,1))
            rw_trial_struct(trial_num).frame_num = nl_struct(chunk_num).start_frame;
            rw_trial_struct(trial_num).rw_cue = [rw_cue(cue_num,1), rw_cue(cue_num,2)];
            rw_trial_struct(trial_num).laser = laser_cue(cue_num);
            if ~any(isnan(laser_post_cue(cue_num, :)))
                rw_trial_struct(trial_num).laser_post_cue = laser_post_cue(cue_num, :);
            else
                rw_trial_struct(trial_num).laser_post_cue = [];
            end

            if(isempty(dispense)==0)                
                dispense = dispense(:,1);
                dispense_in_cue = dispense(dispense>rw_cue(cue_num,1)&dispense<=rw_cue(cue_num,2)+10);
                rw_trial_struct(trial_num).dispense =  dispense_in_cue-rw_cue(cue_num,1);
                
                licks_in_cue_orig = licks(:,1);
                licks_in_cue_orig = licks_in_cue_orig(licks_in_cue_orig>rw_cue(cue_num,1));
                licks_in_cue = licks_in_cue_orig - rw_cue(cue_num,1);
                lick_ili = diff(licks_in_cue);
                
                try
                    retrieval_licks = [licks_in_cue(1)];
                    k=1;
                    retrieval_ilis=[];
                    while lick_ili(k)<300
                        retrieval_licks = [retrieval_licks licks_in_cue(k+1)];
                        retrieval_ilis = [retrieval_ilis lick_ili(k)];
                        k=k+1;
                        if k ==length(lick_ili)
                            break
                        end
                    end
                    rw_trial_struct(trial_num).rw_licks = retrieval_licks;
                    rw_trial_struct(trial_num).rw_ili = retrieval_ilis;
                catch
                    rw_trial_struct(trial_num).rw_licks = []; %doesnt record if only one lick(dispense)
                    rw_trial_struct(trial_num).rw_ili = [];
                end
            else
                rw_trial_struct(trial_num).dispense = [];
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

