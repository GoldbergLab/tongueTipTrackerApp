function t_stats = assign_fakeout_type_2D(t_stats,l_sp_struct,vid_index)
for i=1:numel(t_stats)
    t_stats(i).fakeout_trial = nan;
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
unique_spout_positions = table2array(unique(dist_table, 'rows'));
[~, ind] = sort(unique_spout_positions(:, 1));
unique_spout_positions = unique_spout_positions(ind, :);

for trial_num = 1:numel(l_sp_struct)
    vid_trial = find(vid_index==i);
    
    if numel(vid_trial)
        lick_indices = find([t_stats.trial_num] == vid_trial);
        
        for k = 1:numel(lick_indices)
            lick_index = lick_indices(k);
            
            for spout_position_index = 1:size(unique_spout_positions, 1)
                if ~isempty(find( ...
                        unique_spout_positions(spout_position_index, 1) == l_sp_struct(i).actuator1_ML && ...
                        unique_spout_positions(spout_position_index, 2) == l_sp_struct(i).actuator2_AP, 1))
                    t_stats(lick_index).fakeout_trial = spout_position_index;
                end
            end
        end
    end
    
end

end