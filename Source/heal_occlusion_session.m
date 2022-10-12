function heal_occlusion_session(sessionMaskRoot, sessionVideoRoot, sessionFPGARoot, time_aligned_trial, spout_calibration, cue_frame)
profile on;

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
trial_idxs = 1:length(vid_index);

command_x = [lick_struct.actuator1_ML_command];
command_y = [lick_struct.actuator2_AP_command];
spout_calibration = addPositionToCalibration(spout_calibration, command_x, command_y);

save_path = sessionMaskRoot;

% Set up occlusions directory to hold original masks and occlusion reports
occlusions_dir = fullfile(save_path, 'occlusions');
if ~exist(occlusions_dir, 'dir')
    mkdir(occlusions_dir);
end

debug = false;

if debug
    videoList = findFilesByRegex(sessionVideoRoot, '.*\.[aA][vV][iI]');
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
    display_frames = randsample(1300, 25)';
    [top_healed_masks, bot_healed_masks, top_report_data, bot_report_data] = heal_occlusion_trial(tongue_top_masks, tongue_bot_masks, spout_bbox, cue_frame, display_frames, videoData);

    if debug
        videoPath = videoList{trial_idx};
        videoData = permute(loadVideoData(videoPath), [3, 1, 2]);
        patchedFrames = find([top_report_data.patch_size] > 0 | [bot_report_data.patch_size] > 0) + 1201;
        for display_frame = patchedFrames
            topPatch = top_healed_masks(display_frame, :, :) & ~tongue_top_masks(display_frame, :, :);
            botPatch = bot_healed_masks(display_frame, :, :) & ~tongue_bot_masks(display_frame, :, :);
            disp('patch sizes:')
            sum(topPatch(:))
            sum(botPatch(:))
            f = overlayMask(videoData(display_frame, :, :), {tongue_top_masks(display_frame, :, :), tongue_bot_masks(display_frame, :, :), topPatch, botPatch}, {[1, 1, 0], [0, 1, 1], [1, 0, 0], [1, 0, 0]}, 0.8, {[1, 1], [1, 400-240+1], [1, 1], [1, 400-240+1]}); 
            figure; imshow(f); title(num2str(display_frame));
        end
    end
    
    timestamp = now();

    dryRun = false;

    if ~dryRun
        saveOcclusionResults(top_report_data, top_healed_masks, save_path, occlusions_dir, 'Top', timestamp, tongue_top_path, trial_idx)
        saveOcclusionResults(bot_report_data, bot_healed_masks, save_path, occlusions_dir, 'Bot', timestamp, tongue_bot_path, trial_idx)
    end

end
profile off;
profile viewer;

function saveOcclusionResults(report_data, healed_masks, save_dir, occlusions_dir, view, heal_timestamp, original_mask_path, trial_idx)
% report_data =         struct containing occlusion report for each frame
% healed_masks =        healed mask stack to save
% save_path =           directory in which to save healed masks and report
% occlusions_dir =      directory in which to move original unhealed masks
% view =                view name (either "Top" or "Bot")
% heal_timestamp =      timestamp indicating when healing was done
% original_mask_path =  path to original mask stack
% trial_idx =           trial index (in 1-indexed numbering)

trial_num = trial_idx - 1;

if isempty(report_data)
    return;
end

% Determine path to move original mask stack file to, to avoid overwriting
% it
[~, original_name, original_ext] = fileparts(original_mask_path);
moved_mask_path = fullfile(occlusions_dir, [original_name, original_ext]);

% Store info in struct fields
report.view = view;
report.heal_timestamp = heal_timestamp;
report.patched_mask_path = original_mask_path;
report.unmodified_mask_path = moved_mask_path;
report.trial_num = trial_num;
report.trial_idx = trial_idx;
report.data = report_data;
healed_name = sprintf('%s_%03d.mat', view, trial_num);
num_patched = sum([report_data.patch_size] > 0);
report.num_patched = num_patched;
report_name = sprintf('%s_%03d_occ-report-%04d.mat', view, trial_num, num_patched);

% Copy original mask stack to occlusions folder in case we want to revert.
copyfile(original_mask_path, moved_mask_path);

% Save occlusion report
save(fullfile(occlusions_dir, report_name), 'report');

% Save healed masks
mask_pred = healed_masks;  % Legacy naming scheme which code depends on
save(fullfile(save_dir, healed_name), 'mask_pred');
