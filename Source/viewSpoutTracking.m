function viewSpoutTracking(sessionMaskRoot, sessionVideoRoot, sessionFPGARoot, time_aligned_trial, spout_calibration, cue_frame)

if ~exist('cue_frame', 'var') || isempty(cue_frame)
    cue_frame = 1001;
end

%% Get Times of all the videos
vid_real_time = getTongueVideoTimestamps(sessionVideoRoot);

%% Get mapping between video trials and FPGA trials
lick_struct_path = fullfile(sessionFPGARoot, 'lick_struct.mat');
s = load(lick_struct_path, 'lick_struct');
lick_struct = s.lick_struct;

vid_index = mapVideoIndexToFPGATrialIndex(vid_real_time, lick_struct, time_aligned_trial);

%load(strcat(sessionMaskRoot,'\t_stats.mat'),'t_stats')
%l_sp_struct = lick_struct;
trial_idxs = 1:5; %length(vid_index);

command_x = [lick_struct.actuator1_ML_command];
command_y = [lick_struct.actuator2_AP_command];
spout_calibration = addPositionToCalibration(spout_calibration, command_x, command_y);

save_path = sessionMaskRoot;

% Set up occlusions directory to hold original masks and occlusion reports
occlusions_dir = fullfile(save_path, 'occlusions');
if ~exist(occlusions_dir, 'dir')
    mkdir(occlusions_dir);
end

videoList = findFilesByRegex(sessionVideoRoot, '.*\.[aA][vV][iI]');

for trial_idx = trial_idxs
    trial_num = trial_idx - 1;
    if isnan(trial_idx)
        % No lick_struct row corresponding to this video
        continue;
    end
    %% Calculate spout position
    fprintf('Trial number: %d\n', trial_num);

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

    videoPath = videoList{trial_idx};
    videoData = loadVideoData(videoPath);
    videoData = videoData(:, :, cue_frame:end);
    
    spout_mask = false(size(videoData));

    for frame_num_since_cue = 1:size(spout_bbox, 1)
        displayProgress('Frame %d of %d\n', frame_num_since_cue, size(spout_bbox, 1), 25);
        
        [spout_mask(161:end, :, frame_num_since_cue), spout_mask(1:144, :, frame_num_since_cue)] = getSpoutMasks(spout_bbox(frame_num_since_cue, :), mask_size);

    end
    overlay = overlayMask(videoData, spout_mask, [1, 0, 0], 0.8);
    overlay = permute(overlay, [3, 1, 2, 4]);
    vb = VideoBrowser(overlay, 'sum');
    
%             f = overlayMask(videoData(display_frame, :, :), {tongue_top_masks(display_frame, :, :), tongue_bot_masks(display_frame, :, :), topPatch, botPatch}, {[1, 1, 0], [0, 1, 1], [1, 0, 0], [1, 0, 0]}, 0.8, {[1, 1], [1, 400-240+1], [1, 1], [1, 400-240+1]}); 
%             figure; imshow(f); title(num2str(display_frame));
end
