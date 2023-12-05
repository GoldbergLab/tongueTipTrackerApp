%--------------------------------------------------------------------------
% generates a structure containing the free parameters for the tongue tip
% tracking code. Currently, changes must be hard-coded within this file,
% but future iterations will (hopefully) allow changes programmatically
%--------------------------------------------------------------------------

function parameters = setTrackParams(user_parameters)

% initialize structure
parameters = struct() ; 

% min number of pixels in mask or voxels in recon. to analyze frame
parameters.N_pix_min = 5 ; 
parameters.N_vox_min = 5 ; 

% normalized initial guess vector with which to compare voxel coordinates
parameters.init_vec_1 = (sqrt(2)/2)*[0, 1, -1] ; % NB: should try to automate this guess

% angle thresholds for defining search cone
parameters.theta_max_1 = pi/4 ; % radians
parameters.theta_max_2 = pi/12 ; 

% distance percentile level for which to consider points 
parameters.dist_prctile_1 = 75 ;
parameters.dist_prctile_2 = [] ; % at this point in the current code, we're already at the boundary

% transformation to apply to top image to match bottom image
parameters.im_shift = 5 ; % amount to translate top image by. based on spout comparison
parameters.im_scale_user = 1.0 ; % scale top image. ***only used when code fails to estimate scaling

% structural element used to erode pixels/voxels (and thus find boundary voxels)
parameters.sphere_se = strel('sphere',1) ;
parameters.disk_se_radius = 4 ; % starting radius for S.E. used to combine broken bot mask
parameters.solidity_thresh = 0.95 ; % if solidity less than this, take convex hull (trying to deal with spout occlusion)

% minimum duration of lick bout to consider
parameters.min_bout_duration = 3 ; % frames

% settings for filtering kinematic data
parameters.filter_type = 'butter' ; 
parameters.filter_order = 3 ; 
parameters.filter_hpf = 50 ; % Hz (half power frequency of low-pass filter)
parameters.Fs = 1000 ; %Hz (sampling rate of video)

% method for segmenting tongue trajectories (based on area vs volume
% expansion)
parameters.seg_type = 'vol' ; %or 'area' 

% plotting preferences
parameters.view_az = 112 ; 
parameters.view_el = 8 ; 
parameters.line_width_thick = 2 ; 
parameters.line_width_thin = 1 ; 
parameters.marker_size_tiny = 0.5 ; 
parameters.marker_size_small = 5 ; 
parameters.marker_size_large = 10 ; 
parameters.hull_color = 0.7*[1 1 1] ; % color and transparency for tongue outline 
parameters.hull_alpha = 0.2 ;  %0.2
parameters.figPosition = [] ; % I use the position for full screen on one monitor here
parameters.axis_trim = 40 ; % amount to trim 3D plot (full) axes by
parameters.FPS = 10 ; % frame rate for movie making

% flags for plotting, saving, etc.
parameters.plotFlag1 = false ; % create movie showing tongue tracking w/ voxels and images?
parameters.plotFlag2 = false ; % plot 3D trajectory, speed, curvature, and torsion?
parameters.savePlotsFlag = false ;
parameters.saveDataFlag = false ; 
parameters.verboseFlag = false ; % print out frame count?

if ~exist('user_parameters', 'var')
    % If user passed in user_parameters struct, use those values to
    % override the defaults
    user_fields = fields(user_parameters);
    for k = 1:length(user_fields)
        user_field = user_fields{k};
        if ~isfield(parameters, user_field)
            % Warn user if they're setting a field that doesn't exist in
            % the default set of parameters.
            warning('Warning, %s is not a default field - check the spelling.', user_field);
        end
        parameters.(user_field) = user_parameters.(user_field);
    end
end