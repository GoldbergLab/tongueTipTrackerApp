function t_stats = find_contact_voxels(t_stats, sessionMaskRoot, sessionVideoRoot, params)

% spout width in mm - for thin spout in BOTTOM VIEW
spout_width_mm = 1.27;

% mm/pix conversion factor from PCC
mm_pix_conv = 0.06;

% calculate spout width in pixels
spout_width_pix = spout_width_mm/mm_pix_conv;

% get width of spout in bottom view in mask coords
spout_x = {t_stats.spout_position_x};
spout_x_mid = cellfun(@(x) round(x-(spout_width_pix/2)), spout_x, 'UniformOutput', false);

% get length of spout
spout_y = cellfun(@(x) round(x), {t_stats.spout_position_y}, 'UniformOutput', false);

% get width of spout in top view in mask coords
spout_z = {t_stats.spout_position_z};
spout_z_mid = cellfun(@(x) round(144-x-(spout_width_pix/2)), spout_z, 'UniformOutput', false);

% get trial numbers - remember, trial numbers are from videos, not FPGA.
trial_num_all = unique([t_stats.trial_num]);

% get video list
vid_list = dir(fullfile(sessionVideoRoot, '*.avi'));

% loop through each trial
for trial_num = trial_num_all
    
    % get cue times from video name
    trial_vid_temp = vid_list(trial_num);
    trial_vid_name = trial_vid_temp.name;
    trial_vid_cue_time = str2num(trial_vid_name(regexp(trial_vid_name, '(?<=_C)\d', 'start'):regexp(trial_vid_name, '(?<=_C)\d*', 'end')));
    
    % extract data per trial
    t_stats_temp = t_stats([t_stats.trial_num] == trial_num);
    
    if ~isempty(t_stats_temp) && sum([t_stats_temp.lick_index] > 0)

        spout_x_mid_temp = spout_x_mid([t_stats.trial_num] == trial_num);
        spout_x_mid_temp = spout_x_mid_temp{[t_stats_temp.lick_index] == 1};

        spout_z_mid_temp = spout_z_mid([t_stats.trial_num] == trial_num);
        spout_z_mid_temp = spout_z_mid_temp{[t_stats_temp.lick_index] == 1};

        spout_y_temp = spout_y([t_stats.trial_num] == trial_num);
        spout_y_temp = spout_y_temp{[t_stats_temp.lick_index] == 1};

        tongue_bot_mask = load(append(sessionMaskRoot, '\', sprintf('Bot_%03d', trial_num-1), '.mat'));
        tongue_bot_mask = tongue_bot_mask.mask_pred;

        tongue_top_mask = load(append(sessionMaskRoot, '\', sprintf('Top_%03d', trial_num-1), '.mat'));
        tongue_top_mask = tongue_top_mask.mask_pred;
        
        % loop through each lick per trial and filter times when contact occured
        contact_centroid = cell(size(t_stats_temp));
        contact_area = cell(size(t_stats_temp));
        contact_centroid2 = cell(size(t_stats_temp));
        contact_area2 = cell(size(t_stats_temp));
        parfor lick_idx = 1:numel(t_stats_temp)  

            fprintf('Finding contact voxels on Trial %d, Lick %d\n', trial_num, lick_idx);

            if ~isnan(t_stats_temp(lick_idx).spout_contact) && ~isnan(t_stats_temp(lick_idx).spout_contact_offset) && (t_stats_temp(lick_idx).spout_contact_offset - t_stats_temp(lick_idx).spout_contact) >= 5

                % filter spout location data relative to lick onset/offset
                spout_x_mid_temp2 = spout_x_mid_temp(t_stats_temp(lick_idx).spout_contact:t_stats_temp(lick_idx).spout_contact_offset);
                spout_z_mid_temp2 = spout_z_mid_temp(t_stats_temp(lick_idx).spout_contact:t_stats_temp(lick_idx).spout_contact_offset);
                spout_y_temp2 = spout_y_temp(t_stats_temp(lick_idx).spout_contact:t_stats_temp(lick_idx).spout_contact_offset);

                trial_mask_start_ind = trial_vid_cue_time;    
                tongue_bot_mask_temp = tongue_bot_mask(trial_mask_start_ind+t_stats_temp(lick_idx).spout_contact:trial_mask_start_ind+t_stats_temp(lick_idx).spout_contact_offset, :, :);
                tongue_top_mask_temp = tongue_top_mask(trial_mask_start_ind+t_stats_temp(lick_idx).spout_contact:trial_mask_start_ind+t_stats_temp(lick_idx).spout_contact_offset, :, :);
                
                % find tongue-spout distances
                [contact_centroid_temp, contact_area_temp] = getTongueSpoutDist(spout_width_pix, spout_x_mid_temp2, spout_z_mid_temp2, spout_y_temp2, tongue_bot_mask_temp, tongue_top_mask_temp, params);
            else 
                contact_centroid_temp = NaN;
                contact_area_temp = NaN;
            end

            % repeat for 'double-tap' licks (where a mouse contacts twice on
            % the same lick)
            if ~isnan(t_stats_temp(lick_idx).spout_contact2) && ~isnan(t_stats_temp(lick_idx).spout_contact_offset2) && (t_stats_temp(lick_idx).spout_contact_offset2 - t_stats_temp(lick_idx).spout_contact2) >= 5

                % filter spout location data relative to lick onset/offset
                spout_x_mid_temp2 = spout_x_mid_temp(t_stats_temp(lick_idx).spout_contact2:t_stats_temp(lick_idx).spout_contact_offset2);
                spout_z_mid_temp2 = spout_z_mid_temp(t_stats_temp(lick_idx).spout_contact2:t_stats_temp(lick_idx).spout_contact_offset2);
                spout_y_temp2 = spout_y_temp(t_stats_temp(lick_idx).spout_contact2:t_stats_temp(lick_idx).spout_contact_offset2);

                trial_mask_start_ind = trial_vid_cue_time;   
                tongue_bot_mask_temp = tongue_bot_mask(trial_mask_start_ind+t_stats_temp(lick_idx).spout_contact2:trial_mask_start_ind+t_stats_temp(lick_idx).spout_contact_offset2, :, :);
                tongue_top_mask_temp = tongue_top_mask(trial_mask_start_ind+t_stats_temp(lick_idx).spout_contact2:trial_mask_start_ind+t_stats_temp(lick_idx).spout_contact_offset2, :, :);

                % find tongue-spout distances
                [contact_centroid_temp2, contact_area_temp2] = getTongueSpoutDist(spout_width_pix, spout_x_mid_temp2, spout_z_mid_temp2, spout_y_temp2, tongue_bot_mask_temp, tongue_top_mask_temp, params);
            else 
                contact_centroid_temp2 = NaN;
                contact_area_temp2 = NaN;
            end
            contact_centroid{lick_idx} = contact_centroid_temp;
            contact_area{lick_idx} = contact_area_temp;
            contact_centroid2{lick_idx} = contact_centroid_temp2;
            contact_area2{lick_idx} = contact_area_temp2;
        end
        [t_stats([t_stats.trial_num] == trial_num).contact_centroid] = contact_centroid{:};
        [t_stats([t_stats.trial_num] == trial_num).contact_area] = contact_area{:};
        [t_stats([t_stats.trial_num] == trial_num).contact_centroid2] = contact_centroid2{:};
        [t_stats([t_stats.trial_num] == trial_num).contact_area2] = contact_area2{:};

    elseif isempty(t_stats_temp) || sum([t_stats_temp.lick_index] <= 0) 
        nan_temp = num2cell(nan(1, numel(t_stats_temp)));
        [t_stats([t_stats.trial_num] == trial_num).contact_centroid] = nan_temp{:};
        [t_stats([t_stats.trial_num] == trial_num).contact_area] = nan_temp{:};
        [t_stats([t_stats.trial_num] == trial_num).contact_centroid2] = nan_temp{:};
        [t_stats([t_stats.trial_num] == trial_num).contact_area2] = nan_temp{:};
    end    
end

end

function [contact_centroid, contact_area] = getTongueSpoutDist(spout_width_pix, spout_x_mid_temp2, spout_z_mid_temp2, spout_y_temp2, tongue_bot_mask_temp, tongue_top_mask_temp, params)

% initialize contact_centroid
contact_centroid = zeros(numel(spout_x_mid_temp2), 3);

% radius of spout width
radius = spout_width_pix/2;
spout_y_thresh = 172;

% loop over each timestep where a contact occured
tongue_dist = cell(numel(spout_x_mid_temp2), 2);
[x, y, z] = meshgrid(1:192, 1:240, 1:144);

yshift_scalar = 5;
dil_scalar = 5;
dist_thresh = 1;
for t = 1:numel(spout_x_mid_temp2)
    
    % on the first contact timestep, create the 3D spout reconstruction
    if t == 1
        spout_3D = sqrt((y - spout_x_mid_temp2(t)).^2 + (z - spout_z_mid_temp2(t)).^2) <= radius & (x >= spout_y_temp2(t) & x <= spout_y_thresh);
    % on all timesteps following the first, only re-create the spout
    % reconstruction if the spout has moved (if the values of the spout
    % position at time t does not equal those at time t - 1.
    elseif t > 1
        if spout_x_mid_temp2(t) ~= spout_x_mid_temp2(t - 1) || spout_z_mid_temp2(t) ~= spout_z_mid_temp2(t - 1) || spout_y_temp2(t) ~= spout_y_temp2(t - 1)
            spout_3D = sqrt((y - spout_x_mid_temp2(t)).^2 + (z - spout_z_mid_temp2(t)).^2) <= radius & (x >= spout_y_temp2(t) & x <= spout_y_thresh);
        end
    end
    
    % get masks at current timestemp
    tongue_bot_mask_frame = squeeze(tongue_bot_mask_temp(t, :, :));
    tongue_top_mask_frame = squeeze(tongue_top_mask_temp(t, :, :));
    
    % preprocess masks
    top_dim = [size(tongue_top_mask_frame, 1), size(tongue_top_mask_frame, 2)];
    centroid_avoid = [] ;      
    [tongue_bot_mask_frame, tongue_top_mask_frame] = processTongueMasks(tongue_bot_mask_frame, tongue_top_mask_frame, params, top_dim, centroid_avoid);
    
    % create the full tongue 3D reconstruction
    tongue_bot_3D = repmat(tongue_bot_mask_frame, 1, 1, size(tongue_top_mask_frame, 1));
    tongue_top_3D = repmat(tongue_top_mask_frame, 1, 1, size(tongue_bot_mask_frame, 1));
    tongue_top_3D = permute(tongue_top_3D, [3 2 1]);
    tongue_3D = tongue_top_3D & tongue_bot_3D;
    
    % find the contact points between the spout and real tongue
    tongue_contact_pts = tongue_3D & spout_3D;

    % If there are no contact points, first try to shift the spout forward
    % incrementally until there are contact points.If there is still no 
    % contact points, increase radius of spout and shift forward. Repeat 
    % until the upper bound of radius and shift until there are contact 
    % points. If still no contact points are  detected, we have a bad mask,
    % so NaN contact points.
    yshift_scalar_temp = yshift_scalar;
    radius_temp = 0;
    while sum(tongue_contact_pts, 'all') == 0
        if radius_temp <= 15 && sum(tongue_contact_pts, 'all') == 0
            while yshift_scalar_temp < 20
                if sum(tongue_contact_pts, 'all') == 0
                    spout_3D_temp = sqrt((y - spout_x_mid_temp2(t)).^2 + (z - spout_z_mid_temp2(t)).^2) <= (radius + radius_temp) & (x >= (spout_y_temp2(t) - yshift_scalar_temp) & x <= spout_y_thresh);
                    tongue_contact_pts = tongue_3D & spout_3D_temp;
                    yshift_scalar_temp = yshift_scalar_temp + 5;
                else
                    break
                end
            end
            yshift_scalar_temp = yshift_scalar;
            radius_temp = radius_temp + 3;
        elseif radius_temp > 15 && sum(tongue_contact_pts, 'all') == 0
            tongue_contact_pts = NaN;
            contact_pts = NaN;
            break
        end
    end  
    
    % here, we only want to find an estimate of the points on the spout
    % that contacted the tongue. This will be used to calculate the
    % distance between each point of contact on the spout and tongue,
    % and we will use the distance threshold to filter points that are
    % too far away to be considered contact points. Note that, we only need
    % a rough estimate of contact points on the spout to do this.  So
    % dilation only is fine here - no need to shift forward as dilation
    % will do this as well. 
    if ~isnan(tongue_contact_pts)
        tongue_contact_idx = find(tongue_contact_pts);

        % filter only the contact points on tongue that contacted spout
        tongue_3D_shell = get3MaskSurface(tongue_3D);
        tongue_idx = find(tongue_3D_shell);
        tongue_idx = tongue_idx(ismember(tongue_idx, tongue_contact_idx));
        [tongue_x, tongue_y, tongue_z] = ind2sub(size(tongue_3D), tongue_idx);
        tongue_pts = [tongue_x tongue_y tongue_z];

        % find bound. box inds to reduce vol of tongue_contact_pts before dilation
        [~, ylims, xlims, zlims] = crop3Mask(tongue_contact_pts);
        tongue_contact_pts_box = tongue_contact_pts(ylims(1):ylims(2), xlims(1):xlims(2), zlims(1):zlims(2));
        tongue_3D_contact = false(240, 192, 144);
        tongue_3D_contact(ylims(1):ylims(2), xlims(1):xlims(2), zlims(1):zlims(2)) = tongue_contact_pts_box;

        % find the contact points between the spout and real tongue
        spout_contact_pts = spout_3D & tongue_3D_contact;       

        % if there are no contact points, increase the dilation factor until
        % the tongue contacts the spout, then find indices.
        dil_scalar_temp = dil_scalar;
        while sum(spout_contact_pts, 'all') == 0           
            pos1 = [ylims(1)-dil_scalar_temp xlims(1)-dil_scalar_temp zlims(1)-dil_scalar_temp];
            pos2 = [ylims(2)+dil_scalar_temp xlims(2)+dil_scalar_temp zlims(2)+dil_scalar_temp];
            
            if sum(pos1 < 1) > 0
                pos1(pos1<1) = 1;
            end

            pos2_lim = [240 192 144];    
            if sum(pos2 > pos2_lim) > 0
                pos2(pos2 > pos2_lim) = pos2_lim(pos2 > pos2_lim);
            end
            
            tongue_contact_pts_box = tongue_contact_pts(pos1(1):pos2(1), pos1(2):pos2(2), pos1(3):pos2(3));
            tongue_3D_box_dilate = imdilate(tongue_contact_pts_box, ones(dil_scalar_temp, dil_scalar_temp, dil_scalar_temp));
            tongue_3D_dilate = false(240, 192, 144);
            tongue_3D_dilate(pos1(1):pos2(1), pos1(2):pos2(2), pos1(3):pos2(3)) = tongue_3D_box_dilate;
            spout_contact_pts = spout_3D & tongue_3D_dilate;
            dil_scalar_temp = dil_scalar_temp + 5;
        end 
        spout_contact_idx = find(spout_contact_pts);

        % filter only the contact points on spout that contacted dilated tongue
        spout_idx = find(get3MaskSurface(spout_3D));
        spout_idx = spout_idx(ismember(spout_idx, spout_contact_idx));
        [spout_x, spout_y, spout_z] = ind2sub(size(spout_3D), spout_idx);
        spout_pts = [spout_x spout_y spout_z];    

        % for some licks, the tongue and the spout overlap - such that the
        % distance for tongue points 'inside' of the spout are further away
        % than the points that are the closest.  find overlap between the
        % tongue and 'filled' spout - if there are overlap points, they must be
        % contact points as well.  
        overlap_3D = tongue_3D_shell & spout_3D;
        [overlap_x, overlap_y, overlap_z] = ind2sub(size(overlap_3D), find(overlap_3D));
        overlap_pts = [overlap_x, overlap_y, overlap_z];

        % calculate euclidean distance - must do it for all tongue_pts, even
        % though we can reduce them be excluding overlap points, bc the
        % distance threshold will change.
        [dist, dist_ind] = pdist2(tongue_pts, spout_pts, 'squaredeuclidean', 'Smallest', 1);
        dist = sqrt(dist);
        min_dist = min(dist) + dist_thresh;
        dist_pts = tongue_pts(unique(dist_ind(dist<=min_dist)), :);

        % combine the overlap and distance points into one array
        contact_pts = [dist_pts(~ismember(dist_pts, overlap_pts, 'rows'), :); overlap_pts];
    end
    
    % if there are contact points...
    if ~isempty(contact_pts)
        % and if there is more than one contact point, take the mean
        if numel(contact_pts) > 3
            tongue_dist{t, 1} = mean(contact_pts);
        % and if there is only 1 contact point, use that
        else
            tongue_dist{t, 1} = contact_pts;
        end
        tongue_dist{t, 2} = size(contact_pts, 1);
    % if there were no contact points detected, NaN both entries
    elseif isnan(contact_pts)
        tongue_dist{t, 1} = [NaN NaN NaN];
        tongue_dist{t, 2} = NaN;
    % this case below should not be a concern, but just in case...
    elseif isempty(contact_pts)
        disp('Warning! No contact points detected on a lick and timestep that made contact')
    end
end

% interpolate any NaNs in middle of contact, if there are any
area_temp = [tongue_dist{:, 2}];
% detect if nan exists
if sum(isnan(area_temp)) > 0 
    area_nan = ~isnan(area_temp);
    
    % if there is more than one real value, and the first and last values
    % are real, then interpolate the nan as it is in the middle
    if sum(area_nan) > 1 && area_nan(1) == 0 && area_nan(end) == 0
        area_interp = cumsum(area_nan-diff([1,area_nan])/2);
        contact_area = interp1(1:nnz(area_nan),area_temp(area_nan),area_interp);
        
    % if there is a nan at the beginning or end of the sequence,
    % extrapolate that value
    elseif sum(area_nan) > 1 && (area_nan(1) == 0 || area_nan(end) == 0)
        area_interp = cumsum(area_nan-diff([1,area_nan])/2);
        contact_area = interp1(1:nnz(area_nan),area_temp(area_nan),area_interp, 'linear', 'extrap');
         
    % any other time, assign all values as nan
    else
        contact_area = nan(1,numel(area_temp));
    end
else
    contact_area = area_temp;
end

contact_temp = vertcat(tongue_dist{:,1});
if sum(isnan(contact_temp)) > 0
    contact_nan = ~isnan(contact_temp);
    
    if sum(contact_nan, 'all') > 3 && contact_nan(1) == 0 && contact_nan(end) == 0
        for n = 1:size(contact_temp, 2)
            contact_interp = cumsum(contact_nan(:,n)-diff([1;contact_nan(:,n)])/2);
            contact_centroid(:,n) = interp1(1:nnz(contact_nan(:,n)),contact_temp(contact_nan(:,n),n),contact_interp);
        end
        
    elseif sum(contact_nan, 'all') > 3 && (contact_nan(1) == 0 || contact_nan(end) == 0)
        for n = 1:size(contact_temp, 2)
            contact_interp = cumsum(contact_nan(:,n)-diff([1;contact_nan(:,n)])/2);
            contact_centroid(:,n) = interp1(1:nnz(contact_nan(:,n)),contact_temp(contact_nan(:,n),n),contact_interp, 'linear', 'extrap');
        end
        
    else
        contact_centroid = nan(size(contact_temp));
    end 
else
    contact_centroid = contact_temp;
end
end