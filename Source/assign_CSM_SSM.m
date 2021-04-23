function t_stats = assign_CSM_SSM(t_stats)

for i = 1:numel(t_stats)        
    if ~isnan(t_stats(i).spout_contact)  
        sp_contact_temp = t_stats(i).spout_contact-t_stats(i).time_rel_cue;
        CSM_end = min(sp_contact_temp,t_stats(i).ret_ind);
        t_stats(i).CSM_dur = max(CSM_end-t_stats(i).prot_ind,0);        
        if t_stats(i).CSM_dur>0
            t_stats(i).CSM_start = t_stats(i).prot_ind;
            t_stats(i).CSM_end = CSM_end;
            t_stats(i).SSM_start = CSM_end;
            t_stats(i).SSM_end = t_stats(i).ret_ind;
        else
            t_stats(i).CSM_start = t_stats(i).prot_ind;
            t_stats(i).CSM_end = t_stats(i).prot_ind;
            t_stats(i).SSM_start = t_stats(i).CSM_end;
            t_stats(i).SSM_end = t_stats(i).ret_ind;
        end
    else
        t_stats(i).CSM_dur = t_stats(i).ret_ind-t_stats(i).prot_ind;
        t_stats(i).CSM_start = t_stats(i).prot_ind;
        t_stats(i).CSM_end = t_stats(i).ret_ind;
        t_stats(i).SSM_start = t_stats(i).CSM_end;
        t_stats(i).SSM_end = t_stats(i).ret_ind;
    end        
end

t_stats;