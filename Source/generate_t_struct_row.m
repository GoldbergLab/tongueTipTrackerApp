function [t_stats_row, abort_trial] = generate_t_struct_row(options)
% Generate a single t_struct row (representing a single lick)
arguments
    options.trial_num double = []   % Trial num
    options.tip_tracks = []         % Tip track struct
    options.onset double = []       % Lick onset time
    options.offset double = []      % Lick offset time
    options.cue_onset double = nan  % Cue onset time
    options.laser_trial = false     % Is this lick from a laser on trial?
    options.lowpass_filter = []     % Filter to filter trajectories with
    options.placeholder = false     % Is this a placeholder trial?
end

% Unpack arguments into variables
trial_num = options.trial_num;
tip_tracks = options.tip_tracks;
onset = options.onset;
offset = options.offset;
cue_onset = options.cue_onset;
laser_trial = options.laser_trial;
lowpass_filter = options.lowpass_filter;
null_trial = options.placeholder;

abort_trial = false;

% Initialize row 
t_stats_row = struct();

if ~null_trial
    % Unpack centroid coords for easier use
    centroid_x = tip_tracks.centroid_coords(onset:offset,1);
    centroid_y = tip_tracks.centroid_coords(onset:offset,2);
    centroid_z = tip_tracks.centroid_coords(onset:offset,3);

    % Unpack tip coords for easier use
    tip_x = tip_tracks.tip_coords(onset:offset,1);
    tip_y = tip_tracks.tip_coords(onset:offset,2);
    tip_z = tip_tracks.tip_coords(onset:offset,3);

    % Unpack tongue volumes
    volume = tip_tracks.volumes(onset:offset);
else
    % This is a placeholder trial - use nans instead
    centroid_x = [nan, nan];
    centroid_y = [nan, nan];
    centroid_z = [nan, nan];

    tip_x = [nan, nan];
    tip_y = [nan, nan];
    tip_z = [nan, nan];

    % No tongue visible, no volume
    volume = 0;
end

if ~null_trial && isempty(lowpass_filter)
    % No filter provided, construct one
    filter_coeffs = fdesign.lowpass('N,F3db', 3, 50, 1000);
    lowpass_filter = design(filter_coeffs, 'butter');
end

% nan filter with extrapolation
idx = 1:numel(tip_x);
vect_interp = isnan(tip_x);
if ~null_trial
    tip_x(vect_interp) = interp1(idx(~vect_interp),tip_x(~vect_interp),idx(vect_interp),'linear','extrap');                    
    tip_y(vect_interp) = interp1(idx(~vect_interp),tip_y(~vect_interp),idx(vect_interp),'linear','extrap');
    tip_z(vect_interp) = interp1(idx(~vect_interp),tip_z(~vect_interp),idx(vect_interp),'linear','extrap');
    
    tip_x = filter_and_scale(tip_x,lowpass_filter);
    tip_y = filter_and_scale(tip_y,lowpass_filter);
    tip_z = filter_and_scale(tip_z,lowpass_filter);
    
    centroid_x = filter_and_scale(centroid_x,lowpass_filter);
    centroid_y = filter_and_scale(centroid_y,lowpass_filter);
    centroid_z = filter_and_scale(centroid_z,lowpass_filter);
end

% 3D Speed
x_plt_c = centroid_x;
y_plt_c = centroid_y;
z_plt_c = centroid_z;
magspeed_cent = sqrt(diff(x_plt_c).^2 + diff(y_plt_c).^2 + diff(z_plt_c).^2);

% 3D Speed for Tip
x_plt_t = tip_x;
y_plt_t = tip_y;
z_plt_t = tip_z;
magspeed_tip = sqrt(diff(x_plt_t).^2 + diff(y_plt_t).^2 + diff(z_plt_t).^2);

% 3D Accelerations
if ~null_trial
    accel = diff(magspeed_cent);
    mag_accel = abs(accel);
    [~,accel_peaks_p_cent] = findpeaks(accel);
    [~,accel_peaks_tot_cent] = findpeaks(mag_accel);
else
    accel_peaks_p_cent = [];
    accel_peaks_tot_cent = [];
end

if ~null_trial
    accel = diff(magspeed_tip);
    mag_accel = abs(accel);
    [~,accel_peaks_p_tip] = findpeaks(accel);
    [~,accel_peaks_tot_tip] = findpeaks(mag_accel);
else
    accel_peaks_p_tip = [];
    accel_peaks_tot_tip = [];
end

% Pathlength
if ~null_trial
    pathlength_3D_c = sum(magspeed_cent);
    pathlength_3D_t = sum(magspeed_tip);
else
    pathlength_3D_c = 0;
    pathlength_3D_t = 0;
end

% Duration
if ~null_trial
    dur = offset-onset;
else
    dur = NaN;
end

% Package the kinematic data
t_stats_row.centroid_x = centroid_x;
t_stats_row.centroid_y = centroid_y;
t_stats_row.centroid_z = centroid_z;

t_stats_row.tip_x = tip_x;
t_stats_row.tip_y = tip_y;
t_stats_row.tip_z = tip_z;

t_stats_row.magspeed_c = magspeed_cent;
t_stats_row.magspeed_t = magspeed_tip;
t_stats_row.pathlength_3D_c = pathlength_3D_c;
t_stats_row.pathlength_3D_t = pathlength_3D_t;

t_stats_row.accel_peaks_pos_t = accel_peaks_p_tip;
t_stats_row.accel_peaks_tot_t = accel_peaks_tot_tip;                                                            

t_stats_row.accel_peaks_pos_c = accel_peaks_p_cent;
t_stats_row.accel_peaks_tot_c = accel_peaks_tot_cent;
t_stats_row.dur = dur;

% Tongue Kinematic Segmentation
if ~null_trial
    [seginfo,redir_pts,rad_curv] = get_t_kinsegments(t_stats_row);
else
    seginfo = struct.empty();
    redir_pts = [];
    rad_curv = [];
end
t_stats_row.redir_pts = redir_pts;
t_stats_row.seginfo = seginfo;
t_stats_row.rad_curv = rad_curv;                                                                 

% Tortuosity
curv = 1./rad_curv;
tort = sum(curv.^2)/pathlength_3D_c;
t_stats_row.tort = tort;

% Get Protraction/Retraction from Volume information.
if ~null_trial
    volume = filter_and_scale(volume,lowpass_filter);
    vol_diff = abs(diff(volume));
    try
        [~,locs_asmin] = findpeaks(1./vol_diff);
    
        prot_ind = locs_asmin(1);
        ret_ind = locs_asmin(end);
    catch ME
        %%% ******** Note - this seems a bit off - if lick N
        %%% has no volumne minimum, then all licks M > N are
        %%% skipped. Not sure that's the best behavior, but to
        %%% change it just switch a "continue" for that "break".
        disp(getReport(ME));
        abort_trial = true;
        return;
    end
else
    prot_ind = NaN;
    ret_ind = NaN;
end

% Package the trial information/metadata
if ~null_trial
    laser_valid = (onset>cue_onset) & (onset<(cue_onset+750));
    t_stats_row.time_rel_cue = onset-cue_onset;
    t_stats_row.volume = volume;
    t_stats_row.pairs = [onset, offset];
else
    laser_valid = false;
    t_stats_row.time_rel_cue = NaN;
    t_stats_row.volume = NaN;
    t_stats_row.pairs = [NaN, NaN];
end
t_stats_row.laser = laser_trial && laser_valid;
t_stats_row.laser_trial = laser_trial;
t_stats_row.trial_num = trial_num;
t_stats_row.prot_ind = prot_ind;
t_stats_row.ret_ind = ret_ind;

% ILM_information
if ~null_trial
    t_stats_row.ILM_dur = ret_ind - prot_ind;
    t_stats_row.ILM_pathlength = sum(magspeed_tip(prot_ind:ret_ind));
    t_stats_row.ILM_PeakSpeed = max(magspeed_tip(prot_ind:ret_ind));
    t_stats_row.ILM_NumAcc = sum((accel_peaks_p_cent>prot_ind)&(accel_peaks_p_cent<ret_ind));
else
    t_stats_row.ILM_dur = NaN;
    t_stats_row.ILM_pathlength = NaN;
    t_stats_row.ILM_PeakSpeed = NaN;
    t_stats_row.ILM_NumAcc = NaN;
end

t_stats_row.lick_index = [];

t_stats_row.placeholder = null_trial;
