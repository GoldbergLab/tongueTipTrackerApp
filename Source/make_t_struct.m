function [ t_stats_all ] = make_t_struct(sessionDataRoots, sessionVideoRoots, save_flag, streak_num, fiducial)
%MAKE_XY_STRUCT Summary of this function goes here
%   get xy points from t_struct, separate them into individual licks and
%   estimate kinematic parameters (e.g. pathlength, speed, direction)
arguments
    sessionDataRoots cell {mustBeText}
    sessionVideoRoots cell {mustBeText}
    save_flag (1, 1) logical
    streak_num
    fiducial
end

filterCoeffs = fdesign.lowpass('N,F3db', 3, 50, 1000);
lowpassFilter = design(filterCoeffs, 'butter');

num_sessions = numel(sessionDataRoots);

% Initialize variables
num_trials = zeros(1, num_sessions);
laser_trial = cell(1, num_sessions);
response_bin = cell(1, num_sessions);

for sessionNum = 1:num_sessions
    video_list = findSessionVideos(sessionVideoRoots{sessionNum}, 'avi', @parsePCCFilenameTimestamp);
    num_videos = numel(video_list);

    % Initialize variables
    laser_trial{sessionNum} = zeros(1, num_videos);
    cue_onset = zeros(1, num_videos);

    % Load tip_track.mat file, containing the tongue tip coordinates
    load(fullfile(sessionDataRoots{sessionNum},'tip_track.mat'), 'tip_tracks');

    num_trials(sessionNum) = numel(video_list);
    t_stats_session = [];
    
    for video_num = 1:num_videos
        % Parse cue time and laser on/off status from video filename
        %   See labelTrialsWithCueAndLaser function for more info
        [~, video_name, ~] = fileparts(video_list{video_num});
        vidname_cells = strsplit(video_name, '_');
        descriptor = vidname_cells{end};        
        if descriptor(end) == 'L'
            laser_trial{sessionNum}(video_num) = 1;
            cue_onset(video_num) = str2double(descriptor(2:end-1));
        else
            laser_trial{sessionNum}(video_num) = 0;
            cue_onset(video_num) = str2double(descriptor(2:end));
        end
    end
    
    if numel(streak_num)>0
        streak_on = streak_num(sessionNum,1);
        streak_off = min([num_videos, numel(tip_tracks), streak_num(sessionNum,2)]);
    else
        streak_on = 1;
        streak_off = num_trials(sessionNum);
    end
        
    for video_num = streak_on:streak_off
        % Initialize t_stats rows for this trial/video
        t_stats_video = [];  
        
        lick_exist_vect = tip_tracks(video_num).volumes;
        nan_vect = isnan(lick_exist_vect);
        offset_vect = find(diff(nan_vect)>0);
        onset_vect = find(diff(nan_vect)<0);
        
        response_bin{sessionNum}(video_num) = 0;
        
        onsetOffsetPairs = [];
        lick_num=1;
        for onsetNum = 1:numel(onset_vect)
            % Find the # of offsets between this onset and the next one
            if onsetNum==numel(onset_vect)
                % This is the last onset
                offsetNums = find((offset_vect-onset_vect(onsetNum))>0 & ((offset_vect-numel(nan_vect))<0));
            else
                offsetNums = find((offset_vect-onset_vect(onsetNum))>0 & ((offset_vect-onset_vect(onsetNum+1))<0));
            end
            
            % If the next offset is at least 35 ms after this onset, then
            % it is considered a new lick. If not, ignore the next offset
            % and onset.
            if numel(offsetNums)&&(offset_vect(offsetNums)-onset_vect(onsetNum))>35
                % We have found at least one possible offset and
                %   The 
                onsetOffsetPairs(lick_num,1) = onset_vect(onsetNum)+1;
                onsetOffsetPairs(lick_num,2) = offset_vect(offsetNums)-1;
                lick_num = lick_num+1;
            end
        end
        num_licks = size(onsetOffsetPairs, 1);
        if num_licks > 0
            for lick_num = 1:num_licks
                centroid_x = tip_tracks(video_num).centroid_coords(onsetOffsetPairs(lick_num,1):onsetOffsetPairs(lick_num,2),1);
                centroid_y = tip_tracks(video_num).centroid_coords(onsetOffsetPairs(lick_num,1):onsetOffsetPairs(lick_num,2),2);
                centroid_z = tip_tracks(video_num).centroid_coords(onsetOffsetPairs(lick_num,1):onsetOffsetPairs(lick_num,2),3);

                tip_x = tip_tracks(video_num).tip_coords(onsetOffsetPairs(lick_num,1):onsetOffsetPairs(lick_num,2),1);
                tip_y = tip_tracks(video_num).tip_coords(onsetOffsetPairs(lick_num,1):onsetOffsetPairs(lick_num,2),2);
                tip_z = tip_tracks(video_num).tip_coords(onsetOffsetPairs(lick_num,1):onsetOffsetPairs(lick_num,2),3);
                
                volume = tip_tracks(video_num).volumes(onsetOffsetPairs(lick_num,1):onsetOffsetPairs(lick_num,2));
                
                if (onsetOffsetPairs(lick_num,1)-cue_onset(video_num))<1300 % && (nansum(area_xy_top) + nansum(area_xy_bot))>125000 %&& (pairs(kk,1)-cue_onset(frameNum))>40                    
                    response_bin{sessionNum}(video_num) = 1;
                end    

                %nan filter with extrapolation
                ix = 1:numel(tip_x);
                vect_interp = isnan(tip_x);

                tip_x(vect_interp) = interp1(ix(~vect_interp),tip_x(~vect_interp),ix(vect_interp),'linear','extrap');                    
                tip_y(vect_interp) = interp1(ix(~vect_interp),tip_y(~vect_interp),ix(vect_interp),'linear','extrap');
                tip_z(vect_interp) = interp1(ix(~vect_interp),tip_z(~vect_interp),ix(vect_interp),'linear','extrap');

                tip_x = filter_and_scale(tip_x,lowpassFilter);
                tip_y = filter_and_scale(tip_y,lowpassFilter);
                tip_z = filter_and_scale(tip_z,lowpassFilter);

                centroid_x = filter_and_scale(centroid_x,lowpassFilter);
                centroid_y = filter_and_scale(centroid_y,lowpassFilter);
                centroid_z = filter_and_scale(centroid_z,lowpassFilter);

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
                accel = diff(magspeed_cent);
                mag_accel = abs(accel);
                [~,accel_peaks_p_cent] = findpeaks(accel);
                [~,accel_peaks_tot_cent] = findpeaks(mag_accel);

                accel = diff(magspeed_tip);
                mag_accel = abs(accel);
                [~,accel_peaks_p_tip] = findpeaks(accel);
                [~,accel_peaks_tot_tip] = findpeaks(mag_accel);

                %Pathlength
                pathlength_3D_c = sum(magspeed_cent);
                pathlength_3D_t = sum(magspeed_tip);

                % Duration
                dur = onsetOffsetPairs(lick_num,2)-onsetOffsetPairs(lick_num,1);

                % Package the kinematic data
                t_stats_video(lick_num).centroid_x = centroid_x;
                t_stats_video(lick_num).centroid_y = centroid_y;
                t_stats_video(lick_num).centroid_z = centroid_z;

                t_stats_video(lick_num).tip_x = tip_x;
                t_stats_video(lick_num).tip_y = tip_y;
                t_stats_video(lick_num).tip_z = tip_z;

                t_stats_video(lick_num).magspeed_c = magspeed_cent;
                t_stats_video(lick_num).magspeed_t = magspeed_tip;
                t_stats_video(lick_num).pathlength_3D_c = pathlength_3D_c;
                t_stats_video(lick_num).pathlength_3D_t = pathlength_3D_t;
%                     l_traj(mm).dist_from_fid = dist_from_fid;

                t_stats_video(lick_num).accel_peaks_pos_t = accel_peaks_p_tip;
                t_stats_video(lick_num).accel_peaks_tot_t = accel_peaks_tot_tip;                                                            

                t_stats_video(lick_num).accel_peaks_pos_c = accel_peaks_p_cent;
                t_stats_video(lick_num).accel_peaks_tot_c = accel_peaks_tot_cent;
%                     
                t_stats_video(lick_num).dur = dur;

                % Tongue Kinematic Segmentation
                [seginfo,redir_pts,rad_curv] = get_t_kinsegments(t_stats_video(lick_num));
                t_stats_video(lick_num).redir_pts = redir_pts;
                t_stats_video(lick_num).seginfo = seginfo;
                t_stats_video(lick_num).rad_curv = rad_curv;                                                                 

                % Tortuosity
                curv = 1./rad_curv;
                tort = sum(curv.^2)/pathlength_3D_c;
                t_stats_video(lick_num).tort = tort;

                %Get Protraction/Retraction from Volume information.
                volume = filter_and_scale(volume,lowpassFilter);
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
                    fprintf('Video #%d: Skipping rest of trial - no volume minima found in lick #%d\n', video_num, lick_num);
                    % Delete current incomplete lick row:
                    t_stats_video(lick_num) = [];
                    break;
                end
                %Package the trial information/metadata
                t_stats_video(lick_num).time_rel_cue = onsetOffsetPairs(lick_num,1)-cue_onset(video_num);
                t_stats_video(lick_num).laser = laser_trial{sessionNum}(video_num)&(onsetOffsetPairs(lick_num,1)>cue_onset(video_num))&(onsetOffsetPairs(lick_num,1)<(cue_onset(video_num)+750));
                t_stats_video(lick_num).laser_trial = laser_trial{sessionNum}(video_num);
                t_stats_video(lick_num).trial_num = video_num;
                t_stats_video(lick_num).volume = volume;
                t_stats_video(lick_num).pairs = onsetOffsetPairs(lick_num,:);
                t_stats_video(lick_num).prot_ind = prot_ind;
                t_stats_video(lick_num).ret_ind = ret_ind;                    

                %ILM_information
                t_stats_video(lick_num).ILM_dur = ret_ind-prot_ind;
                t_stats_video(lick_num).ILM_pathlength = sum(magspeed_tip(prot_ind:ret_ind));
                t_stats_video(lick_num).ILM_PeakSpeed = max(magspeed_tip(prot_ind:ret_ind));
                t_stats_video(lick_num).ILM_NumAcc = sum((accel_peaks_p_cent>prot_ind)&(accel_peaks_p_cent<ret_ind));

            end
            if numel(t_stats_video)>0
                lick_rel_to_cue = sign([t_stats_video.time_rel_cue]);
                transition = find(diff(lick_rel_to_cue)>0);
                if numel(transition) == 0
                    transition = 0;
                end
                pre_licks = cumsum(reshape(lick_rel_to_cue(1:transition),1,numel(lick_rel_to_cue(1:transition))));
                post_licks = cumsum(reshape(lick_rel_to_cue((transition+1):end),1,numel(lick_rel_to_cue((transition+1):end))));
                
                lick_index = [fliplr(pre_licks) post_licks];
                
                for lickNum2 = 1:numel(lick_index)
                    t_stats_video(lickNum2).lick_index = lick_index(lickNum2);
                end
            end
        else
            % No 
            t_stats_video = [];
        end
        % Add on this video's t_stats rows on to the t_stats struct
        t_stats_session = [t_stats_session, t_stats_video]; %#ok<*AGROW> 
    end

    % Store this session's full t-stats struct
    t_stats_all{sessionNum} = t_stats_session;
end

% Prompt user to trim sessions to lick streaks
if numel(streak_num)<1
    % No streak specified - get from user
    f = figure('Name', 'Select session streaks');
    set(f, 'CloseRequestFcn', @(a, b)warndlg('Please use the Accept button to close this'));
    ax = gobjects(1, num_sessions);
    for sessionNum = 1:num_sessions
        a = sessionNum;
        ax(sessionNum, 1) = subplot(num_sessions, 1, a);
        axis(ax(sessionNum, 1), 'tight');
        yticks(ax(sessionNum, 1), [0, 1]);
        trialIdx = find(laser_trial{sessionNum}==0);
        xticks(ax(sessionNum, 1), min(trialIdx):max(trialIdx));
        if numel(response_bin{sessionNum}(laser_trial{sessionNum}==0))
            p(sessionNum, 1) = bar(ax(sessionNum, 1), trialIdx, response_bin{sessionNum}(laser_trial{sessionNum}==0));
        end
        ylim(ax(sessionNum, 1), [-0.2, 1.2]);
        title(ax(sessionNum, 1), {['Session ', abbreviateText(sessionDataRoots{sessionNum}, 15)], 'Trials with responses'}, 'Interpreter', 'none');
    end
    xlabel(ax(num_sessions, 1), 'Trial #')
    sgtitle(f, {'Click and drag to select trial range. Do nothing to select all.', 'Click Accept when done.'})
    uicontrol('Position',[10 10 200 20],'String','Accept streak selection','Callback','uiresume(gcbf)');
    brush(f);
    brush('on');
    uiwait(f);
    for sessionNum = 1:num_sessions
        if isgraphics(p(sessionNum, 1))
            selection = find(p(sessionNum, 1).BrushData);
        else
            selection = [];
        end
        if isempty(selection)
            % User did not select anything - use whole session as streak
            streak_on = 1;
            streak_off = num_trials(sessionNum);
        else
            % User selected stuff. Use earliest selected trial as streak start,
            % and latest selected trial as streak end
            streak_on = min(selection);
            streak_off = max(selection);
        end

        t_stats_session = t_stats_all{sessionNum};

        start_index = find([t_stats_session.trial_num] >= streak_on);
        start_index = start_index(1);
        stop_index = find([t_stats_session.trial_num] <= streak_off);
        stop_index = stop_index(end);
        t_stats_session = t_stats_session(start_index:stop_index);        

        t_stats_all{sessionNum} = t_stats_session;
    end
    delete(f);
end

for sessionNum = 1:num_sessions
    % Add in fiducial-referenced kinematics:
    t_stats_all{sessionNum} = addFiducialReferencedCoordinates(t_stats_all{sessionNum}, fiducial{sessionNum});
end

if save_flag
    for sessionNum = 1:num_sessions
        t_stats_session = t_stats_all{sessionNum};
        save(fullfile(sessionDataRoots{sessionNum}, 't_stats'), 't_stats_session', 'streak_on', 'streak_off');
    end
end