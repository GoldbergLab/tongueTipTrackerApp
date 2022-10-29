function t_stats = assign_lick_type_2D(t_stats,l_sp_struct,vid_index)
for i=1:numel(t_stats)
    t_stats(i).lick_type = 0;
    t_stats(i).spout_contact = nan;
    t_stats(i).spout_contact2 = nan;
    t_stats(i).spout_contact_offset = nan;
    t_stats(i).spout_contact_offset2 = nan;
    t_stats(i).prev_spcontact = nan;
    t_stats(i).analog_lick = nan;
end

% trial_num_temp = unique([t_stats.trial_num]);
% for i=1:numel(trial_num_temp)
%     ind = find([t_stats.trial_num] == trial_num_temp(i));
%     t_stats(ind(1)).analog_lick = l_sp_struct(trial_num_temp(i)).analog_lick;
% end

for i=1:numel(vid_index)
    if ~isnan(vid_index(i)) && sum([t_stats.trial_num] == i) > 0
        ind = find([t_stats.trial_num] == i);
        t_stats(ind(1)).analog_lick = l_sp_struct(vid_index(i)).analog_lick;
    end
end

% Old way from BSI - changed by BSI to new verison above
% for i=1:numel(t_stats)
%     if t_stats(i).lick_index == 1
%         t_stats(i).analog_lick = l_sp_struct(t_stats(i).trial_num).analog_lick;
%     end
% end

for i=1:numel(l_sp_struct)
    vid_trial = find(vid_index==i);
    rw_licks = l_sp_struct(i).rw_licks;
    rw_licks_offset = l_sp_struct(i).rw_licks_offset;
    prev_spcontact = l_sp_struct(i).prev_licks;
    
    if numel(vid_trial) && numel(rw_licks)
        vid_licks_ind = find([t_stats.trial_num] == vid_trial);
        %t_stats(vid_licks_ind).lick_type = zeros(1,numel(vid_licks_ind));
        
        t_stats_temp = t_stats(vid_licks_ind);
        
        loc = [];
        loc2 = [];
        %             for jj = 1:numel(rw_licks)
        %                 tdiff = rw_licks(jj)-[ts_temp.time_rel_cue];
        %                 tdiff(tdiff<0) = 1000;
        %                 [~,loc_temp] = min(tdiff);
        %                 if numel(loc_temp)>0
        %                     loc(jj) = loc_temp(1);
        %                 end
        %             end
        
        for lickNum = 1:numel(t_stats_temp)
            % this is a weird way to get an index...but ok, Teja.
            tdiff = rw_licks - t_stats_temp(lickNum).time_rel_cue;
            tdiff(tdiff<0) = 1000;
            tdiff(tdiff>t_stats_temp(lickNum).dur) = 1000;
            [~,loc_temp] = min(tdiff);
            
            % added by BSI to take care of 'double-tap' in 2D
            loc_temp2 = find(tdiff<t_stats_temp(lickNum).dur);
            
            if numel(loc_temp)>0 && tdiff(loc_temp) ~= 1000
                loc(lickNum) = loc_temp(1);
            else
                loc(lickNum) = nan;
            end
            
            % added by BSI to take care of 'double-tap'
            if sum(tdiff<t_stats_temp(lickNum).dur) > 1
                loc2(lickNum) = loc_temp2(2);
            else
                loc2(lickNum) = nan;
            end
        end
        
        flag = 1;
        lick_count = 1;
        for lickNum = 1:numel(t_stats_temp)
            if (flag == 1) && (~isnan(loc(lickNum)))
                t_stats(vid_licks_ind(lickNum)).lick_type = 1;
                lick_count = lick_count + 1;
                flag = 2;
            elseif flag == 2
                t_stats(vid_licks_ind(lickNum)).lick_type = lick_count;
                lick_count = lick_count + 1;
            end
        end
        
        for lickNum = 1:numel(t_stats_temp)
          if ~isnan(loc(lickNum))
            t_stats(vid_licks_ind(lickNum)).spout_contact = rw_licks(loc(lickNum));
            t_stats(vid_licks_ind(lickNum)).prev_spcontact = prev_spcontact(loc(lickNum));
            if loc(lickNum) <= numel(rw_licks_offset)        
                % rarely the lick sensor may detect the offset as somehow
                % being after the onset...NaN both onset/offset if so, but
                % note that this will mess up prev_spcontact.  BSI was not
                % using prev_spcontact at the time of writing this, and did
                % not have time to come up with a workaround - but if I NaN
                % the onset, prev_spcontact has to be from lick n - 1
                if rw_licks(loc(lickNum)) < rw_licks_offset(loc(lickNum))
                    t_stats(vid_licks_ind(lickNum)).spout_contact_offset = rw_licks_offset(loc(lickNum));
                elseif rw_licks(loc(lickNum)) >= rw_licks_offset(loc(lickNum))
                    t_stats(vid_licks_ind(lickNum)).spout_contact = NaN;
                    t_stats(vid_licks_ind(lickNum)).spout_contact_offset = NaN;
                end
            elseif loc(lickNum) > numel(rw_licks_offset)
                t_stats(vid_licks_ind(lickNum)).spout_contact_offset = nan;
            end       
                
            % added by BSI to take care of 'double-tap'
            if ~isnan(loc2(lickNum))
                t_stats(vid_licks_ind(lickNum)).spout_contact2 = rw_licks(loc2(lickNum));
                % recently edited by BSI (221011)
                if lickNum <= numel(rw_licks_offset) && loc2(lickNum) <= numel(rw_licks_offset)
                    t_stats(vid_licks_ind(lickNum)).spout_contact_offset2 = rw_licks_offset(loc2(lickNum));
                elseif lickNum > numel(rw_licks_offset) || loc2(lickNum) > numel(rw_licks_offset)
                    t_stats(vid_licks_ind(lickNum)).spout_contact_offset2 = nan;
                end
            end
          end            
        end                                                                
        
        spcontact_vect = find(~isnan([t_stats(vid_licks_ind).prev_spcontact]));
        for kk = 1:numel(t_stats_temp)
            if isnan(t_stats(vid_licks_ind(kk)).prev_spcontact)
                [~,I] = min(abs(spcontact_vect-kk));
                if numel(I)
                    temp_spcontact = t_stats(vid_licks_ind(spcontact_vect(I))).prev_spcontact - ((t_stats(vid_licks_ind(spcontact_vect(I))).time_rel_cue)-(t_stats(vid_licks_ind(kk)).time_rel_cue));
                    
                    if temp_spcontact>0
                        t_stats(vid_licks_ind(kk)).prev_spcontact = temp_spcontact;
                    else
                        t_stats(vid_licks_ind(kk)).prev_spcontact =  nan;
                    end
                else
                    t_stats(vid_licks_ind(kk)).prev_spcontact =  nan;
                end
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