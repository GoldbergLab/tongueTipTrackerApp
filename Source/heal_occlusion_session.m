function heal_occlusion_session(sessionMaskRoot, sessionVideoRoot, sessionFPGARoot, time_aligned_trial, spout_calibration, cue_frame, revert_old_healing)

if ~exist('cue_frame', 'var') || isempty(cue_frame)
    cue_frame = 1001;
end

if ~exist('revert_old_healing', 'var') || isempty(revert_old_healing)
    revert_old_healing = true;
end


%% Get Times of all the videos
vid_real_time = getTongueVideoTimestamps(sessionVideoRoot);

%% Get mapping between video trials and FPGA trials
lick_struct_path = fullfile(sessionFPGARoot, 'lick_struct.mat');
s = load(lick_struct_path, 'lick_struct');
lick_struct = s.lick_struct;

vid_index = mapVideoIndexToFPGATrialIndex(vid_real_time, lick_struct, time_aligned_trial);

trial_idxs = 1:length(vid_index);

command_x = [lick_struct.actuator1_ML_command];
command_y = [lick_struct.actuator2_AP_command];
spout_calibration = addPositionToCalibration(spout_calibration, command_x, command_y);

save_path = sessionMaskRoot;

% Get proper directories for saving occlusion reports and backups of the 
%   original unhealed masks
[occlusion_reports_dir, original_masks_dir, overwrite_warning] = getOcclusionsDirs(save_path);

if overwrite_warning
    % Pre-existing reports and/or original masks found
    if revert_old_healing
        revertOcclusionHealing(save_path);
    end
end

debug = false;

if debug
    videoList = findFilesByRegex(sessionVideoRoot, '.*\.[aA][vV][iI]');
end

parfor trial_idx = trial_idxs
    trial_num = trial_idx - 1;
    if isnan(trial_idx)
        % No lick_struct row corresponding to this video
        continue;
    end
    %% Calculate spout position
    fprintf('Trial %d of %d\n', trial_idx, length(trial_idxs));

    % Load bot mask stack
    tongue_bot_name = sprintf('Bot_%03d.mat', trial_num);
    tongue_bot_path = fullfile(sessionMaskRoot, tongue_bot_name);
    tongue_bot_masks = load(tongue_bot_path);
    tongue_bot_masks = tongue_bot_masks.mask_pred;

    % Load top mask stack
    tongue_top_name = sprintf('Top_%03d.mat', trial_num);
    tongue_top_path = fullfile(sessionMaskRoot, tongue_top_name);
    tongue_top_masks = load(tongue_top_path);
    tongue_top_masks = tongue_top_masks.mask_pred;

    % Determine the size of the 3D mask volume
    mask_size = [size(tongue_bot_masks, 2), size(tongue_bot_masks, 3), size(tongue_top_masks, 2)];
    
    % Generate the bounding box of the spout for each frame in this trial
    spout_bbox = getSpoutBBox(lick_struct(vid_index(trial_idx)), spout_calibration, mask_size);

%     if debug
%         videoPath = videoList{trial_idx};
%         videoData = loadVideoData(videoPath);
%         display_frames = randsample(1300, 25)';
%     else
%         videoData = [];
%         display_frames = [];
%     end

    [top_healed_masks, bot_healed_masks, top_report_data, bot_report_data] = heal_occlusion_trial(tongue_top_masks, tongue_bot_masks, spout_bbox, cue_frame);

%     if debug
%         videoPath = videoList{trial_idx};
%         videoData = permute(loadVideoData(videoPath), [3, 1, 2]);
%         patchedFrames = find([top_report_data.patch_size] > 0 | [bot_report_data.patch_size] > 0) + cue_frame - 1;
%         for display_frame = patchedFrames
%             unhealedOverlay = overlayMask(videoData(display_frame, :, :), {tongue_top_masks(display_frame, :, :), tongue_bot_masks(display_frame, :, :)}, {[1, 1, 0], [1, 1, 0]}, 0.8, {[1, 1], [1, 400-240+1]}); 
%             healedOverlay =   overlayMask(videoData(display_frame, :, :), {top_healed_masks(display_frame, :, :), bot_healed_masks(display_frame, :, :)}, {[0, 1, 1], [0, 1, 1]}, 0.8, {[1, 1], [1, 400-240+1]}); 
%             f = figure;
%             ax1 = subplot(1, 2, 1);
%             imshow(unhealedOverlay, 'Parent', ax1);
%             ax2 = subplot(1, 2, 2);
%             imshow(healedOverlay, 'Parent', ax2);
%         end
%     end
    
    timestamp = char(datetime('now'));

    dryRun = false;

    if ~dryRun
        saveOcclusionResults(top_report_data, top_healed_masks, save_path, occlusion_reports_dir, original_masks_dir, 'Top', timestamp, tongue_top_path, trial_idx, true)
        saveOcclusionResults(bot_report_data, bot_healed_masks, save_path, occlusion_reports_dir, original_masks_dir, 'Bot', timestamp, tongue_bot_path, trial_idx, true)
    end

end
