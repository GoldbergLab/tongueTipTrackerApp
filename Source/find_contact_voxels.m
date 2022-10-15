function t_stats = find_contact_voxels(t_stats, sessionMaskRoot)

% load('X:\bsi8\2D_Doublestep_Data\ALM_TJS1\ALM_TJS1_6\Masks\211117_ALM_TJS1_6_fakeout2D_ALM_L2_250ms\t_stats.mat');
% t_stats_folder = 'X:\bsi8\2D_Doublestep_Data\ALM_TJS1\ALM_TJS1_6\Masks\211117_ALM_TJS1_6_fakeout2D_ALM_L2_250ms';

% spout width in mm - for thin spout
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

% get trial numbers
trial_num = unique([t_stats.trial_num]);

% loop through each trial
for i = 1%:8%1:max(trial_num)

    % extract data per trial
    t_stats_temp = t_stats([t_stats.trial_num] == i);

    spout_x_mid_temp = spout_x_mid([t_stats.trial_num] == i);
    spout_x_mid_temp = spout_x_mid_temp{1};
    
    spout_z_mid_temp = spout_z_mid([t_stats.trial_num] == i);
    spout_z_mid_temp = spout_z_mid_temp{1};
    
    spout_y_temp = spout_y([t_stats.trial_num] == i);
    spout_y_temp = spout_y_temp{1};
    
    tongue_bot_mask = load(append(sessionMaskRoot, '\', sprintf('Bot_%03d', i-1)));
    tongue_bot_mask = tongue_bot_mask.mask_pred;
    
    tongue_top_mask = load(append(sessionMaskRoot, '\', sprintf('Top_%03d', i-1)));
    tongue_top_mask = tongue_top_mask.mask_pred;
    
    % loop through each lick per trial and filter times when contact occured
    tongue_dist = cell(size(t_stats_temp));
    tongue_dist2 = cell(size(t_stats_temp));
    for j = 3%1:numel(t_stats_temp)  
         
        if ~isnan(t_stats_temp(j).spout_contact) && ~isnan(t_stats_temp(j).spout_contact_offset)
            
            % filter spout location data relative to lick onset/offset
            spout_x_mid_temp2 = spout_x_mid_temp(t_stats_temp(j).spout_contact:t_stats_temp(j).spout_contact_offset);
            spout_z_mid_temp2 = spout_z_mid_temp(t_stats_temp(j).spout_contact:t_stats_temp(j).spout_contact_offset);
            spout_y_temp2 = spout_y_temp(t_stats_temp(j).spout_contact:t_stats_temp(j).spout_contact_offset);

            tongue_bot_mask_temp = tongue_bot_mask(1000+t_stats_temp(j).spout_contact:1000+t_stats_temp(j).spout_contact_offset, :, :);
            tongue_top_mask_temp = tongue_top_mask(1000+t_stats_temp(j).spout_contact:1000+t_stats_temp(j).spout_contact_offset, :, :);

            % find tongue-spout distances
            tongue_dist_temp = getTongueSpoutDist(spout_width_pix, spout_x_mid_temp2, spout_z_mid_temp2, spout_y_temp2, tongue_bot_mask_temp, tongue_top_mask_temp);
        else 
            tongue_dist_temp = NaN;
        end
        
        % repeat for 'double-tap' licks (where a mouse contacts twice on
        % the same lick)
        if ~isnan(t_stats_temp(j).spout_contact2) && ~isnan(t_stats_temp(j).spout_contact_offset2)
            
            % filter spout location data relative to lick onset/offset
            spout_x_mid_temp2 = spout_x_mid_temp(t_stats_temp(j).spout_contact2:t_stats_temp(j).spout_contact_offset2);
            spout_z_mid_temp2 = spout_z_mid_temp(t_stats_temp(j).spout_contact2:t_stats_temp(j).spout_contact_offset2);
            spout_y_temp2 = spout_y_temp(t_stats_temp(j).spout_contact2:t_stats_temp(j).spout_contact_offset2);

            tongue_bot_mask_temp = tongue_bot_mask(1000+t_stats_temp(j).spout_contact2:1000+t_stats_temp(j).spout_contact_offset2, :, :);
            tongue_top_mask_temp = tongue_top_mask(1000+t_stats_temp(j).spout_contact2:1000+t_stats_temp(j).spout_contact_offset2, :, :);

            % find tongue-spout distances
            tongue_dist_temp2 = getTongueSpoutDist(spout_width_pix, spout_x_mid_temp2, spout_z_mid_temp2, spout_y_temp2, tongue_bot_mask_temp, tongue_top_mask_temp);
        else 
            tongue_dist_temp2 = NaN;
        end
        tongue_dist{j} = tongue_dist_temp;
        tongue_dist2{j} = tongue_dist_temp2;
    end
end

end

function tongue_dist = getTongueSpoutDist(spout_width_pix, spout_x_mid_temp2, spout_z_mid_temp2, spout_y_temp2, tongue_bot_mask_temp, tongue_top_mask_temp)

% radius of spout width
radius = spout_width_pix/2;
spout_y_thresh = 172;

% loop over each timestep where a contact occured
tongue_dist = cell(size(spout_x_mid_temp2));
[x, y, z] = meshgrid(1:192, 1:240, 1:144);
yshift_scalar = 15;
dil_scalar = 20;
dist_thresh = 1;
for k = [1, numel(spout_x_mid_temp2)]
    
    % create the 'dilated' & 'real' 3D spout reconstruction
    if k == 1
        spout_3D_dilate = sqrt((y - spout_x_mid_temp2(k)).^2 + (z - spout_z_mid_temp2(k)).^2) <= (radius + (radius/2)) & (x >= (spout_y_temp2(k) - yshift_scalar) & x <= spout_y_thresh);
        spout_3D = sqrt((y - spout_x_mid_temp2(k)).^2 + (z - spout_z_mid_temp2(k)).^2) <= radius & (x >= spout_y_temp2(k) & x <= spout_y_thresh);
    elseif k > 1
        if spout_x_mid_temp2(k) == spout_x_mid_temp2(k - 1) && spout_z_mid_temp2(k) == spout_z_mid_temp2(k - 1) && spout_y_temp2(k) == spout_y_temp2(k - 1)
            % do not recalculate spout_3D_dilate and spout_3D
        else
            spout_3D_dilate = sqrt((y - spout_x_mid_temp2(k)).^2 + (z - spout_z_mid_temp2(k)).^2) <= (radius + (radius/2)) & (x >= (spout_y_temp2(k) - yshift_scalar) & x <= spout_y_thresh);
            spout_3D = sqrt((y - spout_x_mid_temp2(k)).^2 + (z - spout_z_mid_temp2(k)).^2) <= radius & (x >= spout_y_temp2(k) & x <= spout_y_thresh);
        end
    end
    
    % create the 'real' full tongue 3D reconstruction
    tongue_bot_3D = repmat(squeeze(tongue_bot_mask_temp(k, :, :)), 1, 1, size(tongue_top_mask_temp, 2));
    tongue_top_3D = repmat(squeeze(tongue_top_mask_temp(k, :, :)), 1, 1, size(tongue_bot_mask_temp, 2));
    tongue_top_3D = permute(tongue_top_3D, [3 2 1]);
    tongue_3D = tongue_top_3D & tongue_bot_3D;
    
    % find the contact points between the dilated spout and real tongue
    tongue_contact_pts = tongue_3D & spout_3D_dilate;
    
    % if there are no contact points, shift the dilated spout forward by 5
    % pixels until there are contact points, or until the shift is 25
    % pixels. If there is still no contact points, increase radius of spout
    % by 5 pixel increments until there are contact points.
    yshift_scalar_temp = yshift_scalar;
    radius_temp = radius;
    while sum(tongue_contact_pts, 'all') == 0
        if yshift_scalar_temp < 25 && radius_temp < 21
            yshift_scalar_temp = yshift_scalar_temp + 5;
            spout_3D_dilate = sqrt((y - spout_x_mid_temp2(k)).^2 + (z - spout_z_mid_temp2(k)).^2) <= (radius + (radius/2)) & (x >= (spout_y_temp2(k) - yshift_scalar_temp) & x <= spout_y_thresh);
            tongue_contact_pts = tongue_3D & spout_3D_dilate;
        elseif yshift_scalar_temp >= 25 &&  radius_temp < 21
            radius_temp = radius_temp + 5;
            spout_3D_dilate = sqrt((y - spout_x_mid_temp2(k)).^2 + (z - spout_z_mid_temp2(k)).^2) <= (radius + (radius_temp/2)) & (x >= (spout_y_temp2(k) - yshift_scalar) & x <= spout_y_thresh);
            tongue_contact_pts = tongue_3D & spout_3D_dilate;
        elseif yshift_scalar_temp >= 25 &&  radius_temp > 21
            
            
        end
    end
    tongue_contact_idx = find(tongue_contact_pts);
    
    % filter only the contact points on tongue that contacted dilated spout
    tongue_3D_shell = get3MaskSurface(tongue_3D);
    tongue_idx = find(tongue_3D_shell);
    tongue_idx = tongue_idx(ismember(tongue_idx, tongue_contact_idx));
    [tongue_x, tongue_y, tongue_z] = ind2sub(size(tongue_3D), tongue_idx);
    tongue_pts = [tongue_x tongue_y tongue_z];
    
    % find bound. box inds to reduce vol of tongue_contact_pts before dilation
    [~, ylims, xlims, zlims] = crop3Mask(tongue_contact_pts);
    tongue_contact_pts_box = tongue_contact_pts(ylims(1)-dil_scalar:ylims(2)+dil_scalar, xlims(1)-dil_scalar:xlims(2)+dil_scalar, zlims(1)-dil_scalar:zlims(2)+dil_scalar);
    
    % dilate only the points on the tongue that contacted dilated spout
    tongue_3D_box_dilate = imdilate(tongue_contact_pts_box, ones(dil_scalar, dil_scalar, dil_scalar));
    
    % create empty volume of same size and fill in with dilated tongue
    tongue_3D_dilate = false(240, 192, 144);
    tongue_3D_dilate(ylims(1)-dil_scalar:ylims(2)+dil_scalar, xlims(1)-dil_scalar:xlims(2)+dil_scalar, zlims(1)-dil_scalar:zlims(2)+dil_scalar) = tongue_3D_box_dilate;
    
    % find the contact points between the dilated spout and real tongue
    spout_contact_pts = spout_3D & tongue_3D_dilate;
    
    % if there are no contact points, increase the dilation factor until
    % the tongue contacts the spout, then find indices.
    dil_scalar_temp = dil_scalar;
    while sum(spout_contact_pts, 'all') == 0
        dil_scalar_temp = dil_scalar_temp + 5;
        tongue_contact_pts_box = tongue_contact_pts(ylims(1)-dil_scalar_temp:ylims(2)+dil_scalar_temp, xlims(1)-dil_scalar_temp:xlims(2)+dil_scalar_temp, zlims(1)-dil_scalar_temp:zlims(2)+dil_scalar_temp);
        tongue_3D_box_dilate = imdilate(tongue_contact_pts_box, ones(dil_scalar_temp, dil_scalar_temp, dil_scalar_temp));
        tongue_3D_dilate = false(240, 192, 144);
        tongue_3D_dilate(ylims(1)-dil_scalar_temp:ylims(2)+dil_scalar_temp, xlims(1)-dil_scalar_temp:xlims(2)+dil_scalar_temp, zlims(1)-dil_scalar_temp:zlims(2)+dil_scalar_temp) = tongue_3D_box_dilate;
        spout_contact_pts = spout_3D & tongue_3D_dilate;
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
    min_dist = min(sqrt(dist)) + dist_thresh;
    dist_pts = tongue_pts(unique(dist_ind(dist<=min_dist)), :);
    
    % combine the overlap and distance points into one array
    contact_pts = [dist_pts(~ismember(dist_pts, overlap_pts, 'rows'), :); overlap_pts];
    
    tongue_dist{k} = sum(dist<=min_dist);
    
    
end
end