function [ t_stats_stack ] = make_t_struct(sessionDataRoots, dir_vid, save_flag, streak_num, fiducial)
%MAKE_XY_STRUCT Summary of this function goes here
%   get xy points from t_struct, separate them into individual licks and
%   estimate kinematic parameters (e.g. pathlength, speed, direction)

%%Trial Params
%rootdir = 'Z:\video\Head-FixLickExperiments\HFL05\HFL35\HighSpeed\041318_ALM_long_10mW';

% Behavior the algorithm should use when a lick tongue tip track has only one valid
% point in it.
% Options are 'trim', 'fill', 'ignore'
%   trim: trim tip track down to a single point
%   fill: fill in invalid values in tip track with the single valid value
%   ignore: leave NaN values in the tip track
singletonTongueTrackBehavior = 'trim'; 

d = fdesign.lowpass('N,F3db',3, 50, 1000);
lowpassFilter = design(d, 'butter');

response_bin = {};
laser_trial = [];

for sessionNum = 1:numel(sessionDataRoots)
    dirlist_video = rdir(strcat(dir_vid{sessionNum},'\*.avi'));
%   No longer used
    %load(fullfile(sessionDataRoots{sessionNum},'mask_props.mat'));
    load(fullfile(sessionDataRoots{sessionNum},'tip_track.mat'), 'tip_tracks');
    numTrials(sessionNum) = numel(dirlist_video); %size(out_xy_top,1);
    t_stats=[];
    cue_onset = [];
    
    for videoNum = 1:numel(dirlist_video)
        vidname_cells = strsplit(dirlist_video(videoNum).name,'_');
        descriptor = vidname_cells{end};
        descriptor = descriptor(1:end-4);
        
        if descriptor(end) == 'L'
            laser_trial{sessionNum}(videoNum) = 1;
            cue_onset(videoNum) = str2num(descriptor(2:end-1));
        else
            laser_trial{sessionNum}(videoNum) = 0;
            cue_onset(videoNum) = str2num(descriptor(2:end));
        end
        
    end
    
    if numel(streak_num)>0
        streak_on = streak_num(sessionNum,1);
        streak_off = min([numel(dirlist_video),numel(tip_tracks),streak_num(sessionNum,2)]);
    else
        streak_on = 1;
        streak_off = numTrials(sessionNum);
    end
        
    for videoNum=streak_on:streak_off
        
%         xy_vect_top = out_xy_top{frameNum,1};

%           REMOVED THESE - DON'T SEEM TO BE USED
%        area_vect_top = out_xy_top{frameNum,2};

        %         farpt_vect_top = out_xy_top{frameNum,4};
%         ct_vect_top = out_xy_top{frameNum,5};
%         
%         xy_vect_bot = out_xy_bot{frameNum,1};

%       REMOVED THESE - DON'T SEEM TO BE USED
%        area_vect_bot = out_xy_bot{frameNum,2};

        %         farpt_vect_bot = out_xy_bot{frameNum,4};
%         ct_vect_bot = out_xy_bot{frameNum,5};
        
%         xy_vect_top = medfilt1(xy_vect_top,3,[],2,'omitnan','truncate');
%         %area_vect_top = medfilt1(area_vect_top,3,[],2,'omitnan','truncate');

%           REMOVED THESE - DON'T SEEM TO BE USED
%          area_vect_top(area_vect_top<100) = NaN;
%          area_vect_bot(area_vect_bot<100) = NaN;
          
        
%         lick_exist_vect = area_vect_top.*area_vect_bot.*(tip_tracks(frameNum).volumes)';
        
         lick_exist_vect = tip_tracks(videoNum).volumes;
         
%        farpt_vect_top = medfilt1(farpt_vect_top,3,[],2,'omitnan','truncate');
%        farpt_vect_bot = medfilt1(farpt_vect_bot,3,[],2,'omitnan','truncate');
        
%        ct_vect_top = medfilt1(ct_vect_top,3,[],2,'omitnan','truncate');
%        ct_vect_bot = medfilt1(ct_vect_bot,3,[],2,'omitnan','truncate');
        
         nan_vect = isnan(lick_exist_vect);
         offset_vect = find(diff(nan_vect)>0);
         onset_vect = find(diff(nan_vect)<0);
        
        response_bin{sessionNum}(videoNum) = 0;
        
        mm=0;
        onsetOffsetPairs = [];
        lickNum=1;
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
                onsetOffsetPairs(lickNum,1) = onset_vect(onsetNum)+1;
                onsetOffsetPairs(lickNum,2) = offset_vect(offsetNums)-1;
                lickNum=lickNum+1;
            end
        end
        
        if numel(onsetOffsetPairs)
            l_traj = [];
            for lickNum = 1:size(onsetOffsetPairs,1)
                centroid_x = tip_tracks(videoNum).centroid_coords(onsetOffsetPairs(lickNum,1):onsetOffsetPairs(lickNum,2),1);
                centroid_y = tip_tracks(videoNum).centroid_coords(onsetOffsetPairs(lickNum,1):onsetOffsetPairs(lickNum,2),2);
                centroid_z = tip_tracks(videoNum).centroid_coords(onsetOffsetPairs(lickNum,1):onsetOffsetPairs(lickNum,2),3);

                tip_x = tip_tracks(videoNum).tip_coords(onsetOffsetPairs(lickNum,1):onsetOffsetPairs(lickNum,2),1);
                tip_y = tip_tracks(videoNum).tip_coords(onsetOffsetPairs(lickNum,1):onsetOffsetPairs(lickNum,2),2);
                tip_z = tip_tracks(videoNum).tip_coords(onsetOffsetPairs(lickNum,1):onsetOffsetPairs(lickNum,2),3);
                
                volume = tip_tracks(videoNum).volumes(onsetOffsetPairs(lickNum,1):onsetOffsetPairs(lickNum,2));
                
                if (onsetOffsetPairs(lickNum,1)-cue_onset(videoNum))<1300 % && (nansum(area_xy_top) + nansum(area_xy_bot))>125000 %&& (pairs(kk,1)-cue_onset(frameNum))>40                    
                    response_bin{sessionNum}(videoNum) = 1;
                end    

                %nan filter with extrapolation
                ix = 1:numel(tip_x);
                vect_interp = isnan(tip_x);

                numValidTipPositions = sum(~isnan(tip_x));
                if numValidTipPositions > 1
                    tip_x(vect_interp) = interp1(ix(~vect_interp),tip_x(~vect_interp),ix(vect_interp),'linear','extrap');                    
                    tip_y(vect_interp) = interp1(ix(~vect_interp),tip_y(~vect_interp),ix(vect_interp),'linear','extrap');
                    tip_z(vect_interp) = interp1(ix(~vect_interp),tip_z(~vect_interp),ix(vect_interp),'linear','extrap');

                    tip_x = filter_and_scale(tip_x,lowpassFilter);
                    tip_y = filter_and_scale(tip_y,lowpassFilter);
                    tip_z = filter_and_scale(tip_z,lowpassFilter);
                else
                    % Only 0 or 1 non-NaN tip locations, so we can't
                    % interpolate.
                    switch singletonTongueTrackBehavior
                        case 'trim'
                            % Trim tip to single point
                            notNaNMask = ~isnan(tip_x);
                            tip_x = tip_x(notNaNMask);
                            tip_y = tip_y(notNaNMask);
                            tip_z = tip_z(notNaNMask);
                        case 'fill'
                            % Fill whole tip track with single valid value
                            if numValidTipPositions == 0
                                error('Cannot fill tongue tip values because there are zero valid values. Change behavior to trim instead?');
                            end
                            tip_x = ones(size(tip_x)) * tip_x(notNaNMask);
                            tip_y = ones(size(tip_y)) * tip_y(notNaNMask);
                            tip_z = ones(size(tip_z)) * tip_z(notNaNMask);
                        case 'ignore'
                            % Just leave the NaNs in
                    end
                end

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
                dur = onsetOffsetPairs(lickNum,2)-onsetOffsetPairs(lickNum,1);

                % Package the kinematic data
                mm = mm + 1;

                l_traj(mm).centroid_x = centroid_x;
                l_traj(mm).centroid_y = centroid_y;
                l_traj(mm).centroid_z = centroid_z;

                l_traj(mm).tip_x = tip_x;
                l_traj(mm).tip_y = tip_y;
                l_traj(mm).tip_z = tip_z;

                l_traj(mm).magspeed_c = magspeed_cent;
                l_traj(mm).magspeed_t = magspeed_tip;
                l_traj(mm).pathlength_3D_c = pathlength_3D_c;
                l_traj(mm).pathlength_3D_t = pathlength_3D_t;
%                     l_traj(mm).dist_from_fid = dist_from_fid;

                l_traj(mm).accel_peaks_pos_t = accel_peaks_p_tip;
                l_traj(mm).accel_peaks_tot_t = accel_peaks_tot_tip;                                                            

                l_traj(mm).accel_peaks_pos_c = accel_peaks_p_cent;
                l_traj(mm).accel_peaks_tot_c = accel_peaks_tot_cent;
%                     
                l_traj(mm).dur = dur;

                % Tongue Kinematic Segmentation
                [seginfo,redir_pts,rad_curv] = get_t_kinsegments(l_traj(mm));
                l_traj(mm).redir_pts = redir_pts;
                l_traj(mm).seginfo = seginfo;
                l_traj(mm).rad_curv = rad_curv;                                                                 

                % Tortuosity
                curv = 1./rad_curv;
                tort = sum(curv.^2)/pathlength_3D_c;
                l_traj(mm).tort = tort;

                %Get Protraction/Retraction from Volume information.
                volume = filter_and_scale(volume,lowpassFilter);
                vol_diff = abs(diff(volume));
                try
                    [~,locs_asmin] = findpeaks(1./vol_diff);

                    prot_ind = locs_asmin(1);
                    ret_ind = locs_asmin(end);
                catch ME
                    disp(getReport(ME));
                    fprintf('Video #%d: Skipping rest of trial - no volume minima found in lick #%d\n', videoNum, lickNum);
                    % Delete current incomplete lick row:
                    l_traj(mm) = [];
                    flag=1;
                    break;
                end
                %Package the trial information/metadata
                l_traj(mm).time_rel_cue = onsetOffsetPairs(lickNum,1)-cue_onset(videoNum);
                l_traj(mm).laser = laser_trial{sessionNum}(videoNum)&(onsetOffsetPairs(lickNum,1)>cue_onset(videoNum))&(onsetOffsetPairs(lickNum,1)<(cue_onset(videoNum)+750));
                l_traj(mm).laser_trial = laser_trial{sessionNum}(videoNum);
                l_traj(mm).trial_num = videoNum;
                l_traj(mm).volume = volume;
                l_traj(mm).pairs = onsetOffsetPairs(lickNum,:);
                l_traj(mm).prot_ind = prot_ind;
                l_traj(mm).ret_ind = ret_ind;                    

                %ILM_information
                l_traj(mm).ILM_dur = ret_ind-prot_ind;
                l_traj(mm).ILM_pathlength = sum(magspeed_tip(prot_ind:ret_ind));
                l_traj(mm).ILM_PeakSpeed = max(magspeed_tip(prot_ind:ret_ind));
                l_traj(mm).ILM_NumAcc = sum((accel_peaks_p_cent>prot_ind)&(accel_peaks_p_cent<ret_ind));

            end
            if numel(l_traj)>0
                lick_rel_to_cue = sign([l_traj.time_rel_cue]);
                transition = find(diff(lick_rel_to_cue)>0);
                if numel(transition) == 0
                    transition = 0;
                end
                pre_licks = cumsum(reshape(lick_rel_to_cue(1:transition),1,numel(lick_rel_to_cue(1:transition))));
                post_licks = cumsum(reshape(lick_rel_to_cue((transition+1):end),1,numel(lick_rel_to_cue((transition+1):end))));
                
                lick_index = [fliplr(pre_licks) post_licks];
                
                for mm =1:numel(lick_index)
                    l_traj(mm).lick_index = lick_index(mm);
                end
            end
        else
            l_traj = [];
        end
        t_stats = [t_stats l_traj];
        clear l_traj;
    end
    
    t_stats_stack{sessionNum} = t_stats;
end

% Trim sessions to lick streaks
if numel(streak_num)<1
    % No streak specified - get from user
    f = figure('Name', 'Select session streaks');
    set(f, 'CloseRequestFcn', @(a, b)warndlg('Please use the Accept button to close this'));
    for sessionNum = 1:numel(sessionDataRoots)
        a = sessionNum;
        b = sessionNum + numel(sessionDataRoots);
        ax(sessionNum, 1) = subplot(numel(sessionDataRoots), 1, a);
        axis(ax(sessionNum, 1), 'tight');
        yticks(ax(sessionNum, 1), [0, 1]);
        trialIdx = find(laser_trial{sessionNum}==0);
        xticks(ax(sessionNum, 1), min(trialIdx):max(trialIdx));
        if numel(response_bin{sessionNum}(laser_trial{sessionNum}==0))
            p(sessionNum, 1) = bar(ax(sessionNum, 1), trialIdx, response_bin{sessionNum}(laser_trial{sessionNum}==0));
        end
        ylim(ax(sessionNum, 1), [-0.2, 1.2]);
        title(ax(sessionNum, 1), {['Session ', abbreviateText(sessionDataRoots{sessionNum}, 15)], 'Trials with responses'}, 'Interpreter', 'none');
%         temp_laservect((laser_trial{sessionNum}==0))=1;
%         if numel(cumsum(temp_laservect))
%             trialIdx = find(laser_trial{sessionNum}~=0);
%             p(sessionNum, 2) = plot(ax(sessionNum, 2), cumsum(temp_laservect));
%         end
%         title(ax(sessionNum, 2), {'Cumulative trials', 'with responses'}, 'Interpreter', 'none');
    end
    xlabel(ax(numel(sessionDataRoots), 1), 'Trial #')
    sgtitle(f, {'Click and drag to select trial range. Do nothing to select all.', 'Click Accept when done.'})
    h = uicontrol('Position',[10 10 200 20],'String','Accept streak selection','Callback','uiresume(gcbf)');
    b = brush(f);
    brush('on');
    uiwait(f);
    for sessionNum = 1:numel(sessionDataRoots)
        if isgraphics(p(sessionNum, 1))
            selection = find(p(sessionNum, 1).BrushData);
        else
            selection = [];
        end
        if isempty(selection)
            % User did not select anything - use whole session as streak
            streak_on = 1;
            streak_off = numTrials(sessionNum);
        else
            % User selected stuff. Use earliest selected trial as streak start,
            % and latest selected trial as streak end
            streak_on = min(selection);
            streak_off = max(selection);
        end

        t_stats = t_stats_stack{sessionNum};

        start_index = find([t_stats.trial_num] >= streak_on);
        start_index = start_index(1);
        stop_index = find([t_stats.trial_num] <= streak_off);
        stop_index = stop_index(end);
        t_stats = t_stats(start_index:stop_index);        

        t_stats_stack{sessionNum} = t_stats;
    end
    delete(f);
end

for sessionNum = 1:numel(sessionDataRoots)
    % Add in fiducial-referenced kinematics:
    t_stats_stack{sessionNum} = addFiducialReferencedCoordinates(t_stats_stack{sessionNum}, fiducial{sessionNum});
end

if save_flag
    for sessionNum = 1:numel(sessionDataRoots)
        t_stats = t_stats_stack{sessionNum};
        save(fullfile(sessionDataRoots{sessionNum}, 't_stats'), 't_stats', 'streak_on', 'streak_off');
    end
end