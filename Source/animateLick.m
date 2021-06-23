function animateLick(videoData, t_stats, trial_num, start_frame)
% Animate a 2D fakeout trial.
% videoData: a HxWxN array representing a video
% t_stats: a t_stats file with spout position fields
% trial_num: the trial num within the session in the t_stats file (must
%   correspond to the video data provided, of course)
% start_frame: the frame to start the animation on.

% Hardcoded parameters
cueTime = 1000;
top_pix_shift = 20;
botMaskH = 240;
topMaskH = 144;

% Get video dims
[h, w, n] = size(videoData);

% Make functions for mapping mask coordinates onto video coordinates
map_xy = @(mx, my)[my; mx + h - botMaskH];
map_z = @(mz)(topMaskH - mz) + top_pix_shift;

% Filter t_stats for only licks within the requested trial number
t_stats = t_stats([t_stats.trial_num] == trial_num);

% Prepare vectors of the same length as the video
tipxv = nan([1, n]);
tipyv = nan([1, n]);
tipzv = nan([1, n]);
spoutxv = nan([1, n]);
spoutyv = nan([1, n]);
spoutzv = nan([1, n]);

% Loop over each lick and add in tongue position data into vectors
for lickIndex = 1:length(t_stats)
    lickStart = t_stats(lickIndex).pairs(1);
    lickEnd = t_stats(lickIndex).pairs(2);
    lickStart - t_stats(lickIndex).time_rel_cue;
    lickEnd - t_stats(lickIndex).time_rel_cue;
    tipxyv = map_xy(t_stats(lickIndex).tip_x, t_stats(lickIndex).tip_y);
    tipxv(lickStart:lickEnd) = tipxyv(1, :);
    tipyv(lickStart:lickEnd) = tipxyv(2, :);
    tipzv(lickStart:lickEnd) = map_z(t_stats(lickIndex).tip_z);
end

% Add spout position data to vectors
dataLen = length(t_stats(1).spout_position_x);
spoutxyv = map_xy(t_stats(1).spout_position_x, t_stats(1).spout_position_y);
spoutxv(cueTime:cueTime+dataLen-1) = spoutxyv(1, :);
spoutyv(cueTime:cueTime+dataLen-1) = spoutxyv(2, :);
spoutzv(cueTime:cueTime+dataLen-1) = map_z(t_stats(1).spout_position_z);

% Fill in gaps in spout position before and after cue period
spoutxv(1:cueTime-1) = spoutxv(cueTime);
spoutyv(1:cueTime-1) = spoutyv(cueTime);
spoutzv(1:cueTime-1) = spoutzv(cueTime);
spoutxv(cueTime+dataLen:end) = spoutxv(cueTime+dataLen-1);
spoutyv(cueTime+dataLen:end) = spoutyv(cueTime+dataLen-1);
spoutzv(cueTime+dataLen:end) = spoutzv(cueTime+dataLen-1);

% Create initial graphics objects
fig = figure; 
im = imshow(videoData(:, :, start_frame)); 
hold on; 
botTips = plot(tipxv, tipyv, 'red');
topTips = plot(tipxv, tipzv, 'red');

botTipsOld = plot(0, 0, 'Color', [1, 0, 0, 0.3], 'LineStyle', '-');
topTipsOld = plot(0, 0, 'Color', [1, 0, 0, 0.3], 'LineStyle', '-');

botTip = plot(tipxv(1), tipyv(1), 'co');
topTip = plot(tipxv(1), tipzv(1), 'co');

botSpout = plot(spoutxv(1), spoutyv(1), 'y+');
topSpout = plot(spoutxv(1), spoutzv(1), 'y+');
botSpouts = plot(spoutxv, spoutyv, 'y-');
topSpouts = plot(spoutxv, spoutzv, 'y-');

spoutWidth = 22;
[spx, spy] = getSpoutPoly(spoutxv(1), spoutyv(1), spoutWidth, w);
[~, spz] = getSpoutPoly(spoutxv(1), spoutzv(1), spoutWidth, w);
botSpoutPatch = patch(spx, spy, [0, 1, 1], 'FaceAlpha', 0.3);
topSpoutPatch = patch(spx, spz, [0, 1, 1], 'FaceAlpha', 0.3);

% Animate
while true
    if ~isvalid(fig)
        return;
    end
    % Wait for user go signal
    disp('press any key to animate')
    pause
    % Loop over the requested frame range
    for f = start_frame:n
        if ~isvalid(fig)
            return;
        end
        % Update image
        im.CData = videoData(:, :, f);
        % Update spout position
        botSpout.XData = spoutxv(f);
        botSpout.YData = spoutyv(f);
        topSpout.XData = spoutxv(f);
        topSpout.YData = spoutzv(f);
        [spx, spy] = getSpoutPoly(spoutxv(f), spoutyv(f), spoutWidth, w);
        [~, spz] = getSpoutPoly(spoutxv(f), spoutzv(f), spoutWidth, w);
        botSpoutPatch.XData = spx;
        botSpoutPatch.YData = spy;
        topSpoutPatch.XData = spx;
        topSpoutPatch.YData = spz;

        if isnan(tipxv(f))
            % We're between licks - update "start_frame" so we can dull out
            % older licks
            start_frame = f;
        else
            % Update tip data
            fr = start_frame:f;
            frOld = 1:start_frame-1;
            botTips.XData = tipxv(fr);
            botTips.YData = tipyv(fr);
            topTips.XData = tipxv(fr);
            topTips.YData = tipzv(fr);
            botTipsOld.XData = tipxv(frOld);
            botTipsOld.YData = tipyv(frOld);
            topTipsOld.XData = tipxv(frOld);
            topTipsOld.YData = tipzv(frOld);
            botTip.XData = tipxv(f);
            botTip.YData = tipyv(f);
            topTip.XData = tipxv(f);
            topTip.YData = tipzv(f);
        end
        % Animation pause
        pause(0.021);
    end
end

function [x, y] = getSpoutPoly(xCorner, yCorner, spoutWidth, frameWidth)
x = [xCorner, frameWidth, frameWidth, xCorner];
y = [yCorner, yCorner, yCorner - spoutWidth, yCorner - spoutWidth];