function [t_stats_trial, abort_trial] = generate_trial_t_struct(tip_tracks, video_num, onset, offset, cue_onset, laser_trial, lowpass_filter)
arguments
    tip_tracks struct = struct('tip_coords', zeros(0, 3), 'centroid_coords', zeros(0, 3), 'volumes', zeros(0, 3))
    video_num double = []
    onset double = []
    offset double = []
    cue_onset double = []
    laser_trial = false
    lowpass_filter = []
end

abort_trial = false;
t_stats_trial = struct();

centroid_x = tip_tracks.centroid_coords(onset:offset,1);
centroid_y = tip_tracks.centroid_coords(onset:offset,2);
centroid_z = tip_tracks.centroid_coords(onset:offset,3);

tip_x = tip_tracks.tip_coords(onset:offset,1);
tip_y = tip_tracks.tip_coords(onset:offset,2);
tip_z = tip_tracks.tip_coords(onset:offset,3);

null_trial = isempty(tip_x);

volume = tip_tracks.volumes(onset:offset);

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
if ~isempty(magspeed_cent)
    accel = diff(magspeed_cent);
    mag_accel = abs(accel);
    [~,accel_peaks_p_cent] = findpeaks(accel);
    [~,accel_peaks_tot_cent] = findpeaks(mag_accel);
else
    accel_peaks_p_cent = [];
    accel_peaks_tot_cent = [];
end

if ~isempty(magspeed_cent)
    accel = diff(magspeed_tip);
    mag_accel = abs(accel);
    [~,accel_peaks_p_tip] = findpeaks(accel);
    [~,accel_peaks_tot_tip] = findpeaks(mag_accel);
else
    accel_peaks_p_tip = [];
    accel_peaks_tot_tip = [];
end

% Pathlength
pathlength_3D_c = sum(magspeed_cent);
pathlength_3D_t = sum(magspeed_tip);

% Duration
dur = offset-onset;

% Package the kinematic data
t_stats_trial.centroid_x = centroid_x;
t_stats_trial.centroid_y = centroid_y;
t_stats_trial.centroid_z = centroid_z;

t_stats_trial.tip_x = tip_x;
t_stats_trial.tip_y = tip_y;
t_stats_trial.tip_z = tip_z;

t_stats_trial.magspeed_c = magspeed_cent;
t_stats_trial.magspeed_t = magspeed_tip;
t_stats_trial.pathlength_3D_c = pathlength_3D_c;
t_stats_trial.pathlength_3D_t = pathlength_3D_t;

t_stats_trial.accel_peaks_pos_t = accel_peaks_p_tip;
t_stats_trial.accel_peaks_tot_t = accel_peaks_tot_tip;                                                            

t_stats_trial.accel_peaks_pos_c = accel_peaks_p_cent;
t_stats_trial.accel_peaks_tot_c = accel_peaks_tot_cent;
t_stats_trial.dur = dur;

% Tongue Kinematic Segmentation
if ~null_trial
    [seginfo,redir_pts,rad_curv] = get_t_kinsegments(t_stats_trial);
else
    seginfo = struct.empty();
    redir_pts = [];
    rad_curv = [];
end
t_stats_trial.redir_pts = redir_pts;
t_stats_trial.seginfo = seginfo;
t_stats_trial.rad_curv = rad_curv;                                                                 

% Tortuosity
curv = 1./rad_curv;
tort = sum(curv.^2)/pathlength_3D_c;
t_stats_trial.tort = tort;

% Get Protraction/Retraction from Volume information.
if ~isempty(volume)
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
    prot_ind = [];
    ret_ind = [];
end

% Package the trial information/metadata
t_stats_trial.time_rel_cue = onset-cue_onset;
laser_valid = (onset>cue_onset) & (onset<(cue_onset+750));
if isempty(laser_valid)
    laser_valid = false;
end
t_stats_trial.laser = laser_trial && laser_valid;
t_stats_trial.laser_trial = laser_trial;
t_stats_trial.trial_num = video_num;
t_stats_trial.volume = volume;
t_stats_trial.pairs = [onset, offset];
t_stats_trial.prot_ind = prot_ind;
t_stats_trial.ret_ind = ret_ind;                    

% ILM_information
t_stats_trial.ILM_dur = ret_ind-prot_ind;
t_stats_trial.ILM_pathlength = sum(magspeed_tip(prot_ind:ret_ind));
t_stats_trial.ILM_PeakSpeed = max(magspeed_tip(prot_ind:ret_ind));
t_stats_trial.ILM_NumAcc = sum((accel_peaks_p_cent>prot_ind)&(accel_peaks_p_cent<ret_ind));

t_stats_trial.lick_index = [];
