function [top_healed_masks, bot_healed_masks, top_report, bot_report] = heal_occlusion_trial(tongue_top_masks, tongue_bot_masks, spout_bbox, cue_frame, display_frames, videoData)
% Heal any occlusions found in the masks for a single trial.

if ~exist('display_frames', 'var') || isempty(display_frames)
    display_frames = [];
end
if ~exist('videoData', 'var') || isempty(videoData)
    videoData = [];
end

% Initialize occlusion report structs
top_report = [];
bot_report = [];

% Initialize healed masks
top_healed_masks = tongue_top_masks;
bot_healed_masks = tongue_bot_masks;

% Determine the size of the 3D mask volume
mask_size = [size(tongue_bot_masks, 2), size(tongue_bot_masks, 3), size(tongue_top_masks, 2)];

tongue_top_masks = permute(tongue_top_masks, [2, 3, 1]);
tongue_bot_masks = permute(tongue_bot_masks, [2, 3, 1]);

for frame_num_since_cue = 1:size(spout_bbox, 1)
    frame = frame_num_since_cue + cue_frame - 1;
    displayProgress('Frame %d of %d\n', frame_num_since_cue, size(spout_bbox, 1), 10);
%     if any(frame_num_since_cue == display_frames)
%         plotHeal = true;
%     else
%         plotHeal = false;
%     end
    plotHeal = true;
    
    if frame_num_since_cue == 1 || (frame_num_since_cue > 1 && ~isequal(spout_bbox(frame_num_since_cue, :), spout_bbox(frame_num_since_cue-1, :)))
        [bot_spout_mask, top_spout_mask] = getSpoutMasks(spout_bbox(frame_num_since_cue, :), mask_size);
    end

    %spoutTopBBox = [

%     [x, y] = ndgrid(1:size(spoutbot, 1), 1:size(spoutbot, 2));
%     spoutbot = abs(x - (spoutCorner(2)-spoutWidth/2)) <= spoutWidth/2 & y > spoutCorner(1);
%     [z, y] = ndgrid(1:size(spouttop, 1), 1:size(spouttop, 2));
%     spouttop = abs(z - (spoutCo-rner(3)-spoutWidth/2)) <= spoutWidth/2 & y > spoutCorner(1);

    top_tongue_mask = tongue_top_masks(:, :, frame);
    bot_tongue_mask = tongue_bot_masks(:, :, frame);
    
    % If there are multiple connected components in either mask, get rid of
    % all but the biggest one.
    top_cc = bwconncomp(top_tongue_mask);
    if length(top_cc.PixelIdxList) > 1
        for k = 1:length(top_cc.PixelIdxList)
            top_tongue_mask(top_cc.PixelIdxList{k}) = false;
        end
    end
    bot_cc = bwconncomp(bot_tongue_mask);
    if length(bot_cc.PixelIdxList) > 1
        for k = 1:length(bot_cc.PixelIdxList)
            bot_tongue_mask(bot_cc.PixelIdxList{k}) = false;
        end
    end

    if ~isempty(videoData)
        top_video_frame = squeeze(videoData(1:144, :, frame));
        bot_video_frame = squeeze(videoData(161:end, :, frame));
    else
        top_video_frame = [];
        bot_video_frame = [];
    end

    [top_healed_mask, top_patch_size, top_tongue_size, top_spout_close] = heal_occlusion(top_tongue_mask, top_spout_mask, 5, plotHeal, sprintf('top frame %d', frame), top_video_frame);
    [bot_healed_mask, bot_patch_size, bot_tongue_size, bot_spout_close] = heal_occlusion(bot_tongue_mask, bot_spout_mask, 5, plotHeal, sprintf('bot frame %d', frame), bot_video_frame);
    
    spout_close = top_spout_close && bot_spout_close;
    
    next_report = length(top_report)+1;
    top_report(next_report).frame = frame;
    top_report(next_report).tongue_size = top_tongue_size;
    top_report(next_report).patch_size = top_patch_size;
    top_report(next_report).spout_close = spout_close;
    if top_patch_size > 0
        top_healed_masks(frame_num_since_cue, :, :) = top_healed_mask;
    end

    next_report = length(bot_report)+1;
    bot_report(next_report).frame = frame_num_since_cue;
    bot_report(next_report).patch_size = bot_patch_size;
    bot_report(next_report).tongue_size = bot_tongue_size;
    bot_report(next_report).spout_close = spout_close;
    if bot_patch_size > 0
        bot_healed_masks(frame_num_since_cue, :, :) = bot_healed_mask;
    end

end