function tip_track = debugTongueTipTracking(sessionDataRoot, videoIdx, frameIdx, im_shift)
% Run a single frame of tongue tracking with debug output enabled

params = setTTTTrackParams(im_shift);

topFilePaths = dir(fullfile(sessionDataRoot, 'Top*.mat'));
botFilePaths = dir(fullfile(sessionDataRoot, 'Bot*.mat'));

topFilePath = fullfile(topFilePaths(videoIdx).folder, topFilePaths(videoIdx).name);
botFilePath = fullfile(botFilePaths(videoIdx).folder, botFilePaths(videoIdx).name);

% Load the mask stacks for the top and bottom views
top_mask = importdata(topFilePath);
bot_mask = importdata(botFilePath);

tip_track.tip_coords = nan(1, 3);
tip_track.centroid_coords = nan(1, 3);
tip_track.frame_volume = nan(1, 1);

illustrate = true;

[frame_tip_coords, frame_centroid_coords, frame_volume] = getTongueTipFrameTrack(bot_mask(frameIdx,:,:), top_mask(frameIdx,:,:), params, illustrate);
tip_track.tip_coords(1, :) = frame_tip_coords;
tip_track.centroid_coords(1, :) = frame_centroid_coords;
tip_track.volumes(1) = frame_volume;

fprintf('Tip tracking debug:\n')
fprintf('   Top mask path: %s\n', topFilePath)
fprintf('   Bot mask path: %s\n', botFilePath)
fprintf('   Video #: %d\n', videoIdx)
fprintf('   Frame #: %d\n', frameIdx)
fprintf('   im-shift: %d\n', im_shift)
fprintf('Tracking results:\n')
disp(tip_track)