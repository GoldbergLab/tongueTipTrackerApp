function t_stats = assign_lick_type(t_stats, l_sp_struct, vid_index)
for lick_idx=1:numel(t_stats)
    t_stats(lick_idx).lick_type = 0;
    t_stats(lick_idx).spout_contact = nan;
end

for trial_num=1:numel(l_sp_struct)
    vid_trial = find(vid_index==trial_num);
    rw_licks = l_sp_struct(trial_num).rw_licks;
    
    if numel(vid_trial) && numel(rw_licks)
        vid_licks_ind = find([t_stats.trial_num] == vid_trial);
        %t_stats(vid_licks_ind).lick_type = zeros(1,numel(vid_licks_ind));
        
        t_stats_temp = t_stats(vid_licks_ind);
        
        loc = [];
        %             for jj = 1:numel(rw_licks)
        %                 tdiff = rw_licks(jj)-[ts_temp.time_rel_cue];
        %                 tdiff(tdiff<0) = 1000;
        %                 [~,loc_temp] = min(tdiff);
        %                 if numel(loc_temp)>0
        %                     loc(jj) = loc_temp(1);
        %                 end
        %             end
        
        for lick_idx = 1:numel(t_stats_temp)
            tdiff = rw_licks - t_stats_temp(lick_idx).time_rel_cue;
            tdiff(tdiff<0) = 1000;
            tdiff(tdiff>t_stats_temp(lick_idx).dur) = 1000;
            [~,loc_temp] = min(tdiff);
            if numel(loc_temp)>0 && tdiff(loc_temp) ~= 1000
                loc(lick_idx) = loc_temp(1);
            else
                loc(lick_idx) = nan;
            end
        end
        
        flag = 1;
        lick_count = 1;
        for lick_idx = 1:numel(t_stats_temp)
            if (flag == 1) && (~isnan(loc(lick_idx)))
                t_stats(vid_licks_ind(lick_idx)).lick_type = 1;
                lick_count = lick_count + 1;
                flag = 2;
            elseif flag == 2
                t_stats(vid_licks_ind(lick_idx)).lick_type = lick_count;
                lick_count = lick_count + 1;
            end
        end
        
        for lick_idx = 1:numel(t_stats_temp)
          if ~isnan(loc(lick_idx))
            t_stats(vid_licks_ind(lick_idx)).spout_contact = rw_licks(loc(lick_idx));
          end
        end
        
                        
                        

        
%         if numel(loc)
%             temp_dur = t_stats(vid_licks_ind(loc(1))).dur;
%             time_rel_cue = t_stats(vid_licks_ind(loc(1))).time_rel_cue;
%             if (rw_licks(1)-time_rel_cue)<temp_dur
%                 t_stats(vid_licks_ind(loc(1))).spout_contact = rw_licks(1);
%                 lick_ind = loc(1);
%                 t_stats(vid_licks_ind(loc(1))).lick_type = 1;
%                 
%                 while (lick_ind<numel(vid_licks_ind))
%                     lick_ind = lick_ind+1;
%                     if (t_stats(vid_licks_ind(lick_ind)).pairs(1)-t_stats(vid_licks_ind(lick_ind-1)).pairs(1))<300
%                         t_stats(vid_licks_ind(lick_ind)).lick_type = t_stats(vid_licks_ind(lick_ind-1)).lick_type + 1;
%                     else
%                         break
%                     end
%                 end
%                 
%             else
%                 flag = 1;
%             end
%         end
%         
%         if numel(loc)>1
%             for jj=2:numel(loc)
%                 if ~isnan(loc(jj))
%                     temp_dur = t_stats(vid_licks_ind(loc(jj))).dur;
%                     time_rel_cue = t_stats(vid_licks_ind(loc(jj))).time_rel_cue;
%                     if (rw_licks(jj)-time_rel_cue)<temp_dur
%                         t_stats(vid_licks_ind(loc(jj))).spout_contact = rw_licks(jj);
%                     end
%                 end
%             end
%         end
    end
    
end
end
% for i = 1:numel(t_stats)
%     trial_num = t_stats(i).trial_num;
%     t_stats(i).trial_type = 0;
%
%     if ~isnan(vid_index(trial_num))
%         lick_trial = l_sp_struct(vid_index(trial_num));
%
%     end
% end