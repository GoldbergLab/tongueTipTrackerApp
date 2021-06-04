%--------------------------------------------------------------------------
% Function to create hull reconstruction of mouse tongue based on two
% orthogonal camera views (side and bottom). From this hull reconstruction,
% estimate the 3D coordinates of the tongue tip
%
%   INPUTS:
%       -top_frame = bw mask of the tongue as viewed from the side. 
%
%       -bot_mask = bw mask of the tongue as viewed from the bottom 
%       (NB: it is assumed that the width of the top and bottom images are 
%       the same)
%
%       -params (optional) = structure containing parameters used in the
%       tip tracking. If there's no input, it just sets to default. See
%       setTrackParams.m for more details
%
%       -vid_filename (optional): full path to the .avi file of the mouse
%       licking video. not necessary for analysis, but can be used for
%       visualization. Also will potentially be used to deal with noisy
%       mask cases
%
%   OUTPUTS:
%       -tip_coords = 3D voxel coordinates of tongue tip estimate
%       -centroid_coords = 3D voxel coordinates of tongue centroid estimate
%       -volume = estimated voxel volume of tongue
%       -top_area = pixel area of top mask
%       -bot_area = pixel area of bottom mask
%       -top_centroid = 2D pixel centroid of top mask
%       -bot_centroid = 2D pixel centroid of bottom mask
%       -im_scale = scale factor applied to top mask to match with bottom
%       -im_shift = horizontal translation applied to top mask to match 
%           with bottom
%       -coords_b = 3D voxel coordinates of tongue boundary
%       -t_boundary = triangulation of the 3D surface surrounding tongue
%
%   TO DO:
%       - make iteration explicit/tuneable in number
%       - incorporate methods to deal with cases of the spout occluding the
%       side view of the tongue (top mask)
%--------------------------------------------------------------------------
function [tip_coords, centroid_coords, volume, top_area, bot_area, ...
    top_centroid, bot_centroid, im_scale, im_shift, coords_b, t_boundary] = ...
    tongueTipTracker(top_frame, bot_frame, params, vid_filename,centroid_avoid, illustrate)
%--------------------------------------------------------------------------
%% initialization and parameters

% check function inputs
if ~exist('params','var') || isempty(params)
    params = setTrackParams() ;
end

if ~exist('vid_filename','var') || isempty(vid_filename)
    vid_filename = [] ;   
end

if ~exist('centroid_avoid','var') || isempty(centroid_avoid)
    centroid_avoid = [] ;   
end

if ~exist('illustrate', 'var') || isempty(illustrate)
    illustrate = false;
end

% read out parameters from structure
N_pix_min = params.N_pix_min ; % if masks have fewer pixels than this, ignore
N_vox_min = params.N_vox_min ; % if initial recon. has fewer voxels than this, ignore

sphere_se = params.sphere_se ; % structural element used to find boundary

theta_max_1 = params.theta_max_1 ; % angular extent of search cone
dist_prctile_1 = params.dist_prctile_1 ; % distance criteria for distal points
init_vec_1 = params.init_vec_1 ; % center of search cone
theta_max_2 = params.theta_max_2 ;
dist_prctile_2 = params.dist_prctile_2 ;

% size of voxel space and images
top_height = size(top_frame,1) ;
top_width = size(top_frame,2) ;
bot_height = size(bot_frame,1) ;
bot_width = size(bot_frame,2) ;

top_dim = [top_height, top_width] ;
% bot_dim = [bot_height, bot_width] ;

vox_size_vec = [top_height, bot_height, bot_width] ;

%--------------------------------------------------------------------------
%% check pixel count
if (sum(bot_frame(:)) < N_pix_min) || (sum(top_frame(:)) < N_pix_min)
    tip_coords = nan(1,3) ;  
    centroid_coords = nan(1,3) ;  
    volume = nan ; 
    top_area = nan ;  
    bot_area = nan ; 
    top_centroid = nan(1,2) ;
    bot_centroid = nan(1,2) ;
    im_scale = nan ; 
    im_shift = nan ; 
    coords_b = nan ;
    t_boundary = nan ; 
else
    %---------------------------------------------
    %% process masks
    flag = 0;
 
    if illustrate
        f = figure;
        ax = subplot(4, 5, 1);
        imshow(bot_frame);
        title(ax, 'Raw bot frame');
        ax = subplot(4, 5, 2);
        imshow(top_frame);
        title(ax, 'Raw top frame');
    end
    
    [bot_frame, top_frame, bot_s, top_s, im_shift, im_scale] = ...
        processTongueMasks(bot_frame, top_frame, params, top_dim,centroid_avoid) ;

    if illustrate
        ax = subplot(4, 5, 3);
        imshow(bot_frame);
        title(ax, 'Processed bot frame');
        ax = subplot(4, 5, 4);
        imshow(top_frame);
        title(ax, 'Processed top frame');
    end

    % grab some image info from regionprops structs
    try
    top_area = top_s.Area ;  
    bot_area = bot_s.Area ;
    top_centroid = top_s.Centroid ;
    bot_centroid = bot_s.Centroid ;
    catch e
        display(e.message);
    end
        
    %=============================================
    %% attempt voxel reconstruction
    % create voxel volume
    vox_bot = false(vox_size_vec) ;
    vox_top = false(vox_size_vec) ;
    
    % move up in z to fill out "bot" grid
    for z = 1:size(vox_bot,1)
        vox_bot(z,:,:) = bot_frame ;
    end
    
    % move in x to fill out "top" grid
    for x = 1:size(vox_top,2)
        vox_top(:,x,:) = flipud(top_frame) ;
    end
    
    %---------------------------------------------
    % find intersection
    vox = vox_bot & vox_top ;
    if (sum(vox(:)) < N_vox_min)
        tip_coords = nan(1,3) ;
        centroid_coords = nan(1,3) ;
        volume = nan ;
        top_area = nan ;
        bot_area = nan ;
        top_centroid = nan(1,2) ;
        bot_centroid = nan(1,2) ;
        im_scale = nan ;
        im_shift = nan ;
        coords_b = nan ;
        t_boundary = nan ;
    else
        % get voxel x, y, z coordinates
        [R,C,V] = ind2sub(size(vox),find(vox > 0)); %finds index of 'on' pixels
        coords = [C, V, R] ;

        if illustrate
            ax = subplot(4, 5, [6, 7, 11, 12, 16, 17]);
            scatter3(ax, coords(:, 1), coords(:, 2), coords(:, 3), 5);
            title(ax, '3D tongue volume');
        end
        
        % get voxel boundary coordinates
        vox_erode = imerode(vox,sphere_se) ;
        boundary_vox = vox & ~vox_erode ;
        
        [Rb,Cb,Vb] = ind2sub(size(boundary_vox),find(boundary_vox > 0));
        coords_b = [Cb, Vb, Rb] ;
        
        % get centroid of blob and look for tip candidates
        centroid_table = regionprops3(vox, 'Centroid','Volume') ;
        volumes_all = [centroid_table.Volume] ;        
        [volume , max_vol_ind] = max(volumes_all) ;
        centroid = centroid_table.Centroid(max_vol_ind,:) ;
        centroid = [centroid(1), centroid(3), centroid(2)] ;        
        clear vox_bot vox_top vox vox_erode
        %---------------------------------------------
        % make guess for tip vector        
        [tip_guess_1, tip_guess_hat, candidate_coords_1, ~] = makeTipGuess(coords, ...
            centroid, init_vec_1, theta_max_1, dist_prctile_1) ;
        
        if illustrate
            ax = subplot(4, 5, [8, 9, 10, 13, 14, 15, 18, 19, 20]);
            s = scatter3(ax, coords_b(:, 1), coords_b(:, 2), coords_b(:, 3), ...
                10, 'DisplayName', 'Tongue boundary');
            hold(ax, 'on');
            vs = 20;
            quiver3(ax, centroid(1), centroid(2), centroid(3), ...
                vs*init_vec_1(1), vs*init_vec_1(2), vs*init_vec_1(3), 'red', 'DisplayName', 'Initial tip direction guess');
            quiver3(ax, centroid(1), centroid(2), centroid(3), ...
                vs*tip_guess_hat(1), vs*tip_guess_hat(2), vs*tip_guess_hat(3), 'magenta', 'DisplayName', 'Revised tip direction guess');
            scatter3(ax, candidate_coords_1(:, 1), candidate_coords_1(:, 2), candidate_coords_1(:, 3), ...
                15, 'MarkerEdgeColor', 'magenta', 'DisplayName', '1st candidate coords')
            title(ax, 'Tip guess results');
            legend(ax);
        end
        %---------------------------------------------
        % refine guess for tip vector
        init_vec_2 = tip_guess_hat ;
        
        [tip_guess_2, ~, candidate_coords_2, ~] = makeTipGuess(coords_b, ...
            centroid, init_vec_2, theta_max_2, dist_prctile_2) ;

        if illustrate
            fprintf('Final tip coords: %f %f %f\n', tip_guess_2(1), tip_guess_2(2), tip_guess_2(3));
            scatter3(ax, candidate_coords_2(:, 1), candidate_coords_2(:, 2), candidate_coords_2(:, 3), ...
                20, 'MarkerEdgeColor', 'yellow', 'DisplayName', '2nd candidate coords')
            scatter3(ax, tip_guess_2(1), tip_guess_2(2), tip_guess_2(3), ...
                90, 'Marker', 'diamond', 'MarkerEdgeColor', 'green', 'MarkerFaceColor', 'green', 'DisplayName', 'Final tip guess')
            
            projected_tip_coords = project_tip_guess_on_boundary(tip_guess_2, centroid, candidate_coords_2);
            scatter3(ax, projected_tip_coords(1), projected_tip_coords(2), projected_tip_coords(3), ...
                90, 'Marker', 'diamond', 'MarkerEdgeColor', 'cyan', 'MarkerFaceColor', 'cyan', 'DisplayName', 'Projected tip guess')
            
        end
        
        %---------------------------------------------
        % store info on vox coordinates
        tip_coords = tip_guess_2 ;
        centroid_coords = centroid ;
        
        % decimate output to reduce memory costs
        t_boundary = boundary(coords_b(1:10:end,:),0) ;
        coords_b = coords_b(1:10:end,:) ;

    end
end

end

