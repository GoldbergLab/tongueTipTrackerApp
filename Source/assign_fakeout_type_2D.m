function t_stats = assign_fakeout_type_2D_local(t_stats,l_sp_struct,vid_index)
for i=1:numel(t_stats)
    t_stats(i).fakeout_trial = nan;
    t_stats(i).recenter_trial = nan;
    t_stats(i).spout_pos_seq=[];
end

% fakeout_act1_ML_opts = sort(unique([l_sp_struct.actuator1_ML]),'descend');
% fakeout_act2_AP_opts = sort(unique([l_sp_struct.actuator2_AP]),'descend');
% diff_fakeout_act1_ML_dist = diff(fakeout_act1_ML_opts);
% diff_fakeout_act2_AP_dist = diff(fakeout_act2_AP_opts);
% 
% %remove short duplicate distances
% close_index_ML = find(abs(diff_fakeout_act1_ML_dist)<0.2);
% close_index_ML = reshape(close_index_ML,1,numel(close_index_ML));
% close_index_ML(2,:) = close_index_ML(1,:) + 1;
% 
% %remove short duplicate distances
% close_index_AP = find(abs(diff_fakeout_act2_AP_dist)<0.2);
% close_index_AP = reshape(close_index_AP,1,numel(close_index_AP));
% close_index_AP(2,:) = close_index_AP(1,:) + 1;
% 
% k = 0;
% for i = 1:numel(fakeout_act1_ML_opts)
%     isduplicate = find(close_index_ML(2,:) == i);
%     if isduplicate
%         fakeout_dist_act1_ML{k} = [fakeout_dist_act1_ML{k} fakeout_act1_ML_opts(i)];
%     else
%         k=k+1;
%         fakeout_dist_act1_ML{k} = [fakeout_act1_ML_opts(i)];
%     end   
% end
% 
% m = 0;
% for j = 1:numel(fakeout_act2_AP_opts)
%     isduplicate = find(close_index_AP(2,:) == j);
%     if isduplicate
%         fakeout_dist_act2_AP{m} = [fakeout_dist_act2_AP{m} fakeout_act2_AP_opts(j)];
%     else
%         m=m+1;
%         fakeout_dist_act2_AP{m} = [fakeout_act2_AP_opts(j)];
%     end   
% end

% this code now assumes no duplicates are present, can take care of this
% posthoc
dist_table = table([l_sp_struct.actuator1_ML]', [l_sp_struct.actuator2_AP]');
unique_dist = table2array(unique(dist_table, 'rows'));
[~, ind] = sort(unique_dist(:, 1));
unique_dist = unique_dist(ind, :);

% check if recentering happens, assuming the left/right ML commands are
% never duplicated and numbers of spout locations left/right are always
% matched
% if length(unique_dist(:,1)) ~= length(unique(unique_dist(:,1)))
    %center_ind = find(unique_dist(:,1)==median(unique_dist(:,1)));
    %recenter_ind = center_ind(find(unique_dist([center_ind],2)==min(unique_dist([center_ind],2))));
    %recenter_dist=unique_dist(recenter_ind,:);
    %unique_dist(recenter_ind,:)=[];
%end

for i=1:numel(l_sp_struct)
    vid_trial = find(vid_index==i);
    
    if numel(vid_trial)
        vid_licks_ind = find([t_stats.trial_num] == vid_trial);
        
        for kk = 1:numel(vid_licks_ind)
            for ll = 1:size(unique_dist, 1)
                if numel(l_sp_struct(i).rw_licks_offset)>=2 ...
                        & unique_dist(ll, 1) == l_sp_struct(i).actuator1_ML_command(l_sp_struct(i).rw_licks_offset(2)) ...
                        & unique_dist(ll, 2) == l_sp_struct(i).actuator2_AP_command(l_sp_struct(i).rw_licks_offset(2))
                    t_stats(vid_licks_ind(kk)).fakeout_trial = ll;
                end
                if numel(l_sp_struct(i).rw_licks_offset)>=3 ...
                        & unique_dist(ll, 1) == l_sp_struct(i).actuator1_ML_command(end) ...
                        & unique_dist(ll, 2) == l_sp_struct(i).actuator2_AP_command(end)
                    t_stats(vid_licks_ind(kk)).recenter_trial = ll;
                end
            end

            % Use this code to get a field with a sequence of spout
            % positions for each trial
%             dist_table_trial = table([l_sp_struct(i).actuator1_ML_command]', [l_sp_struct(i).actuator2_AP_command]');
%             dist_table_trial = table2array(unique(dist_table_trial, 'rows','stable'));
%             temp=[];
%             for mm = 1:size(dist_table_trial, 1)
%                 for nn = 1:size(unique_dist, 1)
%                     if dist_table_trial(mm,1)==unique_dist(nn,1) & dist_table_trial(mm,2)==unique_dist(nn,2)
%                         %t_stats(vid_licks_ind(kk)).spout_pos_seq=[t_stats(vid_licks_ind(kk)).spout_pos_seq,nn];
%                         temp=[temp,nn];
%                     end
%                 end
%             end
%             t_stats(vid_licks_ind(kk)).spout_pos_seq=temp;
        end
    end
    
end

end