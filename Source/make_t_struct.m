function [ t_stats_all ] = make_t_struct(sessionDataRoots, sessionVideoRoots, save_flag, streak_num, fiducial, includePlaceholderLicks)
%MAKE_XY_STRUCT Summary of this function goes here
%   get xy points from t_struct, separate them into individual licks and
%   estimate kinematic parameters (e.g. pathlength, speed, direction)
arguments
    sessionDataRoots cell {mustBeText}
    sessionVideoRoots cell {mustBeText}
    save_flag (1, 1) logical
    streak_num
    fiducial
    includePlaceholderLicks (1, 1) logical = false
end

filter_coeffs = fdesign.lowpass('N,F3db', 3, 50, 1000);
lowpass_filter = design(filter_coeffs, 'butter');

num_sessions = numel(sessionDataRoots);

% Initialize variables
num_trials = zeros(1, num_sessions);
laser_trials = cell(1, num_sessions);
response_bin = cell(1, num_sessions);

for sessionNum = 1:num_sessions
    video_list = findSessionVideos(sessionVideoRoots{sessionNum}, 'avi', @parsePCCFilenameTimestamp);
    num_videos = numel(video_list);

    % Initialize variables
    laser_trials{sessionNum} = zeros(1, num_videos);
    cue_onsets = zeros(1, num_videos);

    % Load tip_track.mat file, containing the tongue tip coordinates
    load(fullfile(sessionDataRoots{sessionNum},'tip_track.mat'), 'tip_tracks');

    num_trials(sessionNum) = numel(video_list);
    t_stats = [];
    
    for video_num = 1:num_videos
        % Parse cue time and laser on/off status from video filename
        %   See labelTrialsWithCueAndLaser function for more info
        [~, video_name, ~] = fileparts(video_list{video_num});
        vidname_cells = strsplit(video_name, '_');
        descriptor = vidname_cells{end};        
        if descriptor(end) == 'L'
            laser_trials{sessionNum}(video_num) = 1;
            cue_onsets(video_num) = str2double(descriptor(2:end-1));
        else
            laser_trials{sessionNum}(video_num) = 0;
            cue_onsets(video_num) = str2double(descriptor(2:end));
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
        laser_trial = laser_trials{sessionNum}(video_num);
        cue_onset = cue_onsets(video_num);
        if num_licks > 0
            for lick_num = 1:num_licks
                onset =  onsetOffsetPairs(lick_num, 1);
                offset = onsetOffsetPairs(lick_num, 2);

                if onset - cue_onset < 1300
                    response_bin{sessionNum}(video_num) = 1;
                end

                [t_stats_lick, abort_trial] = ...
                    generate_t_struct_row(...
                        'trial_num', video_num, ...
                        'tip_tracks', tip_tracks(video_num), ...
                        'onset', onset, ...
                        'offset', offset, ...
                        'cue_onset', cue_onset, ...
                        'laser_trial', laser_trial, ...
                        'lowpass_filter', lowpass_filter...
                        );

                if ~abort_trial
                    t_stats_video(lick_num) = t_stats_lick;
                else
                    %%% ******** Note - this seems a bit off - if lick N
                    %%% has no volumne minimum, then all licks M > N are
                    %%% skipped. Not sure that's the best behavior, but to
                    %%% change it just switch a "continue" for that "break".
                    fprintf('Video #%d: Skipping rest of trial - no volume minima found in lick #%d\n', video_num, lick_num);
                    break;
                end
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
        end

        if includePlaceholderLicks && (~exist('t_stats_video', 'var') || isempty(t_stats_video))
            % Add placeholder lick to represent the trial 
            [t_stats_video(lick_num), response_bin{sessionNum}(video_num)] = ...
                    generate_t_struct_row(...
                        'trial_num', video_num, ...
                        'laser_trial', laser_trial, ...
                        'placeholder', true...
                        );
        end

        % Add on this video's t_stats rows on to the t_stats struct
        if exist('t_stats_video', 'var')
            t_stats = [t_stats, t_stats_video]; %#ok<*AGROW> 
            clear t_stats_video
        end
    end

    % Store this session's full t-stats struct
    t_stats_all{sessionNum} = t_stats;
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
        trialIdx = find(laser_trials{sessionNum}==0);
        xticks(ax(sessionNum, 1), min(trialIdx):max(trialIdx));
        if numel(response_bin{sessionNum}(laser_trials{sessionNum}==0))
            p(sessionNum, 1) = bar(ax(sessionNum, 1), trialIdx, response_bin{sessionNum}(laser_trials{sessionNum}==0));
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

        t_stats = t_stats_all{sessionNum};

        start_index = find([t_stats.trial_num] >= streak_on);
        start_index = start_index(1);
        stop_index = find([t_stats.trial_num] <= streak_off);
        stop_index = stop_index(end);
        t_stats = t_stats(start_index:stop_index);        

        t_stats_all{sessionNum} = t_stats;
    end
    delete(f);
end

for sessionNum = 1:num_sessions
    % Add in fiducial-referenced kinematics:
    t_stats_session = t_stats_all{sessionNum};
    if ~isempty(t_stats_session)
        t_stats_all{sessionNum} = addFiducialReferencedCoordinates(t_stats_session, fiducial{sessionNum});
    end
end

if save_flag
    for sessionNum = 1:num_sessions
        t_stats = t_stats_all{sessionNum};
        save(fullfile(sessionDataRoots{sessionNum}, 't_stats'), 't_stats', 'streak_on', 'streak_off');
    end
end